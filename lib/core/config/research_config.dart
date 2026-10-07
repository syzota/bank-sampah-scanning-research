import 'package:flutter/services.dart';

enum ResearchModel { yolo, mobilenet }

/// Each Android flavor selects its own model. No network configuration exists.
class ResearchConfig {
  ResearchConfig._();

  static ResearchModel get model {
    final name = appFlavor ??
        const String.fromEnvironment('MODEL', defaultValue: 'mobilenet');
    return switch (name) {
      'yolo' => ResearchModel.yolo,
      'mobilenet' => ResearchModel.mobilenet,
      _ => throw StateError('Varian penelitian tidak dikenal: $name'),
    };
  }

  static String get modelName =>
      model == ResearchModel.yolo ? 'YOLOv8n-cls' : 'MobileNetV2';
  static String get modelAsset => model == ResearchModel.yolo
      ? 'assets/models/best.tflite'
      : 'assets/models/mobnet_model_quantized.tflite';
  static String get preprocessing => model == ResearchModel.yolo
      ? 'rgb_center_crop_224_bilinear_div255_nchw_v1'
      : 'rgb_resize_224_nearest_div255_nhwc_v1';
  static const schemaVersion = 1;
  static const seedVersion = 'research-six-classes-v1';
  static const cpuThreads = 1;
  static const appVersion = '0.1.0+1';
  static const categoryId = 'research-category';
  static const demoBankId = 'research-bank';
}

class WasteClass {
  final String label;
  final String name;
  const WasteClass(this.label, this.name);
  String get id => 'research-$label';
}

/// Order checked against the YOLO metadata and MobileNet training notebook.
const wasteClasses = <WasteClass>[
  WasteClass('cardboard', 'Kardus'),
  WasteClass('glass', 'Kaca'),
  WasteClass('metal', 'Logam'),
  WasteClass('paper', 'Kertas'),
  WasteClass('plastic', 'Plastik'),
  WasteClass('trash', 'Sampah lainnya/residu'),
];
