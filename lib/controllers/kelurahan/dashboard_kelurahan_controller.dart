import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../core/services/local_data_service.dart';
import '../../core/constants/data_tables.dart';
import '../../core/services/session_service.dart';
import '../../models/bank_sampah_model.dart';
import '../../app/routes/app_routes.dart';
import 'monitoring_controller.dart';

class DashboardKelurahanController extends GetxController {
  final isLoading = false.obs;

  // ── State Filter ────────────────────────────────────────────────────────────
  final selectedBankSampahId = RxnString(); // null = Semua Bank Sampah
  final selectedStartDate = Rx<DateTime>(
      DateTime(DateTime.now().year, DateTime.now().month, 1));
  final selectedEndDate = Rx<DateTime>(
      DateTime(DateTime.now().year, DateTime.now().month + 1, 0));
  final isCustomFilter = false.obs;

  // Statistik global
  final totalBankSampah = 0.obs;
  final totalBankSampahAktif = 0.obs;
  final totalJumlahBulanIni = 0.0.obs;
  final totalTransaksiBulanIni = 0.obs;
  final totalNilaiBulanIni = 0.0.obs;
  final totalJumlahBulanLalu = 0.0.obs;

  // Statistik per tipe & breakdown sampah
  final totalTimbulanTon = 0.0.obs;
  final totalSampahPadat = 0.0.obs;
  final totalSampahPadatAnorganik = 0.0.obs;
  final totalSampahPadatOrganik = 0.0.obs;
  final totalSampahCair = 0.0.obs;
  final totalSampahSatuan = 0.0.obs;

  // Bank sampah teraktif (top 3)
  final topBankSampah = <Map<String, dynamic>>[].obs;

  // Bank sampah aktif — untuk pilihan filter & section aktivitas
  final bankSampahAktif = <BankSampahModel>[].obs;

  // Aktivitas terbaru
  final aktivitasTerbaru = <Map<String, dynamic>>[].obs;

  String get penggunaNama =>
      SessionService.to.profile.value?.namaLengkap ?? '-';

  String get namaKelurahan => 'Kelurahan';

  static const _namaBulan = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  String get filterPeriodLabel {
    final start = selectedStartDate.value;
    final end = selectedEndDate.value;
    if (!isCustomFilter.value && start.month == end.month && start.year == end.year) {
      return '${_namaBulan[start.month - 1]} ${start.year}';
    }
    String fmtDate(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')} ${_namaBulan[d.month - 1].substring(0, 3)} ${d.year}';
    return '${fmtDate(start)} - ${fmtDate(end)}';
  }

  String get filterBankLabel {
    if (selectedBankSampahId.value == null || selectedBankSampahId.value!.isEmpty) {
      final total = bankSampahAktif.length;
      return total > 0 ? 'Semua Bank ($total)' : 'Semua Bank Sampah';
    }
    final found = bankSampahAktif.firstWhereOrNull((b) => b.id == selectedBankSampahId.value);
    return found?.nama ?? 'Bank Sampah';
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  @override
  void onInit() {
    super.onInit();
    fetchDashboardData();
  }

  Future<void> fetchDashboardData() async {
    isLoading.value = true;
    try {
      await Future.wait([
        _safeRun(_fetchStatistikBankSampah, 'StatistikBankSampah'),
        _safeRun(_fetchStatistikPeriode, 'StatistikPeriode'),
        _safeRun(_fetchStatistikBulanLalu, 'StatistikBulanLalu'),
        _safeRun(_fetchTopBankSampahBulanIni, 'TopBankSampah'),
        _safeRun(_fetchAktivitasTerbaru, 'AktivitasTerbaru'),
      ]);
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat data dashboard.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _safeRun(Future<void> Function() action, String name) async {
    try {
      await action();
    } catch (e) {
      debugPrint('DashboardKelurahan Warning ($name): $e');
    }
  }

  Future<void> _fetchStatistikBankSampah() async {
    final data = await LocalDataService.client
        .from(DataTables.tableBankSampah)
        .select();

    final list =
        (data as List).map((e) => BankSampahModel.fromJson(e)).toList();
    totalBankSampah.value = list.length;
    totalBankSampahAktif.value = list.where((b) => b.isActive).length;
    bankSampahAktif.value = list.where((b) => b.isActive).toList();
  }

  Future<void> _fetchStatistikPeriode() async {
    final startStr = selectedStartDate.value.toIso8601String().split('T').first;
    final endStr = selectedEndDate.value.toIso8601String().split('T').first;

    var query = LocalDataService.client
        .from(DataTables.tablePengelolaanSampah)
        .select('''
          jumlah,
          total_harga,
          satuan(singkatan),
          kategori_sampah(nama)
        ''')
        .gte('tanggal_pengelolaan', startStr)
        .lte('tanggal_pengelolaan', endStr);

    if (selectedBankSampahId.value != null && selectedBankSampahId.value!.isNotEmpty) {
      query = query.eq('bank_sampah_id', selectedBankSampahId.value!);
    }

    final data = await query;
    final list = data as List;
    totalTransaksiBulanIni.value = list.length;
    totalJumlahBulanIni.value = list.fold(
      0.0,
      (sum, e) => sum + _toDouble(e['jumlah']),
    );
    totalNilaiBulanIni.value = list.fold(
      0.0,
      (sum, e) => sum + _toDouble(e['total_harga']),
    );

    double padat = 0.0;
    double padatAnorganik = 0.0;
    double padatOrganik = 0.0;
    double cair = 0.0;
    double sat = 0.0;

    for (final item in list) {
      final jml = _toDouble(item['jumlah']);
      final singkatan = ((item['satuan'] as Map?)?['singkatan'] as String?)?.toLowerCase() ?? '';
      final katNama = ((item['kategori_sampah'] as Map?)?['nama'] as String?)?.toLowerCase() ?? '';

      if (singkatan == 'kg') {
        padat += jml;
        if (katNama.contains('anorganik') || katNama.contains('an organik')) {
          padatAnorganik += jml;
        } else if (katNama.contains('organik')) {
          padatOrganik += jml;
        } else {
          padatAnorganik += jml;
        }
      } else if (singkatan == 'liter' || singkatan == 'ltr' || singkatan == 'l') {
        cair += jml;
      } else {
        sat += jml;
      }
    }

    totalSampahPadat.value = padat;
    totalSampahPadatAnorganik.value = padatAnorganik;
    totalSampahPadatOrganik.value = padatOrganik;
    totalSampahCair.value = cair;
    totalSampahSatuan.value = sat;

    // Total timbulan terkelola (dalam Ton = padat / 1000.0)
    totalTimbulanTon.value = padat / 1000.0;
  }

  Future<void> _fetchAktivitasTerbaru() async {
    final startStr = selectedStartDate.value.toIso8601String().split('T').first;
    final endStr = selectedEndDate.value.toIso8601String().split('T').first;

    var query = LocalDataService.client
        .from(DataTables.tablePengelolaanSampah)
        .select('''
          jumlah,
          total_harga,
          tanggal_pengelolaan,
          bank_sampah(nama),
          kategori_sampah(nama),
          sub_kategori_sampah(nama),
          tipe_sampah(nama),
          jenis_sampah(nama),
          satuan(singkatan)
        ''')
        .gte('tanggal_pengelolaan', startStr)
        .lte('tanggal_pengelolaan', endStr);

    if (selectedBankSampahId.value != null && selectedBankSampahId.value!.isNotEmpty) {
      query = query.eq('bank_sampah_id', selectedBankSampahId.value!);
    }

    final data = await query
        .order('tanggal_pengelolaan', ascending: false)
        .limit(10);

    aktivitasTerbaru.value = (data as List).map((e) {
      final jenis = (e['jenis_sampah'] as Map?)?['nama'] as String?;
      final tipe = (e['tipe_sampah'] as Map?)?['nama'] as String?;
      final sub = (e['sub_kategori_sampah'] as Map?)?['nama'] as String?;
      final kat = (e['kategori_sampah'] as Map?)?['nama'] as String?;
      final itemNama = jenis ?? tipe ?? sub ?? kat ?? '-';

      return {
        'bank_nama': (e['bank_sampah'] as Map?)?['nama'] ?? '-',
        'jenis_nama': itemNama,
        'jumlah': _toDouble(e['jumlah']),
        'total_harga': _toDouble(e['total_harga']),
        'satuan_singkatan': (e['satuan'] as Map?)?['singkatan'] ?? '',
        'tanggal': e['tanggal_pengelolaan'],
      };
    }).toList();
  }

  Future<void> _fetchStatistikBulanLalu() async {
    final now = DateTime.now();
    final firstDayLastMonth = DateTime(now.year, now.month - 1, 1);
    final lastDayLastMonth = DateTime(now.year, now.month, 0);

    final data = await LocalDataService.client
        .from(DataTables.tablePengelolaanSampah)
        .select('jumlah')
        .gte('tanggal_pengelolaan',
            firstDayLastMonth.toIso8601String().split('T').first)
        .lte('tanggal_pengelolaan',
            lastDayLastMonth.toIso8601String().split('T').first);

    final list = data as List;
    totalJumlahBulanLalu.value = list.fold(
      0.0,
      (sum, e) => sum + _toDouble(e['jumlah']),
    );
  }

  Future<void> _fetchTopBankSampahBulanIni() async {
    final startStr = selectedStartDate.value.toIso8601String().split('T').first;
    final endStr = selectedEndDate.value.toIso8601String().split('T').first;

    final data = await LocalDataService.client
        .from(DataTables.tablePengelolaanSampah)
        .select('jumlah, bank_sampah(nama)')
        .gte('tanggal_pengelolaan', startStr)
        .lte('tanggal_pengelolaan', endStr);

    final list = data as List;
    final aggregates = <String, double>{};

    for (final e in list) {
      final bankMap = e['bank_sampah'] as Map?;
      final bankNama = bankMap?['nama'] as String? ?? 'Tidak Diketahui';
      final jumlah = _toDouble(e['jumlah']);
      aggregates[bankNama] = (aggregates[bankNama] ?? 0.0) + jumlah;
    }

    final sortedList = aggregates.entries
        .map((entry) => {'nama': entry.key, 'total': entry.value})
        .toList();
    sortedList.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));

    topBankSampah.value = sortedList.take(3).toList();
  }

  // ── Aksi Filter ─────────────────────────────────────────────────────────────
  void setBankSampahFilter(String? bankId) {
    selectedBankSampahId.value = bankId;
    fetchDashboardData();
  }

  void setDateRangeFilter(DateTime start, DateTime end) {
    selectedStartDate.value = DateTime(start.year, start.month, start.day);
    selectedEndDate.value = DateTime(end.year, end.month, end.day, 23, 59, 59);
    isCustomFilter.value = true;
    fetchDashboardData();
  }

  void setMonthFilter(int year, int month) {
    selectedStartDate.value = DateTime(year, month, 1);
    selectedEndDate.value = DateTime(year, month + 1, 0, 23, 59, 59);
    isCustomFilter.value = false;
    fetchDashboardData();
  }

  void resetFilters() {
    final now = DateTime.now();
    selectedBankSampahId.value = null;
    selectedStartDate.value = DateTime(now.year, now.month, 1);
    selectedEndDate.value = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    isCustomFilter.value = false;
    fetchDashboardData();
  }

  // Navigasi
  void goToMonitoring() => Get.toNamed(AppRoutes.monitoringBankSampah);
  void goToManajemenBankSampah() =>
      Get.toNamed(AppRoutes.manajemenBankSampah);
  void goToMasterSampah() => Get.toNamed(AppRoutes.masterSampah);
  void goToManajemenPengelola() =>
      Get.toNamed(AppRoutes.manajemenPengelola);
  void goToLaporan() => Get.toNamed(AppRoutes.generatorLaporan);
  void goToProfil() => Get.toNamed(AppRoutes.profilKelurahan);
  void goToDetailBankSampah(BankSampahModel b) {
    if (Get.isRegistered<MonitoringController>()) {
      Get.find<MonitoringController>().selectBank(b);
    }
    Get.toNamed(AppRoutes.detailBankSampah, arguments: b);
  }

  @override
  Future<void> refresh() => fetchDashboardData();
}
