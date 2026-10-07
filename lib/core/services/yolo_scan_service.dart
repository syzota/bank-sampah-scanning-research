import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../config/research_config.dart';
import '../utils/yolo_preprocessing.dart';

/// Cached for the lifetime of this app process; form changes do not reload it.
class YoloScanService {
  YoloScanService._();
  static final instance = YoloScanService._();
  static const modelAsset = 'assets/models/best.tflite';
  static const modelName = 'YOLOv8n-cls';
  static const expectedModelSha256 =
      '4c8c4df10d866ea6ba87aea9c83e3ef9044a7ed3ad113bfcc3294a64fd3986b4';

  bool get isSupported => Platform.isAndroid;
  SendPort? _workerPort;
  Isolate? _worker;
  Future<void>? _loading;
  bool _busy = false;
  bool hasRun = false;
  double modelLoadMs = 0;
  String modelSha256 = expectedModelSha256;

  Future<void> _load() async {
    if (_workerPort != null) return;
    final asset = await rootBundle.load(modelAsset);
    final bytes = asset.buffer.asUint8List(
      asset.offsetInBytes,
      asset.lengthInBytes,
    );
    modelSha256 = sha256.convert(bytes).toString();
    if (modelSha256 != expectedModelSha256) {
      throw StateError(
        'File model berbeda. Gunakan best.tflite dari paket revisi.',
      );
    }
    final ready = ReceivePort();
    try {
      _worker = await Isolate.spawn(_yoloWorker, <Object>[
        ready.sendPort,
        TransferableTypedData.fromList([bytes]),
        ResearchConfig.cpuThreads,
      ]);
      final reply = Map<String, dynamic>.from(
        await ready.first.timeout(const Duration(seconds: 60)) as Map,
      );
      if (reply['error'] != null) throw StateError(reply['error'] as String);
      _workerPort = reply['port'] as SendPort;
      modelLoadMs = (reply['model_load_ms'] as num).toDouble();
    } catch (_) {
      _worker?.kill(priority: Isolate.immediate);
      _worker = null;
      rethrow;
    } finally {
      ready.close();
    }
  }

  Future<Map<String, dynamic>> classify(String imagePath) async {
    if (!isSupported) {
      throw UnsupportedError('Scan YOLO pada versi ini dijalankan di Android.');
    }
    if (_busy) throw StateError('Scan sebelumnya masih berlangsung.');
    _busy = true;
    final response = ReceivePort();
    try {
      await (_loading ??= _load());
      final cold = !hasRun;
      _workerPort!.send(<Object>[imagePath, response.sendPort]);
      final result = Map<String, dynamic>.from(
        await response.first.timeout(const Duration(seconds: 60)) as Map,
      );
      if (result['error'] != null) throw StateError(result['error'] as String);
      hasRun = true;
      return {
        ...result,
        'is_cold_start': cold,
        'model_load_ms': cold ? modelLoadMs : 0.0,
      };
    } on TimeoutException {
      _worker?.kill(priority: Isolate.immediate);
      _worker = null;
      _workerPort = null;
      _loading = null;
      hasRun = false;
      throw StateError(
        'Scan terlalu lama. Coba kembali dengan foto JPG atau PNG.',
      );
    } catch (_) {
      if (_workerPort == null) _loading = null;
      rethrow;
    } finally {
      response.close();
      _busy = false;
    }
  }
}

@pragma('vm:entry-point')
void _yoloWorker(List<Object> initial) async {
  final ready = initial[0] as SendPort;
  final messages = ReceivePort();
  Interpreter? interpreter;
  try {
    final timer = Stopwatch()..start();
    final options = InterpreterOptions()..threads = initial[2] as int;
    try {
      interpreter = Interpreter.fromBuffer(
        (initial[1] as TransferableTypedData).materialize().asUint8List(),
        options: options,
      );
      interpreter.allocateTensors();
    } finally {
      options.delete();
    }
    final input = interpreter.getInputTensor(0);
    final output = interpreter.getOutputTensor(0);
    if (interpreter.getInputTensors().length != 1 ||
        interpreter.getOutputTensors().length != 1 ||
        input.type != TensorType.float32 ||
        output.type != TensorType.float32 ||
        input.shape.join(',') != '1,3,224,224' ||
        output.shape.join(',') != '1,6') {
      throw StateError(
        'Bentuk tensor model tidak cocok dengan YOLO penelitian.',
      );
    }
    timer.stop();
    ready.send({
      'port': messages.sendPort,
      'model_load_ms': timer.elapsedMicroseconds / 1000.0,
    });
    await for (final message in messages) {
      final request = message as List;
      final reply = request[1] as SendPort;
      try {
        final preprocessing = Stopwatch()..start();
        final prepared = prepareYoloImage(
          await File(request[0] as String).readAsBytes(),
        );
        preprocessing.stop();
        final scores = [List<double>.filled(wasteClasses.length, 0.0)];
        // ByteBuffer preserves the model's NCHW shape and float32 storage.
        interpreter.run(prepared.input.buffer, scores);
        final values = scores.single;
        final sum = values.fold<double>(0, (a, b) => a + b);
        if (values.any((v) => !v.isFinite || v < 0 || v > 1) ||
            (sum - 1).abs() > 0.01) {
          throw const FormatException('Probabilitas output model tidak valid.');
        }
        reply.send({
          'scores': values,
          'preview_png': prepared.previewPng,
          'preprocessing_ms': preprocessing.elapsedMicroseconds / 1000.0,
          'inference_ms':
              interpreter.lastNativeInferenceDurationMicroSeconds / 1000.0,
        });
      } catch (error) {
        reply.send({'error': error.toString()});
      }
    }
  } catch (error) {
    ready.send({'error': error.toString()});
  } finally {
    interpreter?.close();
    messages.close();
  }
}
