import 'package:get/get.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';

import '../../core/utils/file_saver_helper.dart';

import '../../core/services/local_data_service.dart';
import '../../core/constants/data_tables.dart';
import '../../core/utils/format_helper.dart';
import '../../models/bank_sampah_model.dart';
import '../../models/kategori_model.dart';
import '../../models/sub_kategori_model.dart';
import '../../models/tipe_sampah_model.dart';
import '../../models/jenis_sampah_model.dart';
import '../../models/pengelolaan_sampah_model.dart';


enum JenisLaporan {
  ringkasanMonitoring,
  rekapTransaksi,
  statistikKategori,
  aktivitasBankSampah,
}


class LaporanController extends GetxController {

  // Tambah di bagian atas variabel controller
  final listAllKategori = <KategoriModel>[].obs;
  final listAllSubKategori = <SubKategoriModel>[].obs;
  final listAllJenisSampah = <JenisSampahModel>[].obs;
  final listAllTipeSampah = <TipeSampahModel>[].obs;
  final listBankSampah = <BankSampahModel>[].obs;
  final selectedBankSampah = Rx<BankSampahModel?>(null);
  final selectedJenisLaporan =
      Rx<JenisLaporan>(JenisLaporan.rekapTransaksi);
  final selectedTanggalMulai = Rx<DateTime?>(null);
  final selectedTanggalAkhir = Rx<DateTime?>(null);

  final isLoading = false.obs;
  final isGenerating = false.obs;

  // Data hasil query untuk preview
  final previewData = <PengelolaanSampahModel>[].obs;
  final hasPreview = false.obs;

  final jenisLaporanOptions = {
    JenisLaporan.ringkasanMonitoring: 'Ringkasan Monitoring',
    JenisLaporan.rekapTransaksi: 'Rekap Transaksi Sampah',
    JenisLaporan.statistikKategori: 'Statistik Kategori Sampah',
    JenisLaporan.aktivitasBankSampah: 'Aktivitas Bank Sampah',
  };

@override
void onInit() {
  super.onInit();
  _fetchBankSampah();
  _fetchMasterData(); // tambah ini
  final now = DateTime.now();
  selectedTanggalMulai.value = DateTime(now.year, now.month, 1);
  selectedTanggalAkhir.value = DateTime(now.year, now.month + 1, 0);
}

  Future<void> _fetchBankSampah() async {
    isLoading.value = true;
    try {
      final data = await LocalDataService.client
          .from(DataTables.tableBankSampah)
          .select()
          .order('nama');
      listBankSampah.value =
          (data as List).map((e) => BankSampahModel.fromJson(e)).toList();
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat daftar bank sampah.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _fetchMasterData() async {
  try {
    final resKategori = await LocalDataService.client
        .from(DataTables.tableKategoriSampah)
        .select()
        .eq('is_active', true)
        .order('urutan');
    listAllKategori.value = (resKategori as List)
        .map((e) => KategoriModel.fromJson(e))
        .toList();

    final resSubKategori = await LocalDataService.client
        .from(DataTables.tableSubKategoriSampah)
        .select()
        .eq('is_active', true)
        .order('urutan');
    listAllSubKategori.value = (resSubKategori as List)
        .map((e) => SubKategoriModel.fromJson(e))
        .toList();

    final resTipe = await LocalDataService.client
        .from(DataTables.tableTipeSampah)
        .select()
        .eq('is_active', true)
        .order('urutan');
    listAllTipeSampah.value = (resTipe as List)
        .map((e) => TipeSampahModel.fromJson(e))
        .toList();

    final resJenis = await LocalDataService.client
        .from(DataTables.tableJenisSampah)
        .select()
        .eq('is_active', true)
        .order('urutan');
    listAllJenisSampah.value = (resJenis as List)
        .map((e) => JenisSampahModel.fromJson(e))
        .toList();
  } catch (e) {
    Get.snackbar('Error', 'Gagal memuat master data: $e');
  }
}

  bool get isValid =>
      selectedTanggalMulai.value != null &&
      selectedTanggalAkhir.value != null;

  Future<List<PengelolaanSampahModel>> _fetchDataLaporan() async {
    var query = LocalDataService.client
        .from(DataTables.tablePengelolaanSampah)
        .select('''
          *,
          kategori_sampah(*),
          sub_kategori_sampah(*),
          tipe_sampah(*),
          jenis_sampah(*, tipe_sampah(*)),
          satuan(*),
          bank_sampah(*),
          profiles(*)
        ''')
        .gte(
          'tanggal_pengelolaan',
          FormatHelper.dateToInput(selectedTanggalMulai.value!),
        )
        .lte(
          'tanggal_pengelolaan',
          FormatHelper.dateToInput(selectedTanggalAkhir.value!),
        );

    if (selectedBankSampah.value != null) {
      query =
          query.eq('bank_sampah_id', selectedBankSampah.value!.id);
    }

    final data =
        await query.order('tanggal_pengelolaan', ascending: true);
    return (data as List)
        .map((e) => PengelolaanSampahModel.fromJson(e))
        .toList();
  }

  Future<void> previewLaporan() async {
    if (!isValid) {
      Get.snackbar(
          'Validasi', 'Tentukan periode laporan terlebih dahulu.');
      return;
    }
    isGenerating.value = true;
    try {
      previewData.value = await _fetchDataLaporan();
      hasPreview.value = true;
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat data laporan: $e');
    } finally {
      isGenerating.value = false;
    }
  }

Future<void> exportExcel() async {
  if (!isValid) {
    Get.snackbar('Validasi', 'Tentukan periode laporan terlebih dahulu.');
    return;
  }
  isGenerating.value = true;
  try {
    // Fetch master data kalau belum ada
    if (listAllKategori.isEmpty) await _fetchMasterData();

    List<PengelolaanSampahModel> data = previewData;
    if (data.isEmpty) data = await _fetchDataLaporan();

    final List<BankSampahModel> bankKolom = selectedBankSampah.value != null
        ? [selectedBankSampah.value!]
        : listBankSampah;

    var excelFile = Excel.createExcel();
    final defaultSheet = excelFile.sheets.keys.first;

    final mulai = selectedTanggalMulai.value!;
    final akhir = selectedTanggalAkhir.value!;
    final selisihHari = akhir.difference(mulai).inDays;

    final createdSheets = <String>[];

    if (selisihHari <= 31) {
      final label =
          '${FormatHelper.date(mulai)} - ${FormatHelper.date(akhir)}';
      final sheetName = label.length > 31 ? 'Laporan' : label;
      createdSheets.add(sheetName);
      
      excelFile.rename(defaultSheet, sheetName);
      final sheet = excelFile[sheetName];
      _buildSheet(sheet, label, data, bankKolom);
    } else {
      // Kelompokkan per bulan, urutkan
      final Map<String, List<PengelolaanSampahModel>> perBulan = {};
      for (final item in data) {
        final tgl = item.tanggalPengelolaan;
        final key =
            '${_namaBulan(tgl.month).toUpperCase()} ${tgl.year}';
        perBulan.putIfAbsent(key, () => []);
        perBulan[key]!.add(item);
      }
      
      final entries = perBulan.entries.toList();
      if (entries.isNotEmpty) {
        final firstKey = entries.first.key;
        excelFile.rename(defaultSheet, firstKey);
        
        for (final entry in entries) {
          createdSheets.add(entry.key);
          final sheet = excelFile[entry.key];
          _buildSheet(sheet, entry.key, entry.value, bankKolom);
        }
      }
    }

    // Hapus sheet lain jika ada yang tersisa yang bukan merupakan bagian dari laporan yang dibuat
    final sheetsToDelete = excelFile.sheets.keys.where((k) => !createdSheets.contains(k)).toList();
    for (final key in sheetsToDelete) {
      excelFile.delete(key);
    }

    final bytes = excelFile.encode();
    if (bytes == null) throw Exception('Gagal membuat byte data Excel.');

    final startStr =
        FormatHelper.dateToInput(mulai).replaceAll('-', '');
    final endStr =
        FormatHelper.dateToInput(akhir).replaceAll('-', '');
    final bsuName = selectedBankSampah.value != null
        ? selectedBankSampah.value!.nama
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), '_')
            .replaceAll(RegExp(r'[^a-z0-9_]'), '')
        : 'seluruh_bsu';
    final fileName = 'laporan_sampah_${bsuName}_$startStr-$endStr.xlsx';
    final shareText = selectedBankSampah.value != null
        ? 'Laporan Bank Sampah ${selectedBankSampah.value!.nama} ${FormatHelper.date(mulai)} - ${FormatHelper.date(akhir)}'
        : 'Laporan Seluruh Bank Sampah ${FormatHelper.date(mulai)} - ${FormatHelper.date(akhir)}';

    await FileSaverHelper.saveBytes(bytes, fileName, shareText: shareText);
    Get.snackbar(
        'Sukses', 'Laporan Excel berhasil diexport dan siap dibagikan.');
  } catch (e) {
    Get.snackbar('Gagal', 'Export Excel gagal: $e');
  } finally {
    isGenerating.value = false;
  }
}

void _buildSheet(
  Sheet sheet,
  String labelPeriode,
  List<PengelolaanSampahModel> data,
  List<BankSampahModel> bankKolom,
) {
  // ── Pivot: jenis_sampah_id → bank_sampah_id → jumlah ───────
  final Map<String, Map<String, double>> pivot = {};
  for (final item in data) {
    final jId = item.jenisSampah?.id;
    if (jId == null) continue;
    final bId = item.bankSampah?.id ?? '';
    pivot.putIfAbsent(jId, () => {});
    pivot[jId]![bId] = (pivot[jId]![bId] ?? 0) + item.jumlah;
  }

  // ── Helper style ────────────────────────────────────────────
  CellStyle _styleHeader() => CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#D9D9D9'),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
      );

  CellStyle _styleGroup() => CellStyle(
        bold: true,
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
      );

  CellStyle _styleData() => CellStyle(
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
      );

  CellStyle _styleNumber() => CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
      );

  void _setRowStyle(Sheet s, int rowIdx, int totalCols, CellStyle style) {
    for (int c = 0; c < totalCols; c++) {
      s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx))
          .cellStyle = style;
    }
  }

  final totalCols = bankKolom.length + 3; // NO + JENIS SAMPAH + bank... + TOTAL
  int rowIdx = 0;

  // ── Baris 1: Judul ──────────────────────────────────────────
  final cellJudul = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx));
  cellJudul.value = TextCellValue('LAPORAN SAMPAH KELURAHAN');
  cellJudul.cellStyle = CellStyle(bold: true);
  rowIdx++;

  // ── Baris 2: Periode ────────────────────────────────────────
  final cellPeriode = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx));
  cellPeriode.value = TextCellValue('PERIODE : $labelPeriode');
  rowIdx++;

  rowIdx++; // baris kosong

  // ── Baris Header Kolom ──────────────────────────────────────
  final headerRow = rowIdx;
  sheet
      .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: headerRow))
      .value = TextCellValue('NO');
  sheet
      .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: headerRow))
      .value = TextCellValue('JENIS SAMPAH');
  for (int i = 0; i < bankKolom.length; i++) {
    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: i + 2, rowIndex: headerRow))
        .value = TextCellValue(bankKolom[i].nama);
  }
  sheet
      .cell(CellIndex.indexByColumnRow(
          columnIndex: bankKolom.length + 2, rowIndex: headerRow))
      .value = TextCellValue('TOTAL');
  _setRowStyle(sheet, headerRow, totalCols, _styleHeader());
  rowIdx++;

  // ── Tulis data per hierarki ─────────────────────────────────
  final Map<String, double> totalKategori = {};

  for (final kat in listAllKategori) {
    // Baris Kategori (bold, background)
    final katRow = rowIdx;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: katRow))
        .value = TextCellValue('');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: katRow))
        .value = TextCellValue(kat.nama.toUpperCase());
    for (int c = 2; c < totalCols; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(
              columnIndex: c, rowIndex: katRow))
          .value = TextCellValue('');
    }
    _setRowStyle(sheet, katRow, totalCols, _styleGroup());
    rowIdx++;

    // Sub kategori yang ada di kategori ini
    final subList = listAllSubKategori
        .where((s) => s.kategoriId == kat.id)
        .toList();

    if (subList.isNotEmpty) {
      // Kategori AN ORGANIK: ada sub kategori
      for (final sub in subList) {
        // Baris Sub Kategori
        final subRow = rowIdx;
        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: subRow))
            .value = TextCellValue('');
        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: 1, rowIndex: subRow))
            .value = TextCellValue(sub.nama.toUpperCase());
        for (int c = 2; c < totalCols; c++) {
          sheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: c, rowIndex: subRow))
              .value = TextCellValue('');
        }
        _setRowStyle(sheet, subRow, totalCols, _styleGroup());
        rowIdx++;

        // Tipe yang ada di sub kategori ini
        final tipeList = listAllTipeSampah
            .where((t) => t.subKategoriId == sub.id)
            .toList();

        if (tipeList.isNotEmpty) {
          // Ada tipe (misal Plastik: PET, PP, Hope, ABS)
          for (final tipe in tipeList) {
            // Baris Tipe
            final tipeRow = rowIdx;
            sheet
                .cell(CellIndex.indexByColumnRow(
                    columnIndex: 0, rowIndex: tipeRow))
                .value = TextCellValue('');
            sheet
                .cell(CellIndex.indexByColumnRow(
                    columnIndex: 1, rowIndex: tipeRow))
                .value = TextCellValue(tipe.nama);
            for (int c = 2; c < totalCols; c++) {
              sheet
                  .cell(CellIndex.indexByColumnRow(
                      columnIndex: c, rowIndex: tipeRow))
                  .value = TextCellValue('');
            }
            _setRowStyle(sheet, tipeRow, totalCols, _styleGroup());
            rowIdx++;

            // Jenis di tipe ini
            final jenisList = listAllJenisSampah
                .where((j) =>
                    j.subKategoriId == sub.id && j.tipeId == tipe.id)
                .toList();

            int noUrut = 1;
            for (final jenis in jenisList) {
              final baris = rowIdx;
              sheet
                  .cell(CellIndex.indexByColumnRow(
                      columnIndex: 0, rowIndex: baris))
                  .value = TextCellValue('$noUrut');
              sheet
                  .cell(CellIndex.indexByColumnRow(
                      columnIndex: 1, rowIndex: baris))
                  .value = TextCellValue(jenis.nama);

              double rowTotal = 0;
              for (int i = 0; i < bankKolom.length; i++) {
                final jumlah =
                    pivot[jenis.id]?[bankKolom[i].id] ?? 0.0;
                rowTotal += jumlah;
                final cell = sheet.cell(CellIndex.indexByColumnRow(
                    columnIndex: i + 2, rowIndex: baris));
                cell.value = jumlah > 0
                    ? TextCellValue(FormatHelper.number(jumlah))
                    : TextCellValue('');
                cell.cellStyle = _styleNumber();
              }
              final totalCell = sheet.cell(CellIndex.indexByColumnRow(
                  columnIndex: bankKolom.length + 2, rowIndex: baris));
              totalCell.value = rowTotal > 0
                  ? TextCellValue(FormatHelper.number(rowTotal))
                  : TextCellValue('');
              totalCell.cellStyle = _styleNumber();

              sheet
                  .cell(CellIndex.indexByColumnRow(
                      columnIndex: 0, rowIndex: baris))
                  .cellStyle = _styleNumber();
              sheet
                  .cell(CellIndex.indexByColumnRow(
                      columnIndex: 1, rowIndex: baris))
                  .cellStyle = _styleData();

              totalKategori[kat.id] =
                  (totalKategori[kat.id] ?? 0) + rowTotal;
              noUrut++;
              rowIdx++;
            }
          }
        } else {
          // Tidak ada tipe (misal Kertas, Logam, Kaca)
          final jenisList = listAllJenisSampah
              .where((j) => j.subKategoriId == sub.id)
              .toList();

          int noUrut = 1;
          for (final jenis in jenisList) {
            final baris = rowIdx;
            sheet
                .cell(CellIndex.indexByColumnRow(
                    columnIndex: 0, rowIndex: baris))
                .value = TextCellValue('$noUrut');
            sheet
                .cell(CellIndex.indexByColumnRow(
                    columnIndex: 1, rowIndex: baris))
                .value = TextCellValue(jenis.nama);

            double rowTotal = 0;
            for (int i = 0; i < bankKolom.length; i++) {
              final jumlah =
                  pivot[jenis.id]?[bankKolom[i].id] ?? 0.0;
              rowTotal += jumlah;
              final cell = sheet.cell(CellIndex.indexByColumnRow(
                  columnIndex: i + 2, rowIndex: baris));
              cell.value = jumlah > 0
                  ? TextCellValue(FormatHelper.number(jumlah))
                  : TextCellValue('');
              cell.cellStyle = _styleNumber();
            }
            final totalCell = sheet.cell(CellIndex.indexByColumnRow(
                columnIndex: bankKolom.length + 2, rowIndex: baris));
            totalCell.value = rowTotal > 0
                ? TextCellValue(FormatHelper.number(rowTotal))
                : TextCellValue('');
            totalCell.cellStyle = _styleNumber();

            sheet
                .cell(CellIndex.indexByColumnRow(
                    columnIndex: 0, rowIndex: baris))
                .cellStyle = _styleNumber();
            sheet
                .cell(CellIndex.indexByColumnRow(
                    columnIndex: 1, rowIndex: baris))
                .cellStyle = _styleData();

            totalKategori[kat.id] =
                (totalKategori[kat.id] ?? 0) + rowTotal;
            noUrut++;
            rowIdx++;
          }
        }
      }
    } else {
      // Tidak ada sub kategori (Organik, Minyak Jelantah, dll)
      // Jenis langsung di bawah kategori via kategori_id
      final jenisList = listAllJenisSampah
          .where((j) => j.kategoriId == kat.id)
          .toList();

      int noUrut = 1;
      for (final jenis in jenisList) {
        final baris = rowIdx;
        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: baris))
            .value = TextCellValue('$noUrut');
        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: 1, rowIndex: baris))
            .value = TextCellValue(jenis.nama);

        double rowTotal = 0;
        for (int i = 0; i < bankKolom.length; i++) {
          final jumlah = pivot[jenis.id]?[bankKolom[i].id] ?? 0.0;
          rowTotal += jumlah;
          final cell = sheet.cell(CellIndex.indexByColumnRow(
              columnIndex: i + 2, rowIndex: baris));
          cell.value = jumlah > 0
              ? TextCellValue(FormatHelper.number(jumlah))
              : TextCellValue('');
          cell.cellStyle = _styleNumber();
        }
        final totalCell = sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: bankKolom.length + 2, rowIndex: baris));
        totalCell.value = rowTotal > 0
            ? TextCellValue(FormatHelper.number(rowTotal))
            : TextCellValue('');
        totalCell.cellStyle = _styleNumber();

        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: baris))
            .cellStyle = _styleNumber();
        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: 1, rowIndex: baris))
            .cellStyle = _styleData();

        totalKategori[kat.id] =
            (totalKategori[kat.id] ?? 0) + rowTotal;
        noUrut++;
        rowIdx++;
      }
    }
  }

  // ── Baris kosong ────────────────────────────────────────────
  rowIdx++;

  // ── Baris JUMLAH per kategori ───────────────────────────────
  final judulTotalRow = rowIdx;
  sheet
      .cell(CellIndex.indexByColumnRow(
          columnIndex: 0, rowIndex: judulTotalRow))
      .value = TextCellValue('');
  sheet
      .cell(CellIndex.indexByColumnRow(
          columnIndex: 1, rowIndex: judulTotalRow))
      .value = TextCellValue('JUMLAH');
  _setRowStyle(sheet, judulTotalRow, totalCols, _styleGroup());
  rowIdx++;

  for (final kat in listAllKategori) {
    final totalRow = rowIdx;
    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: 0, rowIndex: totalRow))
        .value = TextCellValue('');
    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: 1, rowIndex: totalRow))
        .value = TextCellValue(kat.nama);
    for (int c = 2; c < totalCols - 1; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(
              columnIndex: c, rowIndex: totalRow))
          .value = TextCellValue('');
    }
    final val = totalKategori[kat.id] ?? 0;
    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: totalCols - 1, rowIndex: totalRow))
        .value = val > 0
        ? TextCellValue(FormatHelper.number(val))
        : TextCellValue('');
    _setRowStyle(sheet, totalRow, totalCols, _styleData());
    rowIdx++;
  }

  // ── Grand Total ─────────────────────────────────────────────
  final grandTotal =
      totalKategori.values.fold(0.0, (sum, v) => sum + v);
  final grandRow = rowIdx;
  sheet
      .cell(CellIndex.indexByColumnRow(
          columnIndex: 0, rowIndex: grandRow))
      .value = TextCellValue('');
  sheet
      .cell(CellIndex.indexByColumnRow(
          columnIndex: 1, rowIndex: grandRow))
      .value = TextCellValue('GRAND TOTAL');
  for (int c = 2; c < totalCols - 1; c++) {
    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: c, rowIndex: grandRow))
        .value = TextCellValue('');
  }
  sheet
      .cell(CellIndex.indexByColumnRow(
          columnIndex: totalCols - 1, rowIndex: grandRow))
      .value = grandTotal > 0
      ? TextCellValue(FormatHelper.number(grandTotal))
      : TextCellValue('');
  _setRowStyle(sheet, grandRow, totalCols, _styleGroup());
}

String _namaBulan(int bulan) {
  const bulanList = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];
  return bulanList[bulan];
}  


  Future<void> exportCsv() async {
  if (!isValid) {
    Get.snackbar('Validasi', 'Tentukan periode laporan terlebih dahulu.');
    return;
  }
  isGenerating.value = true;
  try {
    if (listAllKategori.isEmpty) await _fetchMasterData();

    List<PengelolaanSampahModel> data = previewData;
    if (data.isEmpty) data = await _fetchDataLaporan();

    if (data.isEmpty) {
      Get.snackbar('Info', 'Tidak ada data transaksi untuk diexport.');
      return;
    }

    final mulai = selectedTanggalMulai.value!;
    final akhir = selectedTanggalAkhir.value!;
    final selisihHari = akhir.difference(mulai).inDays;
    final isMultiBulan = selisihHari > 31;

    final List<BankSampahModel> bankKolom = selectedBankSampah.value != null
        ? [selectedBankSampah.value!]
        : listBankSampah;

    // ── Pivot: bulan? → jenis_id → bank_id → jumlah ──────────
    // Untuk single bulan, key bulan = '' (tidak dipakai)
    final Map<String, Map<String, Map<String, double>>> pivot = {};
    for (final item in data) {
      final jId = item.jenisSampah?.id;
      if (jId == null) continue;
      final tgl = item.tanggalPengelolaan;
      final bId = item.bankSampah?.id ?? '';
      final bulanKey = isMultiBulan
          ? '${_namaBulan(tgl.month).toUpperCase()} ${tgl.year}'
          : '';

  // Pakai variabel lokal agar analyzer tahu nilainya non-null
  final pivotBulan = pivot.putIfAbsent(bulanKey, () => {});
  final pivotJenis = pivotBulan.putIfAbsent(jId, () => {});
  pivotJenis[bId] = (pivotJenis[bId] ?? 0) + item.jumlah;
}

// Urutkan bulan
final List<String> bulanKeys = isMultiBulan
    ? pivot.keys.toList()
    : [''];

    final csvData = <List<dynamic>>[];

    // ── Header ────────────────────────────────────────────────
    final header = <dynamic>[];
    if (isMultiBulan) header.add('BULAN');
    header.add('NO');
    header.add('JENIS SAMPAH');
    for (final b in bankKolom) header.add(b.nama);
    header.add('TOTAL');
    csvData.add(header);

    // ── Judul & Periode (baris info di atas header) ───────────
    // Sisipkan di index 0 setelah header dibuat
    final judulRow = <dynamic>[];
    if (isMultiBulan) judulRow.add('');
    judulRow.addAll(['LAPORAN SAMPAH KELURAHAN', ...List.filled(bankKolom.length + 1, '')]);
    
    final periodeRow = <dynamic>[];
    if (isMultiBulan) periodeRow.add('');
    periodeRow.addAll([
      'PERIODE : ${FormatHelper.date(mulai)} - ${FormatHelper.date(akhir)}',
      ...List.filled(bankKolom.length + 1, '')
    ]);

    // Insert di depan
    csvData.insert(0, periodeRow);
    csvData.insert(0, judulRow);
    csvData.insert(1, []); // baris kosong setelah judul

    // ── Data per bulan ────────────────────────────────────────
    for (final bulanKey in bulanKeys) {
      final pivotBulan = pivot[bulanKey] ?? {};
      final Map<String, double> totalKategori = {};

      if (isMultiBulan) {
        // Baris label bulan
        csvData.add([bulanKey, ...List.filled(bankKolom.length + 2, '')]);
      }

      for (final kat in listAllKategori) {
        // Baris kategori
        final katRow = <dynamic>[];
        if (isMultiBulan) katRow.add('');
        katRow.addAll(['', kat.nama.toUpperCase(), ...List.filled(bankKolom.length + 1, '')]);
        csvData.add(katRow);

        final subList = listAllSubKategori.where((s) => s.kategoriId == kat.id).toList();

        if (subList.isNotEmpty) {
          for (final sub in subList) {
            // Baris sub kategori
            final subRow = <dynamic>[];
            if (isMultiBulan) subRow.add('');
            subRow.addAll(['', '  ${sub.nama.toUpperCase()}', ...List.filled(bankKolom.length + 1, '')]);
            csvData.add(subRow);

            final tipeList = listAllTipeSampah.where((t) => t.subKategoriId == sub.id).toList();

            if (tipeList.isNotEmpty) {
              for (final tipe in tipeList) {
                // Baris tipe
                final tipeRow = <dynamic>[];
                if (isMultiBulan) tipeRow.add('');
                tipeRow.addAll(['', '    ${tipe.nama}', ...List.filled(bankKolom.length + 1, '')]);
                csvData.add(tipeRow);

                final jenisList = listAllJenisSampah
                    .where((j) => j.subKategoriId == sub.id && j.tipeId == tipe.id)
                    .toList();

                int no = 1;
                for (final jenis in jenisList) {
                  double rowTotal = 0;
                  final row = <dynamic>[];
                  if (isMultiBulan) row.add('');
                  row.add('$no');
                  row.add('      ${jenis.nama}');
                  for (final b in bankKolom) {
                    final jumlah = pivotBulan[jenis.id]?[b.id] ?? 0.0;
                    rowTotal += jumlah;
                    row.add(jumlah > 0 ? FormatHelper.number(jumlah) : '');
                  }
                  row.add(rowTotal > 0 ? FormatHelper.number(rowTotal) : '');
                  csvData.add(row);
                  totalKategori[kat.id] = (totalKategori[kat.id] ?? 0) + rowTotal;
                  no++;
                }
              }
            } else {
              final jenisList = listAllJenisSampah
                  .where((j) => j.subKategoriId == sub.id)
                  .toList();

              int no = 1;
              for (final jenis in jenisList) {
                double rowTotal = 0;
                final row = <dynamic>[];
                if (isMultiBulan) row.add('');
                row.add('$no');
                row.add('    ${jenis.nama}');
                for (final b in bankKolom) {
                  final jumlah = pivotBulan[jenis.id]?[b.id] ?? 0.0;
                  rowTotal += jumlah;
                  row.add(jumlah > 0 ? FormatHelper.number(jumlah) : '');
                }
                row.add(rowTotal > 0 ? FormatHelper.number(rowTotal) : '');
                csvData.add(row);
                totalKategori[kat.id] = (totalKategori[kat.id] ?? 0) + rowTotal;
                no++;
              }
            }
          }
        } else {
          // Jenis langsung di bawah kategori
          final jenisList = listAllJenisSampah
              .where((j) => j.kategoriId == kat.id)
              .toList();

          int no = 1;
          for (final jenis in jenisList) {
            double rowTotal = 0;
            final row = <dynamic>[];
            if (isMultiBulan) row.add('');
            row.add('$no');
            row.add('  ${jenis.nama}');
            for (final b in bankKolom) {
              final jumlah = pivotBulan[jenis.id]?[b.id] ?? 0.0;
              rowTotal += jumlah;
              row.add(jumlah > 0 ? FormatHelper.number(jumlah) : '');
            }
            row.add(rowTotal > 0 ? FormatHelper.number(rowTotal) : '');
            csvData.add(row);
            totalKategori[kat.id] = (totalKategori[kat.id] ?? 0) + rowTotal;
            no++;
          }
        }
      }

      // ── Baris kosong antar bulan ────────────────────────────
      csvData.add([]);

      // ── Jumlah per kategori ─────────────────────────────────
      final jumlahLabelRow = <dynamic>[];
      if (isMultiBulan) jumlahLabelRow.add('');
      jumlahLabelRow.addAll(['', 'JUMLAH', ...List.filled(bankKolom.length + 1, '')]);
      csvData.add(jumlahLabelRow);

      for (final kat in listAllKategori) {
        final val = totalKategori[kat.id] ?? 0;
        final totRow = <dynamic>[];
        if (isMultiBulan) totRow.add('');
        totRow.add('');
        totRow.add(kat.nama);
        totRow.addAll(List.filled(bankKolom.length, ''));
        totRow.add(val > 0 ? FormatHelper.number(val) : '');
        csvData.add(totRow);
      }

      // Grand total per bulan
      final grandTotal = totalKategori.values.fold(0.0, (s, v) => s + v);
      final grandRow = <dynamic>[];
      if (isMultiBulan) grandRow.add('');
      grandRow.add('');
      grandRow.add('GRAND TOTAL');
      grandRow.addAll(List.filled(bankKolom.length, ''));
      grandRow.add(grandTotal > 0 ? FormatHelper.number(grandTotal) : '');
      csvData.add(grandRow);

      // Baris kosong pemisah antar bulan
      if (isMultiBulan) csvData.add([]);
    }

    final csvString = const ListToCsvConverter().convert(csvData);
    final csvWithBom = '\uFEFF$csvString';

    final startStr = FormatHelper.dateToInput(mulai).replaceAll('-', '');
    final endStr = FormatHelper.dateToInput(akhir).replaceAll('-', '');
    final bsuName = selectedBankSampah.value != null
        ? selectedBankSampah.value!.nama
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), '_')
            .replaceAll(RegExp(r'[^a-z0-9_]'), '')
        : 'seluruh_bsu';
    final fileName = 'laporan_sampah_${bsuName}_$startStr-$endStr.csv';
    final shareText = selectedBankSampah.value != null
        ? 'Laporan Bank Sampah ${selectedBankSampah.value!.nama} ${FormatHelper.date(mulai)} - ${FormatHelper.date(akhir)}'
        : 'Laporan Seluruh Bank Sampah ${FormatHelper.date(mulai)} - ${FormatHelper.date(akhir)}';

    await FileSaverHelper.saveString(csvWithBom, fileName, shareText: shareText);
    Get.snackbar('Sukses', 'Laporan CSV berhasil diexport dan siap dibagikan.');
  } catch (e) {
    Get.snackbar('Gagal', 'Export CSV gagal: $e');
  } finally {
    isGenerating.value = false;
  }
}
}
