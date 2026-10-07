import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

const manualCropVersion = 'manual_rect_white_square_after_exif_v1';

/// A lazy, additive table: existing SQLite files and scan rows remain usable.
const wasteCropTableSql = '''
CREATE TABLE IF NOT EXISTS scan_image_crops (
  scan_id TEXT NOT NULL PRIMARY KEY REFERENCES hasil_scan(id) ON DELETE CASCADE,
  selection_mode TEXT NOT NULL,
  original_image_path TEXT NOT NULL,
  original_image_sha256 TEXT NOT NULL,
  cropped_image_sha256 TEXT NOT NULL,
  source_width INTEGER NOT NULL CHECK(source_width >= 8),
  source_height INTEGER NOT NULL CHECK(source_height >= 8),
  crop_left INTEGER NOT NULL CHECK(crop_left >= 0),
  crop_top INTEGER NOT NULL CHECK(crop_top >= 0),
  crop_width INTEGER NOT NULL CHECK(crop_width >= 8),
  crop_height INTEGER NOT NULL CHECK(crop_height >= 8),
  output_size INTEGER NOT NULL,
  pad_left INTEGER NOT NULL CHECK(pad_left >= 0),
  pad_top INTEGER NOT NULL CHECK(pad_top >= 0),
  preview_preparation_ms REAL NOT NULL,
  cropping_ms REAL NOT NULL,
  CHECK(crop_left + crop_width <= source_width),
  CHECK(crop_top + crop_height <= source_height),
  CHECK(output_size >= crop_width AND output_size >= crop_height),
  CHECK(pad_left + crop_width <= output_size),
  CHECK(pad_top + crop_height <= output_size)
)
''';

/// Coordinates refer to the original photo after applying EXIF orientation.
class WasteCropRegion {
  final int sourceWidth;
  final int sourceHeight;
  final int left;
  final int top;
  final int width;
  final int height;

  WasteCropRegion({
    required this.sourceWidth,
    required this.sourceHeight,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  }) {
    if (sourceWidth < 8 ||
        sourceHeight < 8 ||
        width < 8 ||
        height < 8 ||
        left < 0 ||
        top < 0 ||
        left + width > sourceWidth ||
        top + height > sourceHeight) {
      throw ArgumentError('Kotak pilihan berada di luar foto.');
    }
  }

  int get outputSize => math.max(width, height);
  int get padLeft => (outputSize - width) ~/ 2;
  int get padTop => (outputSize - height) ~/ 2;

  factory WasteCropRegion.centered(
    int sourceWidth,
    int sourceHeight,
    int width,
    int height,
  ) {
    if (sourceWidth < 8 || sourceHeight < 8) {
      throw ArgumentError('Resolusi foto terlalu kecil.');
    }
    final cropWidth = width.clamp(8, sourceWidth).toInt();
    final cropHeight = height.clamp(8, sourceHeight).toInt();
    return WasteCropRegion.clamped(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      left: (sourceWidth - cropWidth) ~/ 2,
      top: (sourceHeight - cropHeight) ~/ 2,
      width: cropWidth,
      height: cropHeight,
    );
  }

  factory WasteCropRegion.clamped({
    required int sourceWidth,
    required int sourceHeight,
    required int left,
    required int top,
    required int width,
    required int height,
  }) {
    if (sourceWidth < 8 || sourceHeight < 8) {
      throw ArgumentError('Resolusi foto terlalu kecil.');
    }
    final cropWidth = width.clamp(8, sourceWidth).toInt();
    final cropHeight = height.clamp(8, sourceHeight).toInt();
    return WasteCropRegion(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      left: left.clamp(0, sourceWidth - cropWidth).toInt(),
      top: top.clamp(0, sourceHeight - cropHeight).toInt(),
      width: cropWidth,
      height: cropHeight,
    );
  }

  WasteCropRegion moveTo(int x, int y) => WasteCropRegion.clamped(
    sourceWidth: sourceWidth,
    sourceHeight: sourceHeight,
    left: x,
    top: y,
    width: width,
    height: height,
  );

  WasteCropRegion resize({int? width, int? height}) {
    final cropWidth = (width ?? this.width).clamp(8, sourceWidth).toInt();
    final cropHeight = (height ?? this.height).clamp(8, sourceHeight).toInt();
    return WasteCropRegion.clamped(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      left: (left + this.width / 2 - cropWidth / 2).round(),
      top: (top + this.height / 2 - cropHeight / 2).round(),
      width: cropWidth,
      height: cropHeight,
    );
  }
}

class WasteCropPreview {
  final Uint8List png;
  final int sourceWidth;
  final int sourceHeight;
  final String originalSha256;
  final double preparationMs;

  const WasteCropPreview({
    required this.png,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.originalSha256,
    required this.preparationMs,
  });
}

class WasteCropRequest {
  final String originalPath;
  final String outputPath;
  final String expectedOriginalSha256;
  final WasteCropRegion region;
  final double preparationMs;

  const WasteCropRequest({
    required this.originalPath,
    required this.outputPath,
    required this.expectedOriginalSha256,
    required this.region,
    required this.preparationMs,
  });
}

class WasteImageCrop {
  final String originalPath;
  final String croppedPath;
  final String originalSha256;
  final String croppedSha256;
  final WasteCropRegion region;
  final double preparationMs;
  final double croppingMs;

  const WasteImageCrop({
    required this.originalPath,
    required this.croppedPath,
    required this.originalSha256,
    required this.croppedSha256,
    required this.region,
    required this.preparationMs,
    required this.croppingMs,
  });

  Map<String, Object?> toDatabaseRow(String scanId) => {
    'scan_id': scanId,
    'selection_mode': manualCropVersion,
    'original_image_path': originalPath,
    'original_image_sha256': originalSha256,
    'cropped_image_sha256': croppedSha256,
    'source_width': region.sourceWidth,
    'source_height': region.sourceHeight,
    'crop_left': region.left,
    'crop_top': region.top,
    'crop_width': region.width,
    'crop_height': region.height,
    'output_size': region.outputSize,
    'pad_left': region.padLeft,
    'pad_top': region.padTop,
    'preview_preparation_ms': preparationMs,
    'cropping_ms': croppingMs,
  };
}

img.Image _decodeUpright(Uint8List bytes) {
  img.Image? image;
  try {
    image = img.decodeImage(bytes);
  } catch (_) {
    throw const FormatException('Foto tidak terbaca. Gunakan JPG atau PNG.');
  }
  if (image == null) {
    throw const FormatException('Foto tidak terbaca. Gunakan JPG atau PNG.');
  }
  final upright = img
      .bakeOrientation(image)
      .convert(format: img.Format.uint8, numChannels: 3);
  if (math.min(upright.width, upright.height) < 8) {
    throw const FormatException('Resolusi foto terlalu kecil.');
  }
  return upright;
}

/// Run with compute(): only this display preview is downscaled.
/// The saved crop is cut from the full-resolution, upright original.
WasteCropPreview prepareWasteCropPreview(String originalPath) {
  final timer = Stopwatch()..start();
  final bytes = File(originalPath).readAsBytesSync();
  final image = _decodeUpright(bytes);
  final longest = math.max(image.width, image.height);
  final preview = longest <= 1200
      ? image
      : img.copyResize(
          image,
          width: math.max(1, (image.width * 1200 / longest).round()),
          height: math.max(1, (image.height * 1200 / longest).round()),
          interpolation: img.Interpolation.average,
        );
  final png = Uint8List.fromList(img.encodePng(preview));
  final hash = sha256.convert(bytes).toString();
  timer.stop();
  return WasteCropPreview(
    png: png,
    sourceWidth: image.width,
    sourceHeight: image.height,
    originalSha256: hash,
    preparationMs: timer.elapsedMicroseconds / 1000.0,
  );
}

/// This worker contains no Flutter objects, so image processing stays off UI.
WasteImageCrop saveWasteImageCrop(WasteCropRequest request) {
  final timer = Stopwatch()..start();
  if (request.originalPath == request.outputPath) {
    throw ArgumentError('Hasil crop harus disimpan sebagai foto terpisah.');
  }
  final bytes = File(request.originalPath).readAsBytesSync();
  final originalHash = sha256.convert(bytes).toString();
  if (originalHash != request.expectedOriginalSha256) {
    throw StateError('Foto berubah. Pilih objek kembali.');
  }
  final image = _decodeUpright(bytes);
  final region = request.region;
  if (image.width != region.sourceWidth ||
      image.height != region.sourceHeight) {
    throw StateError('Ukuran foto berubah. Pilih objek kembali.');
  }
  final crop = img.copyCrop(
    image,
    x: region.left,
    y: region.top,
    width: region.width,
    height: region.height,
  );
  // Preserve the whole rectangle and its aspect ratio. A square canvas avoids
  // the classifier's center crop cutting off the selected object's ends.
  final square = img.Image(
    width: region.outputSize,
    height: region.outputSize,
    numChannels: 3,
  );
  img.fill(square, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(square, crop, dstX: region.padLeft, dstY: region.padTop);
  final encoded = Uint8List.fromList(img.encodePng(square));
  final output = File(request.outputPath);
  output.parent.createSync(recursive: true);
  output.writeAsBytesSync(encoded, flush: true);
  final croppedHash = sha256.convert(encoded).toString();
  timer.stop();
  return WasteImageCrop(
    originalPath: request.originalPath,
    croppedPath: request.outputPath,
    originalSha256: originalHash,
    croppedSha256: croppedHash,
    region: region,
    preparationMs: request.preparationMs,
    croppingMs: timer.elapsedMicroseconds / 1000.0,
  );
}
