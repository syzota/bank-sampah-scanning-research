import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/local_data_service.dart';
import '../../core/constants/data_tables.dart';
import '../../models/bank_sampah_model.dart';
import '../../models/profile_model.dart';
import '../../app/routes/app_routes.dart';

class BankSampahController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final namaController = TextEditingController();
  final alamatController = TextEditingController();
  final rtController = TextEditingController();
  final rwController = TextEditingController();
  final searchController = TextEditingController();

  final listBankSampah = <BankSampahModel>[].obs;
  final listPengelolaTerhubung = <ProfileModel>[].obs;
  final searchQuery = ''.obs;

  // Filter chip: 0 = Semua, 1 = Aktif, 2 = Nonaktif / Perlu Pendampingan
  final selectedFilter = 0.obs;

  final isLoading = false.obs;
  final isSaving = false.obs;
  final isAktif = true.obs;

  // Cakupan RT terpilih (multi-select)
  final selectedRts = <String>[].obs;

  final editData = Rx<BankSampahModel?>(null);
  bool get isEditMode => editData.value != null;

  // ── Statistik nyata per bank sampah (dari pengelolaan_sampah) ──
  // key: bank_sampah id
  final statKgTerekelola = <String, double>{}.obs; // total kg (semua waktu)
  final statJumlahNasabah = <String, int>{}.obs; // nasabah unik

  // Getter list yang sudah difilter berdasarkan search
  int get totalAktif => listBankSampah.where((b) => b.isActive).length;
  int get totalNonaktif => listBankSampah.length - totalAktif;

  /// Jumlah RW unik yang terdata (untuk chip wilayah di header).
  int get jumlahRw => listBankSampah
      .map((b) => b.rw?.trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toSet()
      .length;

  List<BankSampahModel> get listBankFiltered {
    var list = switch (selectedFilter.value) {
      1 => listBankSampah.where((b) => b.isActive),
      2 => listBankSampah.where((b) => !b.isActive),
      _ => listBankSampah,
    }.toList();
    if (searchQuery.value.isEmpty) return list;
    final q = searchQuery.value.toLowerCase();
    return list.where((b) {
      return b.nama.toLowerCase().contains(q) ||
          (b.alamat?.toLowerCase().contains(q) ?? false) ||
          (b.rt?.contains(q) ?? false) ||
          (b.rw?.contains(q) ?? false);
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    fetchBankSampah();
  }

  /// Tonase terekelola (ton, dibulatkan 1 desimal) untuk kartu BSU.
  String tonTerekelola(String bankId) {
    final kg = statKgTerekelola[bankId] ?? 0.0;
    final ton = kg / 1000.0;
    return ton >= 1000
        ? ton.toStringAsFixed(0)
        : ton.toStringAsFixed(1);
  }

  void onSearch(String value) {
    searchQuery.value = value;
  }

  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
  }

  Future<void> fetchBankSampah() async {
    isLoading.value = true;
    try {
      final data = await LocalDataService.client
          .from(DataTables.tableBankSampah)
          .select()
          .order('nama');
      listBankSampah.value = (data as List)
          .map((e) => BankSampahModel.fromJson(e))
          .toList();
      await _fetchStatistikPerBank();
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat daftar bank sampah.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _fetchStatistikPerBank() async {
    try {
      final data = await LocalDataService.client
          .from(DataTables.tablePengelolaanSampah)
          .select('bank_sampah_id, jumlah, nama_nasabah, satuan(singkatan)');

      final kgMap = <String, double>{};
      final nasabahMap = <String, Set<String>>{};

      for (final row in (data as List)) {
        final bankId = row['bank_sampah_id'] as String?;
        if (bankId == null) continue;

        final singkatan =
            ((row['satuan'] as Map?)?['singkatan'] as String?)?.toLowerCase() ?? '';
        if (singkatan == 'kg') {
          final jml = row['jumlah'];
          final v = jml is num
              ? jml.toDouble()
              : double.tryParse('$jml') ?? 0.0;
          kgMap[bankId] = (kgMap[bankId] ?? 0.0) + v;
        }

        final nasabah = row['nama_nasabah'] as String?;
        if (nasabah != null && nasabah.trim().isNotEmpty) {
          nasabahMap.putIfAbsent(bankId, () => {}).add(nasabah.trim());
        }
      }

      statKgTerekelola.value = kgMap;
      statJumlahNasabah.value =
          nasabahMap.map((key, value) => MapEntry(key, value.length));
    } catch (e) {
      // Statistik opsional — biarkan kosong, jangan ganggu list utama.
      debugPrint('BankSampah stat warning: $e');
    }
  }

  Future<void> _fetchPengelolaTerhubung(String bankSampahId) async {
    try {
      final data = await LocalDataService.client
          .from(DataTables.tablePengelolaBankSampah)
          .select('profile_id, profiles(*)')
          .eq('bank_sampah_id', bankSampahId);

      listPengelolaTerhubung.value = (data as List)
          .map(
            (e) => ProfileModel.fromJson(e['profiles'] as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      listPengelolaTerhubung.clear();
    }
  }

  // Dipanggil dari list view saat tombol edit ditekan
  void initEdit(BankSampahModel data) {
    editData.value = data;
    _populateForm();
    _fetchPengelolaTerhubung(data.id);
  }

  void _populateForm() {
    namaController.text = editData.value!.nama;
    alamatController.text = editData.value!.alamat ?? '';
    rtController.text = editData.value!.rt ?? '';
    rwController.text = editData.value!.rw ?? '';
    isAktif.value = editData.value!.isActive;

    // Populate selectedRts
    if (editData.value!.rt != null && editData.value!.rt!.isNotEmpty) {
      selectedRts.value = editData.value!.rt!
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else {
      selectedRts.clear();
    }
  }

  void resetForm() {
    editData.value = null;
    listPengelolaTerhubung.clear();
    formKey.currentState?.reset();
    namaController.clear();
    alamatController.clear();
    rtController.clear();
    rwController.clear();
    selectedRts.clear();
    isAktif.value = true;
  }

  void goToForm({BankSampahModel? data}) =>
      Get.toNamed(AppRoutes.formBankSampah, arguments: data);

  Future<void> simpan() async {
    if (!formKey.currentState!.validate()) return;

    isSaving.value = true;
    try {
      final payload = {
        'nama': namaController.text.trim(),
        'alamat': alamatController.text.trim().isEmpty
            ? null
            : alamatController.text.trim(),
        'rt': selectedRts.isEmpty
            ? null
            : selectedRts.join(', '),
        'rw': rwController.text.trim().isEmpty
            ? null
            : rwController.text.trim(),
        'is_active': isAktif.value,
      };

      if (isEditMode) {
        await LocalDataService.client
            .from(DataTables.tableBankSampah)
            .update(payload)
            .eq('id', editData.value!.id);
        Get.back(result: true);
        Get.snackbar('Berhasil', 'Bank sampah berhasil diperbarui.');
      } else {
        await LocalDataService.client
            .from(DataTables.tableBankSampah)
            .insert(payload);
        Get.back(result: true);
        Get.snackbar('Berhasil', 'Bank sampah berhasil ditambahkan.');
      }

      await fetchBankSampah();
    } catch (e) {
      Get.snackbar('Gagal', 'Data gagal disimpan.');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> deleteBank(BankSampahModel bank) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Hapus Bank Sampah'),
        content: Text(
          'Yakin ingin menghapus "${bank.nama}"? Semua data terkait akan ikut terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await LocalDataService.client
          .from(DataTables.tableBankSampah)
          .delete()
          .eq('id', bank.id);
      listBankSampah.removeWhere((e) => e.id == bank.id);
      Get.snackbar('Berhasil', 'Bank sampah berhasil dihapus.');
    } catch (e) {
      Get.snackbar('Gagal', 'Bank sampah gagal dihapus.');
    }
  }

  Future<void> toggleAktif(BankSampahModel b) async {
    try {
      await LocalDataService.client
          .from(DataTables.tableBankSampah)
          .update({'is_active': !b.isActive})
          .eq('id', b.id);
      await fetchBankSampah();
    } catch (e) {
      Get.snackbar('Gagal', 'Gagal mengubah status.');
    }
  }

  Future<void> lepaskanPengelola(ProfileModel pengelola) async {
    if (editData.value == null) return;
    try {
      await LocalDataService.client
          .from(DataTables.tablePengelolaBankSampah)
          .delete()
          .eq('bank_sampah_id', editData.value!.id)
          .eq('profile_id', pengelola.id);
      listPengelolaTerhubung.removeWhere((p) => p.id == pengelola.id);
      Get.snackbar('Berhasil', 'Pengelola berhasil dilepas.');
    } catch (e) {
      Get.snackbar('Gagal', 'Gagal melepas pengelola.');
    }
  }

  @override
  void onClose() {
    namaController.dispose();
    alamatController.dispose();
    rtController.dispose();
    rwController.dispose();
    searchController.dispose();
    super.onClose();
  }
}
