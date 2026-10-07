import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../core/services/local_data_service.dart';
import '../../core/constants/data_tables.dart';

/// Model ringkasan satu bulan untuk rekap partisipasi wilayah.
class RekapBulananItem {
  final int year;
  final int month;
  final double totalKg;
  final int totalTransaksi;
  final int bankAktif; // BSU yang punya transaksi pada bulan itu
  final int nasabahAktif; // nama nasabah unik pada bulan itu

  const RekapBulananItem({
    required this.year,
    required this.month,
    required this.totalKg,
    required this.totalTransaksi,
    required this.bankAktif,
    required this.nasabahAktif,
  });

  double partisipasi(int totalBsuAktif) =>
      totalBsuAktif == 0 ? 0 : (bankAktif / totalBsuAktif).clamp(0.0, 1.0);

  String get namaBulan {
    const nama = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return nama[month - 1];
  }

  String get labelLengkap => '$namaBulan $year';
}

class RekapBulananController extends GetxController {
  final isLoading = false.obs;
  final hasError = false.obs;
  final errorMsg = ''.obs;

  /// Jumlah bulan ke belakang yang direkap (termasuk bulan berjalan).
  static const int jumlahBulan = 6;

  final items = <RekapBulananItem>[].obs;
  final totalBsuAktif = 0.obs;

  final selectedBsuId = RxnString(); // null = semua BSU
  final listBsu = <Map<String, dynamic>>[].obs; // {id, nama}

  String get judulPeriode {
    if (items.isEmpty) return '-';
    final first = items.first;
    final last = items.last;
    return '${first.namaBulan} – ${last.labelLengkap}';
  }

  double get rataPartisipasi {
    if (items.isEmpty || totalBsuAktif.value == 0) return 0;
    final sum =
        items.fold(0.0, (s, e) => s + e.partisipasi(totalBsuAktif.value));
    return sum / items.length;
  }

  double get totalTon =>
      items.fold(0.0, (s, e) => s + e.totalKg) / 1000.0;

  int get totalTransaksi =>
      items.fold(0, (s, e) => s + e.totalTransaksi);

  @override
  void onInit() {
    super.onInit();
    fetchRekap();
  }

  Future<void> fetchRekap() async {
    isLoading.value = true;
    hasError.value = false;
    errorMsg.value = '';
    try {
      await Future.wait([
        _fetchDaftarBsu(),
        _fetchSingkatanSatuanBerat(),
      ]);
      await _fetchRekapData();
    } catch (e) {
      debugPrint('RekapBulanan Error: $e');
      hasError.value = true;
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// Set satuan_id yang satuannya berat (kg).
  /// Ini menggantikan embed `satuan(singkatan)` per-transaksi yang rawan
  /// gagal (400) dan mengosongkan seluruh rekap.
  Set<String> satuanBeratIds = {};

  Future<void> _fetchSingkatanSatuanBerat() async {
    try {
      final data = await LocalDataService.client
          .from(DataTables.tableSatuan)
          .select('id, singkatan');
      satuanBeratIds = (data as List)
          .where((e) =>
              ((e['singkatan'] as String?) ?? '').toLowerCase() == 'kg')
          .map((e) => (e['id'] as String).toLowerCase())
          .toSet();
    } catch (e) {
      debugPrint('RekapBulanan satuan warning: $e');
      satuanBeratIds = {};
    }
  }

  Future<void> _fetchDaftarBsu() async {
    final data = await LocalDataService.client
        .from(DataTables.tableBankSampah)
        .select('id, nama')
        .eq('is_active', true)
        .order('nama');

    final list = (data as List)
        .map((e) => {'id': e['id'] as String, 'nama': e['nama'] as String? ?? '-'})
        .toList();

    listBsu.value = list;
    totalBsuAktif.value = list.length;
  }

  Future<void> _fetchRekapData() async {
    final now = DateTime.now();
    final start =
        DateTime(now.year, now.month - (jumlahBulan - 1), 1);
    final end = DateTime(now.year, now.month + 1, 0);

    var query = LocalDataService.client
        .from(DataTables.tablePengelolaanSampah)
        .select(
            'bank_sampah_id, jumlah, nama_nasabah, tanggal_pengelolaan, satuan_id')
        .gte('tanggal_pengelolaan', start.toIso8601String().split('T').first)
        .lte('tanggal_pengelolaan', end.toIso8601String().split('T').first);

    if (selectedBsuId.value != null && selectedBsuId.value!.isNotEmpty) {
      query = query.eq('bank_sampah_id', selectedBsuId.value!);
    }

    final data = await query;
    final list = data as List;

    // Siapkan bucket per bulan.
    final buckets = <String, Map<String, dynamic>>{};
    for (var i = 0; i < jumlahBulan; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final key = '${d.year}-${d.month}';
      buckets[key] = {
        'year': d.year,
        'month': d.month,
        'kg': 0.0,
        'transaksi': 0,
        'bank': <String>{},
        'nasabah': <String>{},
      };
    }

    for (final row in list) {
      final tgl = DateTime.tryParse(row['tanggal_pengelolaan'].toString());
      if (tgl == null) continue;
      final key = '${tgl.year}-${tgl.month}';
      final bucket = buckets[key];
      if (bucket == null) continue;

      final isKg = satuanBeratIds
          .contains((row['satuan_id']?.toString() ?? '').toLowerCase());
      // Hanya timbangan berat (kg) yang masuk tonase; transaksi tetap dihitung semua.
      if (isKg) {
        final jml = row['jumlah'];
        bucket['kg'] = (bucket['kg'] as double) +
            (jml is num ? jml.toDouble() : double.tryParse('$jml') ?? 0.0);
      }
      bucket['transaksi'] = (bucket['transaksi'] as int) + 1;

      final bankId = row['bank_sampah_id'] as String?;
      if (bankId != null) (bucket['bank'] as Set<String>).add(bankId);

      final nasabah = row['nama_nasabah'] as String?;
      if (nasabah != null && nasabah.trim().isNotEmpty) {
        (bucket['nasabah'] as Set<String>).add(nasabah.trim());
      }
    }

    // Urutkan dari bulan terlama → terbaru (untuk chart kiri→kanan).
    final result = buckets.entries
        .map((e) => RekapBulananItem(
              year: e.value['year'] as int,
              month: e.value['month'] as int,
              totalKg: e.value['kg'] as double,
              totalTransaksi: e.value['transaksi'] as int,
              bankAktif: (e.value['bank'] as Set<String>).length,
              nasabahAktif: (e.value['nasabah'] as Set<String>).length,
            ))
        .toList()
      ..sort((a, b) {
        final ka = a.year * 12 + a.month;
        final kb = b.year * 12 + b.month;
        return ka.compareTo(kb);
      });

    items.value = result;
  }

  void setBsuFilter(String? bankId) {
    selectedBsuId.value = bankId;
    fetchRekap();
  }
}
