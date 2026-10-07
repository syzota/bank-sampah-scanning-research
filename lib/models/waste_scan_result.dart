import 'dart:typed_data';

import '../core/config/research_config.dart';

class WasteScanResult {
  final String id;
  final String imagePath;
  final String imageSha256;
  final String source;
  final List<double> scores;
  final double preprocessingMs;
  final double inferenceMs;
  final double totalMs;
  final double modelLoadMs;
  final bool isColdStart;
  final Uint8List previewPng;

  WasteScanResult({
    required this.id,
    required this.imagePath,
    required this.imageSha256,
    required this.source,
    required List<double> scores,
    required this.preprocessingMs,
    required this.inferenceMs,
    required this.totalMs,
    required this.modelLoadMs,
    required this.isColdStart,
    required this.previewPng,
  }) : scores = List.unmodifiable(scores) {
    if (scores.length != wasteClasses.length ||
        scores.any((v) => !v.isFinite || v < 0 || v > 1)) {
      throw const FormatException('Output model bukan enam skor probabilitas.');
    }
  }

  int get predictedIndex {
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    return best;
  }

  WasteClass get predictedClass => wasteClasses[predictedIndex];
  double get confidence => scores[predictedIndex];
  Map<String, double> get scoresByLabel => {
    for (var i = 0; i < wasteClasses.length; i++)
      wasteClasses[i].label: scores[i],
  };
}
