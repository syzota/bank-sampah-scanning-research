import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:get/get.dart';

import '../../core/services/local_data_service.dart';
import '../../core/services/local_database.dart';
import '../../core/services/scan_repository.dart';
import '../../core/services/yolo_scan_service.dart';
import '../../models/waste_scan_result.dart';
import '../../core/utils/waste_image_crop.dart';
import '../../views/pengelola/waste_object_picker_view.dart';
import '../../core/services/session_service.dart';
import '../../core/constants/data_tables.dart';
import '../../core/utils/format_helper.dart';
import '../../models/kategori_model.dart';
import '../../models/sub_kategori_model.dart';
import '../../models/tipe_sampah_model.dart';
import '../../models/jenis_sampah_model.dart';
import '../../models/satuan_model.dart';
import '../../models/harga_sampah_model.dart';
import '../../models/pengelolaan_sampah_model.dart';

class InputSampahController extends GetxController {
  final formKey = GlobalKey<FormState>();

  // Text controllers
  final jumlahController = TextEditingController();
  final hargaPerSatuanController = TextEditingController();
  final catatanController = TextEditingController();
  final tanggalController = TextEditingController();
  final totalHargaController = TextEditingController();
  final nasabahController = TextEditingController();

  // Data list
  final listKategori = <KategoriModel>[].obs;
  final listSubKategori = <SubKategoriModel>[].obs;
  final listTipe = <TipeSampahModel>[].obs; // ← BARU
  final listJenisSampah = <JenisSampahModel>[].obs;
  final listSatuan = <SatuanModel>[].obs;
  final listNamaNasabah = <String>[].obs;

  // State dropdown
  final selectedKategoriId = ''.obs;
  final selectedSubKategoriId = ''.obs;
  final selectedTipeId = ''.obs; // ← BARU
  final selectedJenisId = ''.obs;
  final selectedSatuanId = ''.obs;

  // Tanggal
  final selectedTanggal = Rx<DateTime?>(DateTime.now());

  // Harga snapshot otomatis dari tabel harga_sampah
  final hargaSnapshot = Rx<HargaSampahModel?>(null);

  // Estimasi reactive variables
  final rxJumlah = 0.0.obs;
  final rxHargaPerSatuan = 0.0.obs;

  // Loading state
  final isLoading = false.obs;

  // Scan foto YOLO; prediksi asli tetap tersimpan saat jenis dikoreksi.
  final scanOriginalPhotoPath = ''.obs;
  final scanPhotoPath = ''.obs;
  final scanCrop = Rx<WasteImageCrop?>(null);
  final scanError = ''.obs;
  final scanResult = Rx<WasteScanResult?>(null);
  final isPickingPhoto = false.obs;
  final isScanning = false.obs;
  final isCroppingPhoto = false.obs;
  final _scanPicker = ImagePicker();
  String _scanPhotoSource = 'gallery';
  bool get isScanSupported => YoloScanService.instance.isSupported;
  bool get isScanBusy =>
      isPickingPhoto.value || isScanning.value || isCroppingPhoto.value;

  // Guard untuk mencegah ever() trigger saat populateEditData
  bool _isPopulating = false;

  // Edit mode
  PengelolaanSampahModel? editData;
  bool get isEditMode => editData != null;

  bool get isKategoriAnorganik {
    if (selectedKategoriId.value.isEmpty) return false;
    final kat = listKategori.firstWhereOrNull(
      (k) => k.id == selectedKategoriId.value,
    );
    final nama = kat?.nama.toLowerCase() ?? '';
    return nama.contains('an organik') || nama.contains('anorganik');
  }

  bool get isMinyakJelantah {
    // 1. Kategori
    if (selectedKategoriId.value.isNotEmpty) {
      final kat = listKategori.firstWhereOrNull(
        (k) => k.id == selectedKategoriId.value,
      );
      final nama = kat?.nama.toLowerCase() ?? '';
      if (nama.contains('minyak jelantah') || nama.contains('jelantah'))
        return true;
    }
    // 2. Sub Kategori
    if (selectedSubKategoriId.value.isNotEmpty) {
      final sub = listSubKategori.firstWhereOrNull(
        (s) => s.id == selectedSubKategoriId.value,
      );
      final nama = sub?.nama.toLowerCase() ?? '';
      if (nama.contains('minyak jelantah') || nama.contains('jelantah'))
        return true;
    }
    // 3. Tipe
    if (selectedTipeId.value.isNotEmpty) {
      final tipe = listTipe.firstWhereOrNull(
        (t) => t.id == selectedTipeId.value,
      );
      final nama = tipe?.nama.toLowerCase() ?? '';
      if (nama.contains('minyak jelantah') || nama.contains('jelantah'))
        return true;
    }
    // 4. Jenis
    if (selectedJenisId.value.isNotEmpty) {
      final jenis = listJenisSampah.firstWhereOrNull(
        (j) => j.id == selectedJenisId.value,
      );
      final nama = jenis?.nama.toLowerCase() ?? '';
      if (nama.contains('minyak jelantah') || nama.contains('jelantah'))
        return true;
    }
    return false;
  }

  void _applyUnitLocks() {
    // No-op: Unit locks for Kategori Anorganik and Minyak Jelantah are disabled to allow selection.
  }

  bool get isSatuanAuto {
    if (selectedJenisId.value.isEmpty) return false;
    final jenis = listJenisSampah.firstWhereOrNull(
      (j) => j.id == selectedJenisId.value,
    );
    return jenis?.satuanDefaultId != null;
  }

  String get jenisSampahBreadcrumb {
    if (selectedKategoriId.value.isEmpty) return '-';
    final kat =
        listKategori
            .firstWhereOrNull((k) => k.id == selectedKategoriId.value)
            ?.nama ??
        '';
    if (kat.isEmpty) return '';
    String breadcrumb = kat;
    if (selectedSubKategoriId.value.isNotEmpty) {
      final sub =
          listSubKategori
              .firstWhereOrNull((s) => s.id == selectedSubKategoriId.value)
              ?.nama ??
          '';
      if (sub.isNotEmpty) breadcrumb += ' > $sub';
    }
    if (selectedTipeId.value.isNotEmpty) {
      final tipe =
          listTipe
              .firstWhereOrNull((t) => t.id == selectedTipeId.value)
              ?.nama ??
          '';
      if (tipe.isNotEmpty) breadcrumb += ' > $tipe';
    }
    if (selectedJenisId.value.isNotEmpty) {
      final jenis =
          listJenisSampah
              .firstWhereOrNull((j) => j.id == selectedJenisId.value)
              ?.nama ??
          '';
      if (jenis.isNotEmpty) breadcrumb += ' > $jenis';
    }
    return breadcrumb;
  }

  String get selectedSatuanSingkatan {
    if (selectedSatuanId.value.isEmpty) return '';
    return listSatuan
            .firstWhereOrNull((s) => s.id == selectedSatuanId.value)
            ?.singkatan ??
        '';
  }

  String get selectedTanggalFormat {
    if (selectedTanggal.value == null) return '-';
    return FormatHelper.date(selectedTanggal.value!);
  }

  double get activeHargaPerSatuan {
    if (hargaSnapshot.value != null) {
      return hargaSnapshot.value!.hargaPerSatuan;
    }
    return double.tryParse(
          hargaPerSatuanController.text
              .trim()
              .replaceAll('.', '')
              .replaceAll(',', '.'),
        ) ??
        0.0;
  }

  @override
  void onInit() {
    super.onInit();
    _checkEditMode();
    _fetchMasterData();

    // Listener cascade dropdown — skip saat sedang populate edit data
    ever(selectedKategoriId, (_) {
      if (!_isPopulating) _onKategoriChanged();
    });
    ever(selectedSubKategoriId, (_) {
      if (!_isPopulating) _onSubKategoriChanged();
    });
    ever(selectedTipeId, (_) {
      if (!_isPopulating) _onTipeChanged();
    }); // ← BARU
    ever(selectedJenisId, (_) {
      if (!_isPopulating) _onJenisChanged();
    });

    // Listeners untuk update estimasi total secara real-time
    jumlahController.addListener(_updateEstimasi);
    hargaPerSatuanController.addListener(_updateEstimasi);
  }

  @override
  void onReady() {
    super.onReady();
    if (isScanSupported) _recoverLostScanPhoto();
  }

  Future<void> _storeScanPhoto(XFile photo, String source) async {
    final folder = await getApplicationSupportDirectory();
    final imageFolder = Directory(p.join(folder.path, 'scan_images'));
    await imageFolder.create(recursive: true);
    final extension = p.extension(photo.path).toLowerCase();
    final path = p.join(
      imageFolder.path,
      LocalDatabase.newId() + (extension.isEmpty ? '.jpg' : extension),
    );
    await photo.saveTo(path);
    if (isClosed) return;
    _scanPhotoSource = source;
    scanOriginalPhotoPath.value = path;
    scanPhotoPath.value = path;
    scanCrop.value = null;
    scanResult.value = null;
    scanError.value = '';
    await _chooseScanObject();
  }

  Future<void> chooseScanObject() async {
    if (!isScanSupported || isScanBusy || isLoading.value) return;
    scanError.value = '';
    await _chooseScanObject();
  }

  Future<void> _chooseScanObject() async {
    final originalPath = scanOriginalPhotoPath.value;
    if (isClosed || originalPath.isEmpty) return;
    isCroppingPhoto.value = true;
    try {
      final selected = await Get.to<WasteImageCrop>(
        () => WasteObjectPickerView(
          originalImagePath: originalPath,
          outputImagePath: p.join(
            p.dirname(originalPath),
            LocalDatabase.newId() + '_crop.png',
          ),
        ),
      );
      if (isClosed || selected == null) return;
      scanCrop.value = selected;
      scanPhotoPath.value = selected.croppedPath;
      scanResult.value = null;
      scanError.value = '';
    } catch (error) {
      if (!isClosed) scanError.value = 'Objek belum berhasil dipilih: $error';
    } finally {
      if (!isClosed) isCroppingPhoto.value = false;
    }
  }

  Future<void> pickScanPhoto(ImageSource source) async {
    if (!isScanSupported || isScanBusy || isLoading.value) return;
    isPickingPhoto.value = true;
    scanError.value = '';
    final name = source == ImageSource.camera ? 'camera' : 'gallery';
    try {
      await LocalDatabase.instance.setSetting('pending_scan_source', name);
      // Keep the original, then let the user select one object before Scan.
      final photo = await _scanPicker.pickImage(source: source);
      if (photo != null) await _storeScanPhoto(photo, name);
    } catch (error) {
      if (!isClosed) scanError.value = 'Foto gagal dibuka: $error';
    } finally {
      await LocalDatabase.instance.database.delete(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['pending_scan_source'],
      );
      if (!isClosed) isPickingPhoto.value = false;
    }
  }

  Future<void> _recoverLostScanPhoto() async {
    if (isScanBusy) return;
    isPickingPhoto.value = true;
    try {
      final recovered = await _scanPicker.retrieveLostData();
      if (recovered.isEmpty) return;
      final files = recovered.files;
      if (files != null && files.isNotEmpty) {
        final source = await LocalDatabase.instance.setting(
          'pending_scan_source',
        );
        await _storeScanPhoto(files.first, source ?? 'recovered');
      } else if (recovered.exception != null && !isClosed) {
        scanError.value =
            'Foto belum berhasil dipulihkan. Silakan ambil ulang.';
      }
    } catch (error) {
      if (!isClosed) scanError.value = 'Foto belum berhasil dipulihkan: $error';
    } finally {
      await LocalDatabase.instance.database.delete(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['pending_scan_source'],
      );
      if (!isClosed) isPickingPhoto.value = false;
    }
  }

  void clearScanPhoto() {
    if (isScanBusy || isLoading.value) return;
    scanOriginalPhotoPath.value = '';
    scanPhotoPath.value = '';
    scanCrop.value = null;
    scanResult.value = null;
    scanError.value = '';
    // Recorded images stay available for reviewing research results.
  }

  Future<void> scanSelectedPhoto() async {
    if (!isScanSupported ||
        isScanBusy ||
        isLoading.value ||
        scanPhotoPath.value.isEmpty) {
      return;
    }
    if (scanCrop.value == null) {
      scanError.value = 'Pilih objek sampah terlebih dahulu.';
      return;
    }
    isScanning.value = true;
    scanError.value = '';
    scanResult.value = null;
    try {
      final result = await ScanRepository.instance.scanAndRecord(
        scanPhotoPath.value,
        _scanPhotoSource,
        imageCrop: scanCrop.value,
      );
      if (isClosed) return;
      scanResult.value = result;
      await _applyScanPrediction(result);
    } catch (error) {
      if (!isClosed) {
        scanError.value = scanResult.value == null
            ? 'Scan gagal: $error'
            : 'Hasil belum bisa diterapkan. Pilih jenis sampah secara manual. $error';
      }
    } finally {
      if (!isClosed) isScanning.value = false;
    }
  }

  Future<void> _applyScanPrediction(WasteScanResult result) async {
    final rows = await LocalDatabase.instance.database.query(
      'jenis_sampah',
      where: 'model_label = ? AND is_active = 1',
      whereArgs: [result.predictedClass.label],
      limit: 1,
    );
    if (rows.isEmpty)
      throw StateError('Label model belum ada di master lokal.');
    final categoryId = rows.single['kategori_id'] as String?;
    if (categoryId == null || !listKategori.any((k) => k.id == categoryId)) {
      throw StateError('Kategori hasil scan tidak tersedia.');
    }
    _isPopulating = true;
    try {
      selectedJenisId.value = '';
      selectedKategoriId.value = categoryId;
      selectedSubKategoriId.value = '';
      selectedTipeId.value = '';
      listSubKategori.clear();
      listTipe.clear();
      listJenisSampah.clear();
      hargaSnapshot.value = null;
      await _fetchJenisByKategori(categoryId);
      if (isClosed) return;
      final jenis = listJenisSampah.firstWhereOrNull(
        (j) => j.id == rows.single['id'],
      );
      if (jenis == null) throw StateError('Jenis hasil scan tidak tersedia.');
      selectedJenisId.value = jenis.id;
      selectedSatuanId.value = jenis.satuanDefaultId ?? '';
    } finally {
      _isPopulating = false;
    }
    if (!isClosed) await _fetchHargaOtomatis();
  }

  void _checkEditMode() {
    if (Get.arguments != null && Get.arguments is PengelolaanSampahModel) {
      editData = Get.arguments as PengelolaanSampahModel;
    }
  }

  Future<void> _fetchMasterData() async {
    isLoading.value = true;
    try {
      await Future.wait([_fetchKategori(), _fetchSatuan(), fetchNamaNasabah()]);
      if (isEditMode) {
        await _populateEditData();
      } else {
        if (selectedTanggal.value != null) {
          tanggalController.text = FormatHelper.date(selectedTanggal.value!);
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat data master.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _fetchKategori() async {
    final data = await LocalDataService.client
        .from(DataTables.tableKategoriSampah)
        .select()
        .eq('is_active', true)
        .order('urutan');
    listKategori.value = (data as List)
        .map((e) => KategoriModel.fromJson(e))
        .toList();
  }

  Future<void> _fetchSubKategori(String kategoriId) async {
    final data = await LocalDataService.client
        .from(DataTables.tableSubKategoriSampah)
        .select()
        .eq('kategori_id', kategoriId)
        .eq('is_active', true)
        .order('urutan');
    listSubKategori.value = (data as List)
        .map((e) => SubKategoriModel.fromJson(e))
        .toList();
  }

  // ← BARU: fetch tipe berdasarkan sub_kategori_id
  Future<void> _fetchTipe(String subKategoriId) async {
    final data = await LocalDataService.client
        .from(DataTables.tableTipeSampah)
        .select()
        .eq('sub_kategori_id', subKategoriId)
        .eq('is_active', true)
        .order('urutan');
    listTipe.value = (data as List)
        .map((e) => TipeSampahModel.fromJson(e))
        .toList();
  }

  // Fetch jenis berdasarkan tipe_id
  Future<void> _fetchJenisByTipe(String tipeId) async {
    final data = await LocalDataService.client
        .from(DataTables.tableJenisSampah)
        .select('*, satuan(*)')
        .eq('tipe_id', tipeId)
        .eq('is_active', true)
        .order('urutan');
    listJenisSampah.value = (data as List)
        .map((e) => JenisSampahModel.fromJson(e))
        .toList();
  }

  // Fetch jenis langsung dari sub_kategori (Kertas, Logam, Kaca — tanpa tipe)
  Future<void> _fetchJenisBySubKategori(String subKategoriId) async {
    final data = await LocalDataService.client
        .from(DataTables.tableJenisSampah)
        .select('*, satuan(*)')
        .eq('sub_kategori_id', subKategoriId)
        .isFilter('tipe_id', null)
        .eq('is_active', true)
        .order('urutan');
    listJenisSampah.value = (data as List)
        .map((e) => JenisSampahModel.fromJson(e))
        .toList();
  }

  // Fetch jenis langsung dari kategori (Organik, Minyak Jelantah)
  Future<void> _fetchJenisByKategori(String kategoriId) async {
    final data = await LocalDataService.client
        .from(DataTables.tableJenisSampah)
        .select('*, satuan(*)')
        .eq('kategori_id', kategoriId)
        .isFilter('sub_kategori_id', null)
        .isFilter('tipe_id', null)
        .eq('is_active', true)
        .order('urutan');
    listJenisSampah.value = (data as List)
        .map((e) => JenisSampahModel.fromJson(e))
        .toList();
  }

  Future<void> _fetchSatuan() async {
    final data = await LocalDataService.client
        .from(DataTables.tableSatuan)
        .select()
        .order('nama');
    listSatuan.value = (data as List)
        .map((e) => SatuanModel.fromJson(e))
        .toList();
  }

  Future<void> fetchNamaNasabah() async {
    final bankSampahId = SessionService.to.activeBankSampahId;
    if (bankSampahId.isEmpty) return;
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
      debugPrint('ERROR FETCH NASABAH: $e');
    }
  }

  Future<void> _fetchHargaOtomatis() async {
    final bankSampahId = SessionService.to.activeBankSampahId;
    hargaSnapshot.value = null;

    try {
      dynamic data;

      if (selectedJenisId.value.isNotEmpty) {
        data = await LocalDataService.client
            .from(DataTables.tableHargaSampah)
            .select('*, satuan(*)')
            .eq('bank_sampah_id', bankSampahId)
            .eq('jenis_sampah_id', selectedJenisId.value)
            .maybeSingle();
      }

      if (data == null && selectedTipeId.value.isNotEmpty) {
        data = await LocalDataService.client
            .from(DataTables.tableHargaSampah)
            .select('*, satuan(*)')
            .eq('bank_sampah_id', bankSampahId)
            .eq('tipe_id', selectedTipeId.value)
            .isFilter('jenis_sampah_id', null)
            .maybeSingle();
      }

      if (data == null && selectedSubKategoriId.value.isNotEmpty) {
        data = await LocalDataService.client
            .from(DataTables.tableHargaSampah)
            .select('*, satuan(*)')
            .eq('bank_sampah_id', bankSampahId)
            .eq('sub_kategori_id', selectedSubKategoriId.value)
            .isFilter('tipe_id', null)
            .isFilter('jenis_sampah_id', null)
            .maybeSingle();
      }

      if (data == null && selectedKategoriId.value.isNotEmpty) {
        data = await LocalDataService.client
            .from(DataTables.tableHargaSampah)
            .select('*, satuan(*)')
            .eq('bank_sampah_id', bankSampahId)
            .eq('kategori_id', selectedKategoriId.value)
            .isFilter('sub_kategori_id', null)
            .isFilter('tipe_id', null)
            .isFilter('jenis_sampah_id', null)
            .maybeSingle();
      }

      if (data != null) {
        hargaSnapshot.value = HargaSampahModel.fromJson(data);
        hargaPerSatuanController.text = FormatHelper.number(
          hargaSnapshot.value!.hargaPerSatuan,
        );
        if (hargaSnapshot.value?.satuanId != null &&
            selectedSatuanId.value.isEmpty) {
          selectedSatuanId.value = hargaSnapshot.value!.satuanId;
        }
      }
    } catch (_) {
      // Harga tidak ditemukan, tidak masalah
    }
  }

  // ── Cascade handlers ──────────────────────────────────────────────────────

  void _onKategoriChanged() {
    selectedSubKategoriId.value = '';
    selectedTipeId.value = '';
    selectedJenisId.value = '';
    listSubKategori.clear();
    listTipe.clear();
    listJenisSampah.clear();
    hargaSnapshot.value = null;

    if (selectedKategoriId.value.isNotEmpty) {
      _applyUnitLocks();

      _fetchSubKategori(selectedKategoriId.value).then((_) {
        // Jika tidak ada sub kategori → langsung fetch jenis dari kategori
        // (kasus Organik, Minyak Jelantah)
        if (listSubKategori.isEmpty) {
          _fetchJenisByKategori(selectedKategoriId.value).then((_) {
            _applyUnitLocks();
          });
        } else {
          _applyUnitLocks();
        }
      });
      _fetchHargaOtomatis();
    }
  }

  void _onSubKategoriChanged() {
    selectedTipeId.value = '';
    selectedJenisId.value = '';
    listTipe.clear();
    listJenisSampah.clear();

    if (selectedSubKategoriId.value.isNotEmpty) {
      _applyUnitLocks();
      // Coba fetch tipe dulu; kalau kosong, langsung fetch jenis
      _fetchTipe(selectedSubKategoriId.value).then((_) {
        if (listTipe.isEmpty) {
          _fetchJenisBySubKategori(selectedSubKategoriId.value).then((_) {
            _applyUnitLocks();
          });
        } else {
          _applyUnitLocks();
        }
      });
    }
    _fetchHargaOtomatis();
  }

  void _onTipeChanged() {
    selectedJenisId.value = '';
    listJenisSampah.clear();

    if (selectedTipeId.value.isNotEmpty) {
      _applyUnitLocks();
      _fetchJenisByTipe(selectedTipeId.value).then((_) {
        _applyUnitLocks();
      });
    }
    _fetchHargaOtomatis();
  }

  void _onJenisChanged() {
    if (selectedJenisId.value.isNotEmpty) {
      final jenis = listJenisSampah.firstWhereOrNull(
        (j) => j.id == selectedJenisId.value,
      );
      if (jenis?.satuanDefaultId != null) {
        selectedSatuanId.value = jenis!.satuanDefaultId!;
      }
      _applyUnitLocks();
    }
    _fetchHargaOtomatis();
  }

  // ── Callback untuk dropdown view ────────────────────────────────────────────

  void onKategoriChanged(String? id) => selectedKategoriId.value = id ?? '';
  void onSubKategoriChanged(String? id) =>
      selectedSubKategoriId.value = id ?? '';
  void onTipeChanged(String? id) => selectedTipeId.value = id ?? ''; // ← BARU
  void onJenisChanged(String? id) => selectedJenisId.value = id ?? '';

  // ── Populate data saat edit ──────────────────────────────────────────────────

  Future<void> _populateEditData() async {
    final d = editData!;
    _isPopulating = true;

    selectedTanggal.value = d.tanggalPengelolaan;
    tanggalController.text = FormatHelper.date(d.tanggalPengelolaan);
    jumlahController.text = d.jumlah.toString();
    hargaPerSatuanController.text = d.hargaPerSatuan != null
        ? FormatHelper.number(d.hargaPerSatuan)
        : '';
    catatanController.text = d.catatan ?? '';
    selectedSatuanId.value = d.satuanId;
    nasabahController.text = d.namaNasabah ?? '';

    // Kategori
    if (d.kategoriId.isNotEmpty) {
      selectedKategoriId.value = d.kategoriId;
      await _fetchSubKategori(d.kategoriId);

      if (d.subKategoriId != null) {
        selectedSubKategoriId.value = d.subKategoriId!;
        await _fetchTipe(d.subKategoriId!);

        // Ada tipe?
        if (d.tipeId != null) {
          selectedTipeId.value = d.tipeId!;
          await _fetchJenisByTipe(d.tipeId!);
        } else if (listTipe.isEmpty) {
          // Tidak ada tipe → ambil jenis langsung dari sub_kategori
          await _fetchJenisBySubKategori(d.subKategoriId!);
        }
      } else if (listSubKategori.isEmpty) {
        // Tidak ada sub_kategori → ambil jenis langsung dari kategori
        await _fetchJenisByKategori(d.kategoriId);
      }

      if (d.jenisSampahId != null) {
        selectedJenisId.value = d.jenisSampahId!;
      }
    }

    _isPopulating = false;
    _fetchHargaOtomatis();
  }

  // ── Date picker ──────────────────────────────────────────────────────────────

  Future<void> pickTanggal(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedTanggal.value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      selectedTanggal.value = picked;
      tanggalController.text = FormatHelper.date(picked);
    }
  }

  void clearTanggal() {
    selectedTanggal.value = null;
    tanggalController.clear();
  }

  // ── Simpan ───────────────────────────────────────────────────────────────────

  Future<void> simpan() async {
    if (isScanBusy || isLoading.value) return;
    if (!formKey.currentState!.validate()) return;
    if (selectedKategoriId.value.isEmpty) {
      Get.snackbar('Validasi', 'Kategori wajib dipilih.');
      return;
    }
    // Sub kategori wajib jika ada pilihannya (An Organik)
    if (listSubKategori.isNotEmpty && selectedSubKategoriId.value.isEmpty) {
      Get.snackbar('Validasi', 'Sub Kategori wajib dipilih.');
      return;
    }
    // Tipe wajib jika ada pilihannya (Plastik)
    if (listTipe.isNotEmpty && selectedTipeId.value.isEmpty) {
      Get.snackbar('Validasi', 'Tipe wajib dipilih.');
      return;
    }
    // Jenis wajib jika ada pilihannya
    if (listJenisSampah.isNotEmpty && selectedJenisId.value.isEmpty) {
      Get.snackbar('Validasi', 'Jenis Sampah wajib dipilih.');
      return;
    }
    if (selectedSatuanId.value.isEmpty) {
      Get.snackbar('Validasi', 'Satuan wajib dipilih.');
      return;
    }
    if (selectedTanggal.value == null) {
      Get.snackbar('Validasi', 'Tanggal wajib diisi.');
      return;
    }

    final bankSampahId = SessionService.to.activeBankSampahId;
    final profileId = SessionService.to.profile.value?.id ?? '';

    if (bankSampahId.isEmpty) {
      Get.snackbar(
        'Validasi',
        'ID Bank Sampah tidak ditemukan. Silakan pilih bank sampah terlebih dahulu.',
      );
      return;
    }
    if (profileId.isEmpty) {
      Get.snackbar(
        'Validasi',
        'ID Profil tidak ditemukan. Silakan login ulang.',
      );
      return;
    }

    isLoading.value = true;
    try {
      final jumlah = double.parse(
        jumlahController.text.trim().replaceAll(',', '.'),
      );
      final totalHargaInput = double.tryParse(
        totalHargaController.text
            .trim()
            .replaceAll('.', '')
            .replaceAll(',', '.'),
      );
      final hargaPerSatuanInput = double.tryParse(
        hargaPerSatuanController.text
            .trim()
            .replaceAll('.', '')
            .replaceAll(',', '.'),
      );

      // Total dihitung bersama penyimpanan transaksi dalam SQLite.
      double hargaPerSatuan = 0.0;
      if (totalHargaInput != null && totalHargaInput > 0) {
        hargaPerSatuan = totalHargaInput / (jumlah > 0 ? jumlah : 1.0);
      } else if (hargaPerSatuanInput != null) {
        hargaPerSatuan = hargaPerSatuanInput;
      }

      final payload = {
        'bank_sampah_id': bankSampahId,
        'profile_id': profileId,
        'kategori_id': selectedKategoriId.value.trim(),
        'sub_kategori_id': selectedSubKategoriId.value.trim().isEmpty
            ? null
            : selectedSubKategoriId.value.trim(),
        'tipe_id': selectedTipeId.value.trim().isEmpty
            ? null
            : selectedTipeId.value.trim(),
        'jenis_sampah_id': selectedJenisId.value.trim().isEmpty
            ? null
            : selectedJenisId.value.trim(),
        'jumlah': jumlah,
        'satuan_id': selectedSatuanId.value.trim(),
        'harga_per_satuan': hargaPerSatuan,
        'tanggal_pengelolaan': FormatHelper.dateToInput(selectedTanggal.value!),
        'catatan': catatanController.text.trim().isEmpty
            ? null
            : catatanController.text.trim(),
        'nama_nasabah': nasabahController.text.trim().isEmpty
            ? null
            : nasabahController.text.trim(),
      };

      debugPrint('PAYLOAD PENYIMPANAN: $payload');

      await ScanRepository.instance.saveTransaction(
        payload: Map<String, Object?>.from(payload),
        existingId: editData?.id,
        scan: scanResult.value,
      );
      Get.snackbar(
        'Berhasil',
        isEditMode
            ? 'Data sampah berhasil diperbarui.'
            : 'Data sampah berhasil disimpan.',
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = Get.key.currentState;
        if (nav != null && nav.canPop()) {
          nav.pop(true);
        }
      });
    } catch (e) {
      debugPrint('ERROR SIMPAN SAMPAH: $e');
      Get.snackbar('Gagal', 'Data gagal disimpan: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _updateEstimasi() {
    rxJumlah.value =
        double.tryParse(jumlahController.text.trim().replaceAll(',', '.')) ??
        0.0;
    rxHargaPerSatuan.value =
        double.tryParse(
          hargaPerSatuanController.text
              .trim()
              .replaceAll('.', '')
              .replaceAll(',', '.'),
        ) ??
        0.0;
  }

  @override
  void onClose() {
    jumlahController.removeListener(_updateEstimasi);
    hargaPerSatuanController.removeListener(_updateEstimasi);
    jumlahController.dispose();
    hargaPerSatuanController.dispose();
    catatanController.dispose();
    tanggalController.dispose();
    totalHargaController.dispose();
    nasabahController.dispose();
    super.onClose();
  }
}
