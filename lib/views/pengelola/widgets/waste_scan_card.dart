import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/themes/app_colors.dart';
import '../../../controllers/pengelola/input_sampah_controller.dart';
import '../../../core/config/research_config.dart';
import 'input_sampah_widgets.dart';

class WasteScanCard extends StatelessWidget {
  final InputSampahController controller;
  const WasteScanCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final busy = controller.isScanBusy || controller.isLoading.value;
      final result = controller.scanResult.value;
      final path = controller.scanPhotoPath.value;
      final supported = controller.isScanSupported;
      final hasSelection = controller.scanCrop.value != null;
      final chosen = controller.listJenisSampah.firstWhereOrNull(
        (j) => j.id == controller.selectedJenisId.value,
      );
      final indices = result == null
          ? <int>[]
          : List.generate(result.scores.length, (i) => i);
      if (result != null) {
        indices.sort((a, b) => result.scores[b].compareTo(result.scores[a]));
      }
      return SectionCard(
        title: 'Scan Sampah — YOLO',
        icon: Icons.document_scanner_outlined,
        iconColor: AppColors.pengelolaMain,
        iconBg: AppColors.pengelolaLight,
        accentColor: AppColors.pengelolaMain,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              supported
                  ? 'Ambil atau pilih foto, tentukan satu objek sampah, lalu scan. Periksa hasil sebelum menyimpan.'
                  : 'Scan tersedia pada aplikasi Android. Form input tetap bisa digunakan di Windows.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Kamera'),
                  onPressed: !supported || busy
                      ? null
                      : () => controller.pickScanPhoto(ImageSource.camera),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galeri'),
                  onPressed: !supported || busy
                      ? null
                      : () => controller.pickScanPhoto(ImageSource.gallery),
                ),
                if (path.isNotEmpty)
                  TextButton(
                    onPressed: busy ? null : controller.clearScanPhoto,
                    child: const Text('Lepas foto'),
                  ),
              ],
            ),
            if (path.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: result == null
                    ? Image.file(
                        File(path),
                        height: 210,
                        cacheWidth: 768,
                        fit: BoxFit.contain,
                        errorBuilder: (_, error, stack) => const SizedBox(
                          height: 80,
                          child: Center(
                            child: Text('Pratinjau foto tidak tersedia.'),
                          ),
                        ),
                      )
                    : Image.memory(
                        result.previewPng,
                        height: 210,
                        fit: BoxFit.contain,
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                result == null
                    ? (hasSelection
                          ? 'Objek yang dipilih'
                          : 'Foto terpilih — pilih objek sebelum scan')
                    : 'Objek yang dianalisis',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.crop),
                label: Text(
                  hasSelection ? 'Ubah pilihan objek' : 'Pilih objek',
                ),
                onPressed: !supported || busy
                    ? null
                    : controller.chooseScanObject,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: controller.isScanning.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded),
                label: Text(
                  controller.isScanning.value ? 'Memproses foto…' : 'Scan Foto',
                ),
                onPressed: !supported || busy || !hasSelection
                    ? null
                    : controller.scanSelectedPhoto,
              ),
            ],
            if (controller.isPickingPhoto.value ||
                controller.isCroppingPhoto.value)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            if (controller.scanError.value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  controller.scanError.value,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            if (result != null) ...[
              const SizedBox(height: 16),
              Text(
                'Prediksi: ${result.predictedClass.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Skor model: ${(result.confidence * 100).toStringAsFixed(1)}%',
              ),
              Text('Waktu scan: ${result.totalMs.toStringAsFixed(0)} ms'),
              const SizedBox(height: 8),
              Text("Pilihan akhir: ${chosen?.nama ?? 'Belum dipilih'}"),
              const Text('Kamu bisa mengubah jenis sampah di bawah.'),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Lihat skor enam jenis'),
                children: [
                  for (final i in indices)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(wasteClasses[i].name)),
                          Text(
                            '${(result.scores[i] * 100).toStringAsFixed(1)}%',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }
}
