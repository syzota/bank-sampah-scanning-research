import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/themes/app_colors.dart';
import '../../core/utils/waste_image_crop.dart';

class WasteObjectPickerView extends StatefulWidget {
  final String originalImagePath;
  final String outputImagePath;

  const WasteObjectPickerView({
    super.key,
    required this.originalImagePath,
    required this.outputImagePath,
  });

  @override
  State<WasteObjectPickerView> createState() => _WasteObjectPickerViewState();
}

class _WasteObjectPickerViewState extends State<WasteObjectPickerView> {
  WasteCropPreview? _preview;
  WasteCropRegion? _region;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  Offset? _dragStart;
  WasteCropRegion? _dragRegion;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final preview = await compute(
        prepareWasteCropPreview,
        widget.originalImagePath,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _region = WasteCropRegion.centered(
          preview.sourceWidth,
          preview.sourceHeight,
          (preview.sourceWidth * 0.65).round(),
          (preview.sourceHeight * 0.8).round(),
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Foto gagal dibuka: $error';
        _loading = false;
      });
    }
  }

  Future<void> _useSelection() async {
    final preview = _preview;
    final region = _region;
    if (preview == null || region == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final crop = await compute(
        saveWasteImageCrop,
        WasteCropRequest(
          originalPath: widget.originalImagePath,
          outputPath: widget.outputImagePath,
          expectedOriginalSha256: preview.originalSha256,
          region: region,
          preparationMs: preview.preparationMs,
        ),
      );
      if (!mounted) return;
      // Clear PopScope before returning the completed crop.
      setState(() => _saving = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(crop);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Pilihan belum tersimpan: $error';
      });
    }
  }

  void _resetSelection() {
    final preview = _preview;
    if (preview == null || _saving) return;
    setState(() {
      _region = WasteCropRegion.centered(
        preview.sourceWidth,
        preview.sourceHeight,
        (preview.sourceWidth * 0.65).round(),
        (preview.sourceHeight * 0.8).round(),
      );
    });
  }

  Widget _photoArea(WasteCropPreview preview, WasteCropRegion region) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(
          constraints.maxWidth / preview.sourceWidth,
          constraints.maxHeight / preview.sourceHeight,
        );
        final imageWidth = preview.sourceWidth * scale;
        final imageHeight = preview.sourceHeight * scale;
        final imageRect = Rect.fromLTWH(
          (constraints.maxWidth - imageWidth) / 2,
          (constraints.maxHeight - imageHeight) / 2,
          imageWidth,
          imageHeight,
        );
        final selection = Rect.fromLTWH(
          imageRect.left + region.left * scale,
          imageRect.top + region.top * scale,
          region.width * scale,
          region.height * scale,
        );

        Offset sourcePoint(Offset point) => Offset(
          (point.dx - imageRect.left) / scale,
          (point.dy - imageRect.top) / scale,
        );

        void placeAt(Offset point) {
          if (_saving || !imageRect.contains(point)) return;
          final source = sourcePoint(point);
          final current = _region!;
          setState(() {
            _region = current.moveTo(
              (source.dx - current.width / 2).round(),
              (source.dy - current.height / 2).round(),
            );
          });
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => placeAt(details.localPosition),
          onPanStart: (details) {
            if (_saving || !imageRect.contains(details.localPosition)) return;
            if (!selection.contains(details.localPosition)) {
              placeAt(details.localPosition);
            }
            _dragStart = sourcePoint(details.localPosition);
            _dragRegion = _region;
          },
          onPanUpdate: (details) {
            final start = _dragStart;
            final initial = _dragRegion;
            if (_saving || start == null || initial == null) return;
            final delta = sourcePoint(details.localPosition) - start;
            setState(() {
              _region = initial.moveTo(
                (initial.left + delta.dx).round(),
                (initial.top + delta.dy).round(),
              );
            });
          },
          onPanEnd: (_) {
            _dragStart = null;
            _dragRegion = null;
          },
          onPanCancel: () {
            _dragStart = null;
            _dragRegion = null;
          },
          child: SizedBox.expand(
            child: Stack(
              children: [
                Positioned.fromRect(
                  rect: imageRect,
                  child: Image.memory(preview.png, fit: BoxFit.fill),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _ObjectSelectionPainter(
                        imageRect: imageRect,
                        selection: selection,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final region = _region;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: const Color(0xFF131B16),
        appBar: AppBar(
          backgroundColor: const Color(0xFF131B16),
          foregroundColor: Colors.white,
          title: const Text('Pilih objek sampah'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
          ),
          actions: [
            TextButton(
              onPressed: _loading || _saving ? null : _resetSelection,
              child: const Text(
                'Atur ulang',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Masukkan satu objek utuh ke dalam kotak. Geser kotak '
                  'atau ketuk objek, lalu atur ukurannya di bawah.',
                  style: TextStyle(color: Colors.white, height: 1.4),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : preview == null || region == null
                      ? Center(
                          child: TextButton.icon(
                            onPressed: _loadPhoto,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba buka foto lagi'),
                          ),
                        )
                      : _photoArea(preview, region),
                ),
                if (preview != null && region != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              'Lebar kotak',
                              style: TextStyle(color: Colors.white),
                            ),
                            Slider(
                              activeColor: AppColors.pengelolaMain,
                              value: region.width.toDouble(),
                              min: 8,
                              max: preview.sourceWidth.toDouble(),
                              onChanged: _saving || preview.sourceWidth == 8
                                  ? null
                                  : (value) => setState(() {
                                      _region = _region!.resize(
                                        width: value.round(),
                                      );
                                    }),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              'Tinggi kotak',
                              style: TextStyle(color: Colors.white),
                            ),
                            Slider(
                              activeColor: AppColors.pengelolaMain,
                              value: region.height.toDouble(),
                              min: 8,
                              max: preview.sourceHeight.toDouble(),
                              onChanged: _saving || preview.sourceHeight == 8
                                  ? null
                                  : (value) => setState(() {
                                      _region = _region!.resize(
                                        height: value.round(),
                                      );
                                    }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFFFB4AB)),
                    ),
                  ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.pengelolaMain,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _loading || _saving || region == null
                      ? null
                      : _useSelection,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_saving ? 'Menyiapkan foto…' : 'Gunakan pilihan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ObjectSelectionPainter extends CustomPainter {
  final Rect imageRect;
  final Rect selection;

  _ObjectSelectionPainter({required this.imageRect, required this.selection});

  @override
  void paint(Canvas canvas, Size size) {
    final shaded = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(imageRect)
      ..addRect(selection);
    canvas.drawPath(shaded, Paint()..color = const Color(0x99000000));
    canvas.drawRect(
      selection,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final guide = Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = selection.left + selection.width * i / 3;
      final y = selection.top + selection.height * i / 3;
      canvas.drawLine(
        Offset(x, selection.top),
        Offset(x, selection.bottom),
        guide,
      );
      canvas.drawLine(
        Offset(selection.left, y),
        Offset(selection.right, y),
        guide,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ObjectSelectionPainter oldDelegate) =>
      oldDelegate.imageRect != imageRect || oldDelegate.selection != selection;
}
