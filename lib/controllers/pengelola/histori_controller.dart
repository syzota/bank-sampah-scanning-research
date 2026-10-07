import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:excel/excel.dart' as excel;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/services/local_data_service.dart';
import '../../core/services/session_service.dart';
import '../../core/constants/data_tables.dart';
import '../../core/utils/format_helper.dart';
import '../../models/pengelolaan_sampah_model.dart';
import '../../models/kategori_model.dart';
import '../../app/routes/app_routes.dart';

class HistoriController extends GetxController {
  final searchController = TextEditingController();
  final searchQuery = ''.obs;

  final listHistori = <PengelolaanSampahModel>[].obs;
  final _rawHistori = <PengelolaanSampahModel>[];
  final listKategoriFilter = <KategoriModel>[].obs;
  final listNamaNasabah = <String>[].obs;
  final isLoading = false.obs;
  final isExporting = false.obs;

  /// Periode cepat dari chip header: 'all' | 'week' | 'month'.
  final periode = 'all'.obs;

  /// Statistik bulan berjalan — untuk heading "hidup" di header.
  final transaksiBulanIni = 0.obs;
  final beratBulanIni = 0.0.obs;

  // Filter
  final filterKategoriId = ''.obs;
  final filterTanggalMulai = Rx<DateTime?>(null);
  final filterTanggalAkhir = Rx<DateTime?>(null);
  final filterNamaNasabah = ''.obs;

  bool get isFilterActive =>
      filterKategoriId.value.isNotEmpty ||
      filterTanggalMulai.value != null ||
      filterTanggalAkhir.value != null ||
      filterNamaNasabah.value.isNotEmpty;

  double get totalNilai =>
      listHistori.fold(0.0, (sum, e) => sum + (e.totalHarga ?? 0.0));

  @override
  void onInit() {
    super.onInit();
    // Trigger filter lokal saat search berubah (tanpa fetch ulang ke server)
    debounce(
      searchQuery,
      (_) => _applySearchFilter(),
      time: const Duration(milliseconds: 300),
    );

    // Defer navigasi dan fetch agar tidak dipanggil saat build berlangsung
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bankSampahId = SessionService.to.activeBankSampahIdOrNull;
      if (bankSampahId == null) {
        Get.offAllNamed(AppRoutes.pilihBankSampah);
        return;
      }
      fetchHistori();
      _fetchKategori();
      fetchNamaNasabah();
    });
  }

  // Filter lokal dari _rawHistori berdasarkan searchQuery + periode
  void _applySearchFilter() {
    Iterable<PengelolaanSampahModel> items = _rawHistori;

    final now = DateTime.now();
    switch (periode.value) {
      case 'week':
        final start = now.subtract(Duration(days: now.weekday - 1));
        final startDay = DateTime(start.year, start.month, start.day);
        items = items.where((e) => !e.tanggalPengelolaan.isBefore(startDay));
      case 'month':
        final startDay = DateTime(now.year, now.month, 1);
        items = items.where((e) => !e.tanggalPengelolaan.isBefore(startDay));
    }

    final q = searchQuery.value.toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((item) {
        return item.namaItem.toLowerCase().contains(q) ||
            item.breadcrumb.toLowerCase().contains(q) ||
            (item.catatan?.toLowerCase().contains(q) ?? false);
      });
    }

    listHistori.value = items.toList();
  }

  /// Ganti periode chip (Semua / Minggu Ini / Bulan Ini) — filter lokal.
  void setPeriode(String p) {
    periode.value = p;
    _applySearchFilter();
  }

  /// Hitung statistik bulan berjalan dari data mentah.
  void _hitungStatistikBulan() {
    final now = DateTime.now();
    final startDay = DateTime(now.year, now.month, 1);
    final bulanIni = _rawHistori
        .where((e) => !e.tanggalPengelolaan.isBefore(startDay))
        .toList();
    transaksiBulanIni.value = bulanIni.length;
    beratBulanIni.value = bulanIni.fold(
        0.0,
        (sum, e) =>
            sum +
            ((e.satuan?.singkatan.toLowerCase() == 'kg')
                ? e.jumlah
                : 0.0));
  }

  void onSearch(String value) => searchQuery.value = value;

  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
  }

  Future<void> fetchHistori() async {
    // FIX: guard jika bank sampah belum dipilih
    final bankSampahId = SessionService.to.activeBankSampahIdOrNull;
    if (bankSampahId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed(AppRoutes.pilihBankSampah);
      });
      return;
    }

    isLoading.value = true;
    try {
      var query = LocalDataService.client
          .from(DataTables.tablePengelolaanSampah)
          .select('''
            *,
            kategori_sampah(*),
            sub_kategori_sampah(*),
            tipe_sampah(*),
            jenis_sampah(*, tipe_sampah(*)),
            satuan(*)
          ''')
          .eq('bank_sampah_id', bankSampahId);

      if (filterKategoriId.value.isNotEmpty) {
        query = query.eq('kategori_id', filterKategoriId.value);
      }
      if (filterNamaNasabah.value.isNotEmpty) {
        query = query.eq('nama_nasabah', filterNamaNasabah.value);
      }
      if (filterTanggalMulai.value != null) {
        query = query.gte(
          'tanggal_pengelolaan',
          filterTanggalMulai.value!.toIso8601String().split('T').first,
        );
      }
      if (filterTanggalAkhir.value != null) {
        query = query.lte(
          'tanggal_pengelolaan',
          filterTanggalAkhir.value!.toIso8601String().split('T').first,
        );
      }

      final data =
          await query.order('tanggal_pengelolaan', ascending: false);

      var list = (data as List)
          .map((e) => PengelolaanSampahModel.fromJson(e))
          .toList();

      _rawHistori
        ..clear()
        ..addAll(list);
      _hitungStatistikBulan();
      _applySearchFilter();
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat histori.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _fetchKategori() async {
    try {
      final data = await LocalDataService.client
          .from(DataTables.tableKategoriSampah)
          .select()
          .eq('is_active', true)
          .order('nama');
      listKategoriFilter.value =
          (data as List).map((e) => KategoriModel.fromJson(e)).toList();
    } catch (_) {}
  }

  Future<void> fetchNamaNasabah() async {
    final bankSampahId = SessionService.to.activeBankSampahIdOrNull;
    if (bankSampahId == null) return;
    try {
      final data = await LocalDataService.client
          .from(DataTables.tablePengelolaanSampah)
          .select('nama_nasabah')
          .eq('bank_sampah_id', bankSampahId);

      final names = (data as List)
          .map((e) => e['nama_nasabah'] as String?)
          .where((name) => name != null && name.trim().isNotEmpty)
          .map((name) => name!.trim())
          .toSet()
          .toList();

      names.sort((a, b) => a.compareTo(b));
      listNamaNasabah.value = names;
    } catch (e) {
      debugPrint('ERROR FETCH NASABAH IN HISTORI: $e');
    }
  }

  Future<void> pickTanggalMulai(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: filterTanggalMulai.value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) filterTanggalMulai.value = picked;
  }

  Future<void> pickTanggalAkhir(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: filterTanggalAkhir.value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) filterTanggalAkhir.value = picked;
  }

  void applyFilter() => fetchHistori();

  void resetFilter() {
    filterKategoriId.value = '';
    filterTanggalMulai.value = null;
    filterTanggalAkhir.value = null;
    filterNamaNasabah.value = '';
    searchController.clear();
    searchQuery.value = '';
    fetchHistori();
  }

  Future<void> editItem(PengelolaanSampahModel data) async {
    final result = await Get.toNamed(AppRoutes.inputSampah, arguments: data);
    if (result == true) fetchHistori();
  }

  Future<void> deleteItem(PengelolaanSampahModel data) async {
    final confirm = await showDialog<bool>(
      context: Get.context!,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Data'),
        content: const Text('Yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await LocalDataService.client
          .from(DataTables.tablePengelolaanSampah)
          .delete()
          .eq('id', data.id);
      _rawHistori.removeWhere((e) => e.id == data.id);
      listHistori.removeWhere((e) => e.id == data.id);
      Get.snackbar('Berhasil', 'Data berhasil dihapus.');
    } catch (e) {
      Get.snackbar('Gagal', 'Data gagal dihapus.');
    }
  }

  Future<void> refresh() => fetchHistori();

  Future<void> exportExcel() async {
    isExporting.value = true;
    try {
      if (_rawHistori.isEmpty) {
        await fetchHistori();
      }
      if (_rawHistori.isEmpty) {
        Get.snackbar('Info', 'Tidak ada data untuk diexport.');
        return;
      }

      final namaBankSampah = SessionService.to.activeBankSampahNama;
      
      // Tentukan label periode filter aktif
      String labelPeriode = 'Semua Data';
      if (filterTanggalMulai.value != null || filterTanggalAkhir.value != null) {
        if (filterTanggalMulai.value != null && filterTanggalAkhir.value != null) {
          labelPeriode = 'Periode: ${FormatHelper.date(filterTanggalMulai.value)} - ${FormatHelper.date(filterTanggalAkhir.value)}';
        } else if (filterTanggalMulai.value != null) {
          labelPeriode = 'Mulai: ${FormatHelper.date(filterTanggalMulai.value)}';
        } else {
          labelPeriode = 'Sampai: ${FormatHelper.date(filterTanggalAkhir.value)}';
        }
      }
      if (filterNamaNasabah.value.isNotEmpty) {
        labelPeriode += ' | Nasabah: ${filterNamaNasabah.value}';
      }

      final excelFile = excel.Excel.createExcel();
      
      // Ambil sheet default bawaan (biasanya 'Sheet1') dan ganti namanya agar tidak tersisa sheet kosong
      final defaultSheet = excelFile.sheets.keys.first;
      excelFile.rename(defaultSheet, 'Laporan Pengelolaan');
      final sheet = excelFile['Laporan Pengelolaan'];
      
      // Hapus sheet default bawaan lain jika ada
      final sheetsToDelete = excelFile.sheets.keys.where((k) => k != 'Laporan Pengelolaan').toList();
      for (final key in sheetsToDelete) {
        excelFile.delete(key);
      }

      // ── Helper style ────────────────────────────────────────────
      excel.CellStyle styleHeader() => excel.CellStyle(
            bold: true,
            horizontalAlign: excel.HorizontalAlign.Center,
            verticalAlign: excel.VerticalAlign.Center,
            backgroundColorHex: excel.ExcelColor.fromHexString('#D9D9D9'),
            leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
            rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
            topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
            bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
          );

      excel.CellStyle styleData() => excel.CellStyle(
            leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
            rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
            topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
            bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
          );

      int rowIdx = 0;

      // Baris 1: Judul
      final cellJudul = sheet.cell(
          excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx));
      cellJudul.value = excel.TextCellValue('LAPORAN PENGELOLAAN SAMPAH - ${namaBankSampah.toUpperCase()}');
      cellJudul.cellStyle = excel.CellStyle(bold: true);
      rowIdx++;

      // Baris 2: Periode
      final cellPeriode = sheet.cell(
          excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx));
      cellPeriode.value = excel.TextCellValue(labelPeriode);
      rowIdx++;

      // Baris kosong
      rowIdx++;

      // Baris Header Kolom
      final headerCols = [
        'Tanggal',
        'Kategori',
        'Sub Kategori',
        'Tipe',
        'Jenis Sampah',
        'Jumlah',
        'Satuan',
        'Harga/Satuan',
        'Total Harga',
        'Catatan'
      ];

      for (int i = 0; i < headerCols.length; i++) {
        final cell = sheet.cell(
            excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIdx));
        cell.value = excel.TextCellValue(headerCols[i]);
        cell.cellStyle = styleHeader();
      }
      rowIdx++;

      // Tulis data (diurutkan tanggal ascending agar laporan kronologis)
      final sortedData = List<PengelolaanSampahModel>.from(_rawHistori)
        ..sort((a, b) => a.tanggalPengelolaan.compareTo(b.tanggalPengelolaan));

      for (final item in sortedData) {
        final dataRow = [
          FormatHelper.date(item.tanggalPengelolaan),
          item.kategori?.nama ?? '',
          item.subKategori?.nama ?? '',
          item.tipe?.nama ?? '',
          item.jenisSampah?.nama ?? '',
          FormatHelper.number(item.jumlah),
          item.satuan?.nama ?? '',
          FormatHelper.currency(item.hargaPerSatuan),
          FormatHelper.currency(item.totalHarga),
          item.catatan ?? ''
        ];

        for (int i = 0; i < dataRow.length; i++) {
          final cell = sheet.cell(
              excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIdx));
          cell.value = excel.TextCellValue(dataRow[i]);
          cell.cellStyle = styleData();
        }
        rowIdx++;
      }

      final bytes = excelFile.encode();
      if (bytes == null) throw Exception('Gagal membuat byte data Excel.');

      final cleanBankNama = namaBankSampah
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '_')
          .replaceAll(RegExp(r'[^a-z0-9_]'), '');
      final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14);
      final fileName = 'laporan_${cleanBankNama}_$timestamp.xlsx';
      final shareText = 'Laporan Pengelolaan Sampah - $namaBankSampah';

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: shareText,
      );
      
      Get.snackbar(
        'Sukses',
        'Laporan Excel berhasil diexport dan siap dibagikan.',
      );
    } catch (e) {
      Get.snackbar('Gagal', 'Export Excel gagal: $e');
    } finally {
      isExporting.value = false;
    }
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}
