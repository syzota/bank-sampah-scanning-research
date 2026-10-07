import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const yoloImageSize = 224;
const yoloPreprocessingVersion =
    'rgb_exif_short224_pil_bilinear_center224_div255_nchw_v1';

class PreparedYoloImage {
  final Float32List input;
  final Uint8List previewPng;
  const PreparedYoloImage(this.input, this.previewPng);
}

/// YOLOv8n-cls: RGB, shortest edge 224, center crop, [0,1], NCHW.
/// Bilinear downsampling includes antialiasing, as in Pillow/torchvision.
PreparedYoloImage prepareYoloImage(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    throw const FormatException('Foto tidak terbaca. Gunakan JPG atau PNG.');
  }
  if (decoded == null) {
    throw const FormatException('Foto tidak terbaca. Gunakan JPG atau PNG.');
  }
  final image = img
      .bakeOrientation(decoded)
      .convert(format: img.Format.uint8, numChannels: 3);
  final width = image.width <= image.height
      ? yoloImageSize
      : (image.width * yoloImageSize ~/ image.height);
  final height = image.height <= image.width
      ? yoloImageSize
      : (image.height * yoloImageSize ~/ image.width);
  final resized = _resizeBilinear(image, width, height);
  final crop = img.copyCrop(
    resized,
    x: _halfRoundEven(width - yoloImageSize),
    y: _halfRoundEven(height - yoloImageSize),
    width: yoloImageSize,
    height: yoloImageSize,
  );
  const plane = yoloImageSize * yoloImageSize;
  final input = Float32List(3 * plane);
  for (var y = 0; y < yoloImageSize; y++) {
    for (var x = 0; x < yoloImageSize; x++) {
      final pixel = crop.getPixel(x, y);
      final index = y * yoloImageSize + x;
      input[index] = pixel.r / 255.0;
      input[plane + index] = pixel.g / 255.0;
      input[2 * plane + index] = pixel.b / 255.0;
    }
  }
  return PreparedYoloImage(input, Uint8List.fromList(img.encodePng(crop)));
}

// torchvision uses Python's ties-to-even rounding for the crop offset.
int _halfRoundEven(int difference) {
  final half = difference ~/ 2;
  return difference.isOdd && half.isOdd ? half + 1 : half;
}

class _Weights {
  final int start;
  final List<int> values;
  const _Weights(this.start, this.values);
}

const _precision = 22;
const _weightOne = 1 << _precision;

List<_Weights> _weights(int sourceSize, int targetSize) {
  final scale = sourceSize / targetSize;
  final filterScale = math.max(1.0, scale);
  return List.generate(targetSize, (out) {
    final center = (out + 0.5) * scale;
    final start = math.max(0, (center - filterScale + 0.5).toInt());
    final end = math.min(sourceSize, (center + filterScale + 0.5).toInt());
    final raw = <double>[];
    var total = 0.0;
    for (var i = start; i < end; i++) {
      final weight = math.max(
        0.0,
        1.0 - ((i - center + 0.5) / filterScale).abs(),
      );
      raw.add(weight);
      total += weight;
    }
    return _Weights(
      start,
      raw.map((w) => (w / total * _weightOne + 0.5).toInt()).toList(),
    );
  });
}

img.Image _resizeBilinear(img.Image source, int width, int height) {
  var horizontal = source;
  if (width != source.width) {
    horizontal = img.Image(width: width, height: source.height, numChannels: 3);
    final weights = _weights(source.width, width);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < width; x++) {
        final w = weights[x];
        var r = _weightOne ~/ 2;
        var g = r;
        var b = r;
        for (var i = 0; i < w.values.length; i++) {
          final pixel = source.getPixel(w.start + i, y);
          r += pixel.r.toInt() * w.values[i];
          g += pixel.g.toInt() * w.values[i];
          b += pixel.b.toInt() * w.values[i];
        }
        horizontal.setPixelRgb(
          x,
          y,
          (r >> _precision).clamp(0, 255),
          (g >> _precision).clamp(0, 255),
          (b >> _precision).clamp(0, 255),
        );
      }
    }
  }
  if (height == source.height) return horizontal;
  final output = img.Image(width: width, height: height, numChannels: 3);
  final weights = _weights(source.height, height);
  for (var y = 0; y < height; y++) {
    final w = weights[y];
    for (var x = 0; x < width; x++) {
      var r = _weightOne ~/ 2;
      var g = r;
      var b = r;
      for (var i = 0; i < w.values.length; i++) {
        final pixel = horizontal.getPixel(x, w.start + i);
        r += pixel.r.toInt() * w.values[i];
        g += pixel.g.toInt() * w.values[i];
        b += pixel.b.toInt() * w.values[i];
      }
      output.setPixelRgb(
        x,
        y,
        (r >> _precision).clamp(0, 255),
        (g >> _precision).clamp(0, 255),
        (b >> _precision).clamp(0, 255),
      );
    }
  }
  return output;
}
