import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/local_data_service.dart';
import '../../core/constants/data_tables.dart';
import '../../models/bank_sampah_model.dart';
import '../../models/pengelolaan_sampah_model.dart';

class MonitoringController extends GetxController {
  final searchController = TextEditingController();
  final searchQuery = ''.obs;
  final filterAktifSaja = false.obs;

  final listBankSampah = <BankSampahModel>[].obs;
  final isLoading = false.obs;

  // Statistik global bulan ini
  final totalSampahGlobal = 0.0.obs;
  final totalNilaiGlobal = 0.0.obs;

  // Statistik per bank sampah — key: bank_sampah id
  // value: {'total_jumlah': num, 'total_transaksi': num, 'total_nilai': num}
  final statistikPerBank = <String, Map<String, num>>{}.obs;

  // Detail bank sampah yang dipilih
  final selectedBankSampah = Rx<BankSampahModel?>(null);
  final detailTransaksi = <PengelolaanSampahModel>[].obs;
  final isLoadingDetail = false.obs;

  // Statistik untuk detail view
  final statJumlah = 0.0.obs;
  final statTransaksi = 0.obs;
  final statNilai = 0.0.obs;
  final statJumlahPadat = 0.0.obs;
  final statJumlahCair = 0.0.obs;
  final statJumlahSatuan = 0.0.obs;

  // Getter list yang sudah difilter
  List<BankSampahModel> get listBankFiltered {
    var list = listBankSampah.toList();
    if (filterAktifSaja.value) {
      list = list.where((b) => b.isActive).toList();
    }
    if (searchQuery.value.isNotEmpty) {
      final q = searchQuery.value.toLowerCase();
      list = list.where((b) {
        return b.nama.toLowerCase().contains(q) ||
            (b.alamat?.toLowerCase().contains(q) ?? false) ||
            (b.rt?.contains(q) ?? false) ||
            (b.rw?.contains(q) ?? false);
      }).toList();
    }
    return list;
  }

  @override
  void onInit() {
    super.onInit();
    // Cek apakah ada argument (dari dashboard -> detail langsung)
    if (Get.arguments != null && Get.arguments is BankSampahModel) {
      selectedBankSampah.value = Get.arguments as BankSampahModel;
      fetchDetailBankSampah(selectedBankSampah.value!.id);
    } else {
      fetchMonitoring();
    }
  }

  void onSearch(String value) {
    searchQuery.value = value;
  }

  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
  }

  void selectBank(BankSampahModel bank) {
    selectedBankSampah.value = bank;
    fetchDetailBankSampah(bank.id);
  }

  Future<void> fetchMonitoring() async {
    isLoading.value = true;
    try {
      await Future.wait([
        fetchSemuaBankSampah(),
        _fetchStatistikGlobal(),
      ]);
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat data monitoring.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchSemuaBankSampah() async {
    final data = await LocalDataService.client
        .from(DataTables.tableBankSampah)
        .select()
        .order('nama');
    listBankSampah.value =
        (data as List).map((e) => BankSampahModel.fromJson(e)).toList();
  }

  Future<void> _fetchStatistikGlobal() async {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    final data = await LocalDataService.client
        .from(DataTables.tablePengelolaanSampah)
        .select('bank_sampah_id, jumlah, total_harga')
        .gte('tanggal_pengelolaan',
            firstDay.toIso8601String().split('T').first)
        .lte('tanggal_pengelolaan',
            lastDay.toIso8601String().split('T').first);

    final list = data as List;

    // Reset
    double totalJumlah = 0;
    double totalNilai = 0;
    final Map<String, Map<String, num>> statMap = {};

    for (final row in list) {
      final bankId = row['bank_sampah_id'] as String;
      final jumlah = (row['jumlah'] as num).toDouble();
      final nilai = ((row['total_harga'] as num?)?.toDouble() ?? 0.0);

      totalJumlah += jumlah;
      totalNilai += nilai;

      if (!statMap.containsKey(bankId)) {
        statMap[bankId] = {
          'total_jumlah': 0.0,
          'total_transaksi': 0,
          'total_nilai': 0.0,
        };
      }
      statMap[bankId]!['total_jumlah'] =
          (statMap[bankId]!['total_jumlah'] ?? 0) + jumlah;
      statMap[bankId]!['total_transaksi'] =
          (statMap[bankId]!['total_transaksi'] ?? 0) + 1;
      statMap[bankId]!['total_nilai'] =
          (statMap[bankId]!['total_nilai'] ?? 0) + nilai;
    }

    totalSampahGlobal.value = totalJumlah;
    totalNilaiGlobal.value = totalNilai;
    statistikPerBank.value = statMap;
  }

  Future<void> fetchDetailBankSampah(String bankSampahId) async {
    isLoadingDetail.value = true;
    try {
      final now = DateTime.now();
      final firstDay = DateTime(now.year, now.month, 1);
      final lastDay = DateTime(now.year, now.month + 1, 0);

      final data = await LocalDataService.client
          .from(DataTables.tablePengelolaanSampah)
          .select('''
            *,
            kategori_sampah(*),
            sub_kategori_sampah(*),
            tipe_sampah(*),
            jenis_sampah(*, tipe_sampah(*)),
            satuan(*),
            profiles(*)
          ''')
          .eq('bank_sampah_id', bankSampahId)
          .gte('tanggal_pengelolaan',
              firstDay.toIso8601String().split('T').first)
          .lte('tanggal_pengelolaan',
              lastDay.toIso8601String().split('T').first)
          .order('tanggal_pengelolaan', ascending: false);

      final list = (data as List)
          .map((e) => PengelolaanSampahModel.fromJson(e))
          .toList();

      detailTransaksi.value = list;
      statTransaksi.value = list.length;
      statJumlah.value = list.fold(0.0, (sum, e) => sum + e.jumlah);
      statNilai.value =
          list.fold(0.0, (sum, e) => sum + (e.totalHarga ?? 0.0));

      double padat = 0.0;
      double cair = 0.0;
      double sat = 0.0;

      for (final item in list) {
        final singkatan = item.satuan?.singkatan.toLowerCase() ?? '';
        if (singkatan == 'kg') {
          padat += item.jumlah;
        } else if (singkatan == 'liter' || singkatan == 'ltr' || singkatan == 'l') {
          cair += item.jumlah;
        } else {
          sat += item.jumlah;
        }
      }

      statJumlahPadat.value = padat;
      statJumlahCair.value = cair;
      statJumlahSatuan.value = sat;
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat detail bank sampah.');
    } finally {
      isLoadingDetail.value = false;
    }
  }

  Future<void> refresh() async {
    if (selectedBankSampah.value != null) {
      await fetchDetailBankSampah(selectedBankSampah.value!.id);
    } else {
      await fetchMonitoring();
    }
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}
