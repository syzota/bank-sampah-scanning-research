import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../config/research_config.dart';
import '../utils/yolo_preprocessing.dart';
import '../utils/waste_image_crop.dart';
import '../../models/waste_scan_result.dart';
import 'local_database.dart';
import 'yolo_scan_service.dart';

class ScanRepository {
  ScanRepository._();
  static final instance = ScanRepository._();

  /// Every scan attempt is recorded, including failed and repeated scans.
  Future<WasteScanResult> scanAndRecord(
    String imagePath,
    String source, {
    WasteImageCrop? imageCrop,
  }) async {
    final service = YoloScanService.instance;
    final timer = Stopwatch()..start();
    final id = LocalDatabase.newId();
    final coldBefore = !service.hasRun;
    var imageHash = '';
    Map<String, dynamic>? output;
    Object? failure;
    try {
      imageHash = sha256
          .convert(await File(imagePath).readAsBytes())
          .toString();
      if (imageCrop != null &&
          (imageCrop.croppedPath != imagePath ||
              imageCrop.croppedSha256 != imageHash)) {
        throw StateError('Foto hasil pilihan berubah. Pilih objek kembali.');
      }
      output = await service.classify(imagePath);
    } catch (error) {
      failure = error;
    }
    timer.stop();
    final now = DateTime.now().toUtc().toIso8601String();
    final result = output == null
        ? null
        : WasteScanResult(
            id: id,
            imagePath: imagePath,
            imageSha256: imageHash,
            source: source,
            scores: List<double>.from(output['scores'] as List),
            preprocessingMs: (output['preprocessing_ms'] as num).toDouble(),
            inferenceMs: (output['inference_ms'] as num).toDouble(),
            totalMs: timer.elapsedMicroseconds / 1000.0,
            modelLoadMs: (output['model_load_ms'] as num).toDouble(),
            isColdStart: output['is_cold_start'] as bool,
            previewPng: output['preview_png'] as Uint8List,
          );
    final deviceId = await LocalDatabase.instance.setting('device_id');
    if (deviceId == null)
      throw StateError('Identitas instalasi lokal tidak ditemukan.');
    final compiledDeviceLabel = const String.fromEnvironment('DEVICE_LABEL');
    final db = LocalDatabase.instance.database;
    if (imageCrop != null) {
      await db.execute(wasteCropTableSql);
    }
    await db.transaction((txn) async {
      final previous = await txn.rawQuery(
        'SELECT COALESCE(MAX(scan_order), 0) AS last_order FROM hasil_scan WHERE device_id = ?',
        [deviceId],
      );
      await txn.insert('hasil_scan', {
        'id': id,
        'transaction_id': null,
        'image_path': imagePath,
        'image_sha256': imageHash,
        'source': source,
        'model_name': YoloScanService.modelName,
        'model_sha256': service.modelSha256,
        'preprocessing': yoloPreprocessingVersion,
        'seed_version': ResearchConfig.seedVersion,
        'cpu_threads': ResearchConfig.cpuThreads,
        'raw_label': result?.predictedClass.label,
        'raw_scores': result == null ? null : jsonEncode(result.scoresByLabel),
        'confidence': result?.confidence,
        'preprocessing_ms': result?.preprocessingMs,
        'inference_ms': result?.inferenceMs,
        'total_ms': timer.elapsedMicroseconds / 1000.0,
        'model_load_ms': result?.modelLoadMs,
        'scan_order': (previous.single['last_order'] as num).toInt() + 1,
        'device_id': deviceId,
        'device_label': compiledDeviceLabel.isEmpty
            ? Platform.operatingSystem
            : compiledDeviceLabel,
        'os_version': Platform.operatingSystemVersion,
        'app_version': ResearchConfig.appVersion,
        'is_cold_start': (result?.isColdStart ?? coldBefore) ? 1 : 0,
        'test_image_id': null,
        'ground_truth_label': null,
        'final_label': null,
        'status': result == null ? 'failed' : 'success',
        'error_message': failure?.toString(),
        'created_at': now,
        'updated_at': now,
      });
      if (imageCrop != null) {
        await txn.insert('scan_image_crops', imageCrop.toDatabaseRow(id));
      }
    });
    if (result == null) {
      throw StateError(failure?.toString() ?? 'Hasil scan tidak tersedia.');
    }
    return result;
  }

  /// Saves the transaction and links its latest applied scan atomically.
  /// User corrections update final_label; raw_label/raw_scores remain intact.
  Future<void> saveTransaction({
    required Map<String, Object?> payload,
    String? existingId,
    WasteScanResult? scan,
  }) async {
    final db = LocalDatabase.instance.database;
    final id = existingId ?? LocalDatabase.newId();
    final now = DateTime.now().toUtc().toIso8601String();
    final values = <String, Object?>{
      ...payload,
      if (existingId == null) 'id': id,
      if (existingId == null) 'created_at': now,
      'updated_at': now,
      'total_harga':
          (payload['jumlah'] as num).toDouble() *
          ((payload['harga_per_satuan'] as num?)?.toDouble() ?? 0),
    };
    await db.transaction((txn) async {
      if (existingId == null) {
        await txn.insert('pengelolaan_sampah', values);
      } else {
        final updated = await txn.update(
          'pengelolaan_sampah',
          values,
          where: 'id = ?',
          whereArgs: [id],
        );
        if (updated != 1)
          throw StateError('Data yang akan diedit tidak ditemukan.');
      }
      if (scan == null && existingId == null) return;
      final selected = await txn.query(
        'jenis_sampah',
        columns: ['model_label'],
        where: 'id = ?',
        whereArgs: [payload['jenis_sampah_id']],
        limit: 1,
      );
      if (selected.isEmpty || selected.single['model_label'] == null) {
        throw StateError('Jenis akhir tidak memiliki label penelitian.');
      }
      // Keep user decisions in sync when an existing transaction is edited.
      await txn.update(
        'hasil_scan',
        {'final_label': selected.single['model_label'], 'updated_at': now},
        where: 'transaction_id = ?',
        whereArgs: [id],
      );
      if (scan == null) return;
      final linked = await txn.update(
        'hasil_scan',
        {
          'transaction_id': id,
          'final_label': selected.single['model_label'],
          'updated_at': now,
        },
        where:
            "id = ? AND status = 'success' AND (transaction_id IS NULL OR transaction_id = ?)",
        whereArgs: [scan.id, id],
      );
      if (linked != 1)
        throw StateError('Hasil scan gagal dihubungkan ke data sampah.');
    });
  }
}
