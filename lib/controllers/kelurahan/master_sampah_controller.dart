import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/services/local_errors.dart';

import '../../core/services/local_data_service.dart';
import '../../core/constants/data_tables.dart';
import '../../models/kategori_model.dart';
import '../../models/sub_kategori_model.dart';
import '../../models/tipe_sampah_model.dart';
import '../../models/jenis_sampah_model.dart';
import '../../models/satuan_model.dart';

class MasterSampahController extends GetxController {
  // Tab aktif: 0=Kategori, 1=Sub Kategori, 2=Tipe, 3=Jenis, 4=Satuan
  final activeTab = 0.obs;

  // Data
  final listKategori    = <KategoriModel>[].obs;
  final listSubKategori = <SubKategoriModel>[].obs;
  final listTipe        = <TipeSampahModel>[].obs;   // ← BARU
  final listJenis       = <JenisSampahModel>[].obs;
  final listSatuan      = <SatuanModel>[].obs;

  // Dropdown untuk form
  final listKategoriDropdown    = <KategoriModel>[].obs;
  final listSubKategoriDropdown = <SubKategoriModel>[].obs;
  final listTipeDropdown        = <TipeSampahModel>[].obs;   // ← BARU

  final isLoading = false.obs;
  final isSaving  = false.obs;

  // Mode edit: id item yang sedang diedit (null = mode tambah)
  final editingId = RxnString();
  bool get isEditing => editingId.value != null;

  // ── Pencarian & filter status per tab ────────────────────────────────────
  final searchQuery = ''.obs;

  /// Filter status aktif: 'semua' | 'aktif' | 'nonaktif'
  final statusFilter = 'semua'.obs;

  void setSearchQuery(String v) => searchQuery.value = v;

  void setStatusFilter(String v) => statusFilter.value = v;

  /// Helper generik: terapkan pencarian (nama/deskripsi) + filter status
  /// pada daftar item yang punya [nama] & [isActive].
  List<T> _applyFilter<T>(
    Iterable<T> source,
    String Function(T) nama,
    String? Function(T) deskripsi,
    bool Function(T) isActive,
  ) {
    final q = searchQuery.value.trim().toLowerCase();
    return source.where((item) {
      // Filter status
      switch (statusFilter.value) {
        case 'aktif':
          if (!isActive(item)) return false;
          break;
        case 'nonaktif':
          if (isActive(item)) return false;
          break;
      }
      // Pencarian
      if (q.isEmpty) return true;
      final n = nama(item).toLowerCase();
      final d = (deskripsi(item) ?? '').toLowerCase();
      return n.contains(q) || d.contains(q);
    }).toList();
  }

  List<KategoriModel> get listKategoriFiltered => _applyFilter(
      listKategori, (e) => e.nama, (e) => e.deskripsi, (e) => e.isActive);

  List<SubKategoriModel> get listSubKategoriFiltered => _applyFilter(
      listSubKategori, (e) => e.nama, (e) => e.deskripsi, (e) => e.isActive);

  List<TipeSampahModel> get listTipeFiltered => _applyFilter(
      listTipe, (e) => e.nama, (e) => e.deskripsi, (e) => e.isActive);

  List<JenisSampahModel> get listJenisFiltered => _applyFilter(
      listJenis,
      (e) => e.nama,
      (e) => e.deskripsi,
      (e) => e.isActive);

  List<SatuanModel> get listSatuanFiltered => _applyFilter(
      listSatuan, (e) => e.nama, (e) => null, (_) => true);

  // Form controllers
  final namaController       = TextEditingController();
  final deskripsiController  = TextEditingController();
  final singkatanController  = TextEditingController();
  final formKey              = GlobalKey<FormState>();

  final selectedKategoriForm    = Rx<KategoriModel?>(null);
  final selectedSubKategoriForm = Rx<SubKategoriModel?>(null);
  final selectedTipeForm        = Rx<TipeSampahModel?>(null);   // ← BARU
  final selectedSatuanForm      = Rx<SatuanModel?>(null);

  @override
  void onInit() {
    super.onInit();
    fetchAll();
    ever(selectedKategoriForm,    (_) => _fetchSubKategoriDropdown());
    ever(selectedSubKategoriForm, (_) => _fetchTipeDropdown());   // ← BARU
  }

  Future<void> fetchAll() async {
    isLoading.value = true;
    try {
      await Future.wait([
        _fetchKategori(),
        _fetchSubKategori(),
        _fetchTipe(),
        _fetchJenis(),
        _fetchSatuan(),
      ]);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _fetchKategori() async {
    final data = await LocalDataService.client
        .from(DataTables.tableKategoriSampah)
        .select()
        .order('urutan');
    listKategori.value =
        (data as List).map((e) => KategoriModel.fromJson(e)).toList();
    listKategoriDropdown.value = listKategori;
  }

  Future<void> _fetchSubKategori() async {
    final data = await LocalDataService.client
        .from(DataTables.tableSubKategoriSampah)
        .select('*, kategori_sampah(*)')
        .order('urutan');
    listSubKategori.value =
        (data as List).map((e) => SubKategoriModel.fromJson(e)).toList();
  }

  Future<void> _fetchTipe() async {
    final data = await LocalDataService.client
        .from(DataTables.tableTipeSampah)
        .select('*, sub_kategori_sampah(*)')
        .order('urutan');
    listTipe.value =
        (data as List).map((e) => TipeSampahModel.fromJson(e)).toList();
  }

  Future<void> _fetchJenis() async {
    final data = await LocalDataService.client
        .from(DataTables.tableJenisSampah)
        .select('*, sub_kategori_sampah(*, kategori_sampah(*)), tipe_sampah(*), kategori_sampah(*), satuan(*)')
        .order('urutan');
    listJenis.value =
        (data as List).map((e) => JenisSampahModel.fromJson(e)).toList();
  }

  Future<void> _fetchSatuan() async {
    final data = await LocalDataService.client
        .from(DataTables.tableSatuan)
        .select()
        .order('nama');
    listSatuan.value =
        (data as List).map((e) => SatuanModel.fromJson(e)).toList();
  }

  Future<void> _fetchSubKategoriDropdown() async {
    if (selectedKategoriForm.value == null) {
      listSubKategoriDropdown.clear();
      listTipeDropdown.clear();
      if (!isEditing) {
        selectedSubKategoriForm.value = null;
        selectedTipeForm.value = null;
      }
      return;
    }
    final data = await LocalDataService.client
        .from(DataTables.tableSubKategoriSampah)
        .select()
        .eq('kategori_id', selectedKategoriForm.value!.id)
        .order('urutan');
    listSubKategoriDropdown.value =
        (data as List).map((e) => SubKategoriModel.fromJson(e)).toList();
    if (!isEditing) {
      listTipeDropdown.clear();
      selectedSubKategoriForm.value = null;
      selectedTipeForm.value = null;
    } else {
      _sinkSelSubKategori();
    }
  }

  /// Saat mode edit: selaraskan instance sub kategori terpilih dengan item
  /// dropdown yang baru di-fetch (match by id) agar DropdownButtonFormField
  /// menampilkan nilai prefill dengan benar.
  void _sinkSelSubKategori() {
    final sel = selectedSubKategoriForm.value;
    if (sel == null) return;
    for (final s in listSubKategoriDropdown) {
      if (s.id == sel.id) {
        selectedSubKategoriForm.value = s;
        return;
      }
    }
    // Tidak cocok dengan daftar baru (mis. kategori diganti saat edit)
    selectedSubKategoriForm.value = null;
    selectedTipeForm.value = null;
  }

  void _sinkSelTipe() {
    final sel = selectedTipeForm.value;
    if (sel == null) return;
    for (final t in listTipeDropdown) {
      if (t.id == sel.id) {
        selectedTipeForm.value = t;
        return;
      }
    }
    selectedTipeForm.value = null;
  }

  Future<void> _fetchTipeDropdown() async {
    if (selectedSubKategoriForm.value == null) {
      listTipeDropdown.clear();
      if (!isEditing) {
        selectedTipeForm.value = null;
      }
      return;
    }
    final data = await LocalDataService.client
        .from(DataTables.tableTipeSampah)
        .select()
        .eq('sub_kategori_id', selectedSubKategoriForm.value!.id)
        .order('urutan');
    listTipeDropdown.value =
        (data as List).map((e) => TipeSampahModel.fromJson(e)).toList();
    if (!isEditing) {
      selectedTipeForm.value = null;
    } else {
      _sinkSelTipe();
    }
  }

  void resetForm() {
    formKey.currentState?.reset();
    namaController.clear();
    deskripsiController.clear();
    singkatanController.clear();
    selectedKategoriForm.value    = null;
    selectedSubKategoriForm.value = null;
    selectedTipeForm.value        = null;
    selectedSatuanForm.value      = null;
    listSubKategoriDropdown.clear();
    listTipeDropdown.clear();
    editingId.value = null;
  }

  // ── Mulai edit (prefill form) ──────────────────────────────────────────────

  KategoriModel? _kategoriById(String? id) {
    if (id == null) return null;
    try {
      return listKategoriDropdown.firstWhere((k) => k.id == id);
    } catch (_) {
      return null;
    }
  }

  void mulaiEditKategori(KategoriModel item) {
    resetForm();
    editingId.value = item.id;
    namaController.text = item.nama;
    deskripsiController.text = item.deskripsi ?? '';
  }

  void mulaiEditSubKategori(SubKategoriModel item) {
    resetForm();
    editingId.value = item.id;
    namaController.text = item.nama;
    deskripsiController.text = item.deskripsi ?? '';
    selectedKategoriForm.value = _kategoriById(item.kategoriId);
  }

  void mulaiEditTipe(TipeSampahModel item) {
    resetForm();
    editingId.value = item.id;
    namaController.text = item.nama;
    deskripsiController.text = item.deskripsi ?? '';
    final kategori = _kategoriById(item.subKategori?.kategoriId);
    if (kategori != null) {
      selectedKategoriForm.value = kategori;
      selectedSubKategoriForm.value = item.subKategori;
    }
  }

  void mulaiEditJenis(JenisSampahModel item) {
    resetForm();
    editingId.value = item.id;
    namaController.text = item.nama;
    deskripsiController.text = item.deskripsi ?? '';
    final kategori =
        _kategoriById(item.kategoriId ?? item.subKategori?.kategoriId);
    selectedKategoriForm.value = kategori;
    // Prefill sub/tipe hanya jika relasinya cocok dengan kategori terpilih,
    // agar nilai awal selalu ada di daftar dropdown (hindari assert).
    if (item.subKategori != null &&
        kategori != null &&
        kategori.id == item.subKategori!.kategoriId) {
      selectedSubKategoriForm.value = item.subKategori;
    }
    if (item.tipe != null &&
        selectedSubKategoriForm.value != null &&
        selectedSubKategoriForm.value!.id == item.tipe!.subKategoriId) {
      selectedTipeForm.value = item.tipe;
    }
    selectedSatuanForm.value = item.satuanDefault;
  }

  void mulaiEditSatuan(SatuanModel item) {
    resetForm();
    editingId.value = item.id;
    namaController.text = item.nama;
    singkatanController.text = item.singkatan;
  }

  // ── Update (edit) ─────────────────────────────────────────────────────────

  Future<void> updateKategori() async {
    if (!formKey.currentState!.validate() || editingId.value == null) return;
    isSaving.value = true;
    try {
      await LocalDataService.client
          .from(DataTables.tableKategoriSampah)
          .update({
        'nama': namaController.text.trim(),
        'deskripsi': deskripsiController.text.trim().isEmpty
            ? null
            : deskripsiController.text.trim(),
      }).eq('id', editingId.value!);
      await _fetchKategori();
      resetForm();
      Get.back();
      Get.snackbar('Berhasil', 'Kategori berhasil diperbarui.');
    } catch (e) {
      Get.snackbar('Gagal',
          'Gagal memperbarui kategori: ${_mapPostgrestError(e)}');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> updateSubKategori() async {
    if (!formKey.currentState!.validate() ||
        editingId.value == null ||
        selectedKategoriForm.value == null) {
      return;
    }
    isSaving.value = true;
    try {
      await LocalDataService.client
          .from(DataTables.tableSubKategoriSampah)
          .update({
        'kategori_id': selectedKategoriForm.value!.id,
        'nama': namaController.text.trim(),
        'deskripsi': deskripsiController.text.trim().isEmpty
            ? null
            : deskripsiController.text.trim(),
      }).eq('id', editingId.value!);
      await _fetchSubKategori();
      resetForm();
      Get.back();
      Get.snackbar('Berhasil', 'Sub kategori berhasil diperbarui.');
    } catch (e) {
      Get.snackbar('Gagal',
          'Gagal memperbarui sub kategori: ${_mapPostgrestError(e)}');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> updateTipe() async {
    if (!formKey.currentState!.validate() ||
        editingId.value == null ||
        selectedSubKategoriForm.value == null) {
      return;
    }
    isSaving.value = true;
    try {
      await LocalDataService.client
          .from(DataTables.tableTipeSampah)
          .update({
        'sub_kategori_id': selectedSubKategoriForm.value!.id,
        'nama': namaController.text.trim(),
        'deskripsi': deskripsiController.text.trim().isEmpty
            ? null
            : deskripsiController.text.trim(),
      }).eq('id', editingId.value!);
      await _fetchTipe();
      resetForm();
      Get.back();
      Get.snackbar('Berhasil', 'Tipe berhasil diperbarui.');
    } catch (e) {
      Get.snackbar('Gagal',
          'Gagal memperbarui tipe: ${_mapPostgrestError(e)}');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> updateJenis() async {
    if (!formKey.currentState!.validate() || editingId.value == null) return;
    isSaving.value = true;
    try {
      await LocalDataService.client
          .from(DataTables.tableJenisSampah)
          .update({
        'sub_kategori_id': selectedSubKategoriForm.value?.id,
        'tipe_id':         selectedTipeForm.value?.id,
        'kategori_id':     selectedKategoriForm.value?.id,
        'nama':            namaController.text.trim(),
        'deskripsi': deskripsiController.text.trim().isEmpty
            ? null
            : deskripsiController.text.trim(),
        'satuan_default_id': selectedSatuanForm.value?.id,
      }).eq('id', editingId.value!);
      await _fetchJenis();
      resetForm();
      Get.back();
      Get.snackbar('Berhasil', 'Jenis sampah berhasil diperbarui.');
    } catch (e) {
      Get.snackbar('Gagal',
          'Gagal memperbarui jenis sampah: ${_mapPostgrestError(e)}');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> updateSatuan() async {
    if (!formKey.currentState!.validate() || editingId.value == null) return;
    isSaving.value = true;
    try {
      await LocalDataService.client
          .from(DataTables.tableSatuan)
          .update({
        'nama':      namaController.text.trim(),
        'singkatan': singkatanController.text.trim(),
      }).eq('id', editingId.value!);
      await _fetchSatuan();
      resetForm();
      Get.back();
      Get.snackbar('Berhasil', 'Satuan berhasil diperbarui.');
    } catch (e) {
      Get.snackbar('Gagal',
          'Gagal memperbarui satuan: ${_mapPostgrestError(e)}');
    } finally {
      isSaving.value = false;
    }
  }

  // ── Simpan ─────────────────────────────────────────────────────────────────

  Future<void> simpanKategori() async {
    if (!formKey.currentState!.validate()) return;
    isSaving.value = true;
    try {
      await LocalDataService.client
          .from(DataTables.tableKategoriSampah)
          .insert({
        'nama': namaController.text.trim(),
        'deskripsi': deskripsiController.text.trim().isEmpty
            ? null
            : deskripsiController.text.trim(),
      });
      await _fetchKategori();
      resetForm();
      Get.snackbar('Berhasil', 'Kategori berhasil ditambahkan.');
    } catch (e) {
      Get.snackbar('Gagal',
          'Gagal menyimpan kategori: ${_mapPostgrestError(e)}');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> simpanSubKategori() async {
    if (!formKey.currentState!.validate()) return;
    if (selectedKategoriForm.value == null) {
      Get.snackbar('Validasi', 'Pilih kategori terlebih dahulu.');
      return;
    }
    isSaving.value = true;
    try {
      await LocalDataService.client
          .from(DataTables.tableSubKategoriSampah)
          .insert({
        'kategori_id': selectedKategoriForm.value!.id,
        'nama': namaController.text.trim(),
        'deskripsi': deskripsiController.text.trim().isEmpty
            ? null
            : deskripsiController.text.trim(),
      });
      await _fetchSubKategori();
      resetForm();
      Get.snackbar('Berhasil', 'Sub kategori berhasil ditambahkan.');
    } catch (e) {
      Get.snackbar('Gagal',
          'Gagal menyimpan sub kategori: ${_mapPostgrestError(e)}');
    } finally {
      isSaving.value = false;
    }
  }

  // ← BARU
  Future<void> simpanTipe() async {
    if (!formKey.currentState!.validate()) return;
    if (selectedSubKategoriForm.value == null) {
      Get.snackbar('Validasi', 'Pilih sub kategori terlebih dahulu.');
      return;
    }
    isSaving.value = true;
    try {
      await LocalDataService.client
          .from(DataTables.tableTipeSampah)
          .insert({
        'sub_kategori_id': selectedSubKategoriForm.value!.id,
        'nama': namaController.text.trim(),
        'deskripsi': deskripsiController.text.trim().isEmpty
            ? null
            : deskripsiController.text.trim(),
      });
      await _fetchTipe();
      resetForm();
      Get.snackbar('Berhasil', 'Tipe berhasil ditambahkan.');
    } catch (e) {
      Get.snackbar('Gagal',
          'Gagal menyimpan tipe: ${_mapPostgrestError(e)}');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> simpanJenis() async {
    if (!formKey.currentState!.validate()) return;
    isSaving.value = true;
    try {
      await LocalDataService.client
          .from(DataTables.tableJenisSampah)
          .insert({
        'sub_kategori_id': selectedSubKategoriForm.value?.id,
        'tipe_id':         selectedTipeForm.value?.id,
        'kategori_id':     selectedKategoriForm.value?.id,
        'nama':            namaController.text.trim(),
        'deskripsi': deskripsiController.text.trim().isEmpty
            ? null
            : deskripsiController.text.trim(),
        'satuan_default_id': selectedSatuanForm.value?.id,
      });
      await _fetchJenis();
      resetForm();
      Get.snackbar('Berhasil', 'Jenis sampah berhasil ditambahkan.');
    } catch (e) {
      Get.snackbar('Gagal',
          'Gagal menyimpan jenis sampah: ${_mapPostgrestError(e)}');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> simpanSatuan() async {
    if (!formKey.currentState!.validate()) return;
    isSaving.value = true;
    try {
      await LocalDataService.client.from(DataTables.tableSatuan).insert({
        'nama':       namaController.text.trim(),
        'singkatan':  singkatanController.text.trim(),
      });
      await _fetchSatuan();
      resetForm();
      Get.snackbar('Berhasil', 'Satuan berhasil ditambahkan.');
    } catch (e) {
      Get.snackbar('Gagal',
          'Gagal menyimpan satuan: ${_mapPostgrestError(e)}');
    } finally {
      isSaving.value = false;
    }
  }

  // ── Hapus ──────────────────────────────────────────────────────────────────

  Future<void> hapusKategori(String id) async {
    try {
      await LocalDataService.client
          .from(DataTables.tableKategoriSampah)
          .delete()
          .eq('id', id);
      listKategori.removeWhere((e) => e.id == id);
      Get.snackbar('Berhasil', 'Kategori dihapus.');
    } catch (e) {
      Get.snackbar('Gagal',
          'Kategori tidak bisa dihapus karena masih digunakan.');
    }
  }

  Future<void> hapusSubKategori(String id) async {
    try {
      await LocalDataService.client
          .from(DataTables.tableSubKategoriSampah)
          .delete()
          .eq('id', id);
      listSubKategori.removeWhere((e) => e.id == id);
      Get.snackbar('Berhasil', 'Sub kategori dihapus.');
    } catch (e) {
      Get.snackbar('Gagal',
          'Sub kategori tidak bisa dihapus karena masih digunakan.');
    }
  }

  // ← BARU
  Future<void> hapusTipe(String id) async {
    try {
      await LocalDataService.client
          .from(DataTables.tableTipeSampah)
          .delete()
          .eq('id', id);
      listTipe.removeWhere((e) => e.id == id);
      Get.snackbar('Berhasil', 'Tipe dihapus.');
    } catch (e) {
      Get.snackbar('Gagal',
          'Tipe tidak bisa dihapus karena masih digunakan.');
    }
  }

  Future<void> hapusJenis(String id) async {
    try {
      await LocalDataService.client
          .from(DataTables.tableJenisSampah)
          .delete()
          .eq('id', id);
      listJenis.removeWhere((e) => e.id == id);
      Get.snackbar('Berhasil', 'Jenis sampah dihapus.');
    } catch (e) {
      Get.snackbar('Gagal',
          'Jenis sampah tidak bisa dihapus karena masih digunakan.');
    }
  }

  Future<void> hapusSatuan(String id) async {
    try {
      await LocalDataService.client
          .from(DataTables.tableSatuan)
          .delete()
          .eq('id', id);
      listSatuan.removeWhere((e) => e.id == id);
      Get.snackbar('Berhasil', 'Satuan dihapus.');
    } catch (e) {
      Get.snackbar('Gagal',
          'Satuan tidak bisa dihapus karena masih digunakan.');
    }
  }

  String _mapPostgrestError(dynamic e) {
    if (e is LocalDataException) {
      if (e.code == '23505') return 'Data dengan nama tersebut sudah terdaftar.';
      return e.message;
    }
    return e.toString();
  }

  @override
  void onClose() {
    namaController.dispose();
    deskripsiController.dispose();
    singkatanController.dispose();
    super.onClose();
  }
}
