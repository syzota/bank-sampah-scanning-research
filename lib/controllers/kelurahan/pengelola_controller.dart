import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/local_data_service.dart';
import '../../core/constants/data_tables.dart';
import '../../models/profile_model.dart';
import '../../models/bank_sampah_model.dart';
import '../../app/routes/app_routes.dart';

class PengelolaController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final namaController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final noHpController = TextEditingController();

  // Pengelola aktif (sudah verified)
  final listPengelola = <ProfileModel>[].obs;
  // Pengelola pending (belum verified, daftar mandiri)
  final listPending = <ProfileModel>[].obs;

  final listBankSampah = <BankSampahModel>[].obs;
  final selectedBankSampahIds = <String>[].obs;

  final isLoading = false.obs;
  final isSaving = false.obs;
  final isApprovingId = ''.obs;
  final isPasswordVisible = false.obs;

  // ── Pencarian & relasi ────────────────────────────────────────────────
  final searchQuery = ''.obs;

  void setSearchQuery(String v) => searchQuery.value = v;

  /// Pengelola aktif setelah difilter pencarian (nama / no HP / BSU).
  List<ProfileModel> get listPengelolaFiltered {
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isEmpty) return listPengelola;
    return listPengelola.where((p) {
      final nama = p.namaLengkap.toLowerCase();
      final hp = (p.noHp ?? '').toLowerCase();
      final bsu = relasiPengelola
          .where((r) => r['profile_id'] == p.id)
          .map((r) => (r['nama'] as String?) ?? '')
          .join(' ')
          .toLowerCase();
      return nama.contains(q) || hp.contains(q) || bsu.contains(q);
    }).toList();
  }

  /// Map relasi pengelola → bank sampah: {profile_id, nama, rw, rt}.
  final relasiPengelola = <Map<String, dynamic>>[].obs;

  /// Map tonase total (kg) per profile_id pengelola (dari transaksi BSU yang dikelola).
  final tonasePerPengelola = <String, double>{}.obs;

  /// Nama BSU yang dikelola seorang pengelola, digabung "BSU A (RW 02), BSU B".
  String namaBsuPengelola(String profileId) {
    final rows = relasiPengelola
        .where((r) => r['profile_id'] == profileId)
        .toList();
    if (rows.isEmpty) return '';
    return rows
        .map((r) {
          final nama = (r['nama'] as String?) ?? '-';
          final rw = (r['rw'] as String?) ?? '';
          return rw.isNotEmpty ? '$nama (RW $rw)' : nama;
        })
        .join(', ');
  }

  /// Total ton yang diinput pengelola (kg → ton, 1 desimal).
  String tonaseLabel(String profileId) {
    final kg = tonasePerPengelola[profileId] ?? 0.0;
    final ton = kg / 1000.0;
    return '${ton.toStringAsFixed(ton < 10 ? 1 : 0)} Ton';
  }

  // ── State untuk sheet approve ────────────────────────────────────────────────
  // Menyimpan pilihan bank sampah sementara saat sheet approve dibuka.
  // Dipakai oleh sheet agar Obx bisa reaktif dengan benar.
  final approveSelectedIds = <String>[].obs;

  void togglePassword() => isPasswordVisible.value = !isPasswordVisible.value;

  void resetForm() {
    formKey.currentState?.reset();
    namaController.clear();
    emailController.clear();
    passwordController.clear();
    noHpController.clear();
    selectedBankSampahIds.clear();
  }

  /// Siapkan state pilihan bank sampah untuk sheet approve.
  /// Harus dipanggil sebelum membuka sheet approve.
  void initApproveSheet(ProfileModel pengelola) {
    // Pre-select pilihan bank sampah dari registrasi
    approveSelectedIds.value = List<String>.from(pengelola.bankSampahPilihan);
  }

  void toggleApproveBank(String bankId, bool selected) {
    if (selected) {
      if (!approveSelectedIds.contains(bankId)) {
        approveSelectedIds.add(bankId);
      }
    } else {
      approveSelectedIds.remove(bankId);
    }
  }

  @override
  void onInit() {
    super.onInit();
    fetchAll();
  }

  Future<void> fetchAll() async {
    isLoading.value = true;
    try {
      await Future.wait([
        _fetchPengelola(),
        _fetchBankSampah(),
        _fetchRelasi(),
        _fetchTonase(),
      ]);
    } finally {
      isLoading.value = false;
    }
  }

  /// Ambil relasi profile ↔ bank_sampah (dengan nama BSU) untuk semua pengelola.
  Future<void> _fetchRelasi() async {
    try {
      final data = await LocalDataService.client
          .from(DataTables.tablePengelolaBankSampah)
          .select('profile_id, bank_sampah_id, bank_sampah(nama, rw, rt)');
      relasiPengelola.value = (data as List)
          .map(
            (e) => {
              'profile_id': e['profile_id'],
              'bank_sampah_id': e['bank_sampah_id'],
              'nama': ((e['bank_sampah'] as Map?)?['nama'] as String?) ?? '-',
              'rw': ((e['bank_sampah'] as Map?)?['rw'] as String?) ?? '',
              'rt': ((e['bank_sampah'] as Map?)?['rt'] as String?) ?? '',
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Pengelola relasi warning: $e');
    }
  }

  /// Total tonase (kg) per pengelola: gabungkan transaksi dari semua BSU yang dia kelola.
  Future<void> _fetchTonase() async {
    try {
      if (relasiPengelola.isEmpty) return;
      final bsuIds = relasiPengelola
          .map((r) => r['bank_sampah_id'])
          .whereType<String>()
          .toSet();
      if (bsuIds.isEmpty) return;

      final data = await LocalDataService.client
          .from(DataTables.tablePengelolaanSampah)
          .select('bank_sampah_id, jumlah, satuan(singkatan)')
          .inFilter('bank_sampah_id', bsuIds.toList());

      final kgPerBsu = <String, double>{};
      for (final row in (data as List)) {
        final singkatan =
            ((row['satuan'] as Map?)?['singkatan'] as String?)?.toLowerCase() ??
            '';
        if (singkatan != 'kg') continue;
        final jml = row['jumlah'];
        final kg = jml is num ? jml.toDouble() : double.tryParse('$jml') ?? 0.0;
        final bsuId = row['bank_sampah_id'] as String?;
        if (bsuId == null) continue;
        kgPerBsu[bsuId] = (kgPerBsu[bsuId] ?? 0.0) + kg;
      }

      final tonase = <String, double>{};
      for (final r in relasiPengelola) {
        final bsuId = r['bank_sampah_id'];
        final kg = kgPerBsu[bsuId] ?? 0.0;
        final pid = r['profile_id'] as String;
        tonase[pid] = (tonase[pid] ?? 0.0) + kg;
      }
      tonasePerPengelola.value = tonase;
    } catch (e) {
      debugPrint('Pengelola tonase warning: $e');
    }
  }

  Future<void> _fetchPengelola() async {
    final data = await LocalDataService.client
        .from(DataTables.tableProfiles)
        .select()
        .eq('role', 'pengelola')
        .order('nama_lengkap');

    final semua = (data as List).map((e) => ProfileModel.fromJson(e)).toList();
    listPengelola.value = semua.where((p) => p.isVerified).toList();
    listPending.value = semua.where((p) => !p.isVerified).toList();
  }

  Future<void> _fetchBankSampah() async {
    final data = await LocalDataService.client
        .from(DataTables.tableBankSampah)
        .select()
        .eq('is_active', true)
        .order('nama');
    listBankSampah.value = (data as List)
        .map((e) => BankSampahModel.fromJson(e))
        .toList();
  }

  Future<List<String>> getBankSampahPengelola(String profileId) async {
    final data = await LocalDataService.client
        .from(DataTables.tablePengelolaBankSampah)
        .select('profile_id, bank_sampah_id')
        .eq('profile_id', profileId);
    return (data as List).map((e) => e['bank_sampah_id'] as String).toList();
  }

  void goToForm() => Get.toNamed(AppRoutes.formPengelola);

  // ─── Approve pengelola yang daftar mandiri ────────────────────────────────────
  Future<void> approvePengelola(
    String profileId,
    List<String> bankSampahIds,
  ) async {
    if (bankSampahIds.isEmpty) {
      Get.snackbar(
        'Pilih Bank Sampah',
        'Pilih minimal satu bank sampah sebelum menyetujui.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isApprovingId.value = profileId;
    try {
      // 1. Hapus relasi lama (jika ada)
      await LocalDataService.client
          .from(DataTables.tablePengelolaBankSampah)
          .delete()
          .eq('profile_id', profileId);

      // 2. Insert relasi baru
      final relasi = bankSampahIds
          .map((bsId) => {'profile_id': profileId, 'bank_sampah_id': bsId})
          .toList();
      await LocalDataService.client
          .from(DataTables.tablePengelolaBankSampah)
          .insert(relasi);

      // 3. Set verified + kosongkan bank_sampah_pilihan
      await LocalDataService.client
          .from(DataTables.tableProfiles)
          .update({'is_verified': true, 'bank_sampah_pilihan': []})
          .eq('id', profileId);

      // 4. Update list lokal
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _fetchPengelola();
      });

      Get.snackbar('Berhasil', 'Pengelola berhasil disetujui.');
    } catch (e) {
      Get.snackbar('Gagal', 'Gagal menyetujui pengelola: ${e.toString()}');
    } finally {
      isApprovingId.value = '';
    }
  }

  // ─── Tolak / hapus pengelola pending ─────────────────────────────────────────
  Future<void> tolakPengelola(String profileId) async {
    isApprovingId.value = profileId;
    try {
      final profileData = await LocalDataService.client
          .from(DataTables.tableProfiles)
          .select('auth_user_id')
          .eq('id', profileId)
          .single();

      final authUserId = profileData['auth_user_id'] as String;

      bool deletedViaFunction = false;
      try {
        final response = await LocalDataService.client.functions.invoke(
          'delete-pengelola',
          body: {'auth_user_id': authUserId, 'profile_id': profileId},
        );

        if (response.status == 200) {
          deletedViaFunction = true;
        } else {
          final errorMsg = response.data['error'] ?? response.data['message'];
          debugPrint(
            'Edge Function tolak gagal: ${errorMsg ?? response.status}',
          );
        }
      } catch (e) {
        debugPrint('Edge Function tolak error: $e');
      }

      // Fallback: Coba hapus via PostgreSQL RPC jika Edge Function gagal/tidak aktif
      if (!deletedViaFunction) {
        try {
          final rpcResponse = await LocalDataService.client.rpc(
            'delete_pengelola_account',
            params: {'p_auth_user_id': authUserId, 'p_profile_id': profileId},
          );
          if (rpcResponse != null &&
              rpcResponse is Map &&
              rpcResponse['status'] == 'success') {
            deletedViaFunction = true;
          }
        } catch (rpcErr) {
          debugPrint('RPC delete-pengelola error: $rpcErr');
        }
      }

      // Fallback 2: Hapus langsung dari database public schema saja jika RPC & Edge Function gagal
      if (!deletedViaFunction) {
        // Hapus relasi jika ada (opsional tapi aman)
        await LocalDataService.client
            .from(DataTables.tablePengelolaBankSampah)
            .delete()
            .eq('profile_id', profileId);

        // Hapus profile
        await LocalDataService.client
            .from(DataTables.tableProfiles)
            .delete()
            .eq('id', profileId);
      }

      listPending.removeWhere((e) => e.id == profileId);
      Get.snackbar(
        'Ditolak',
        deletedViaFunction
            ? 'Pendaftaran pengelola telah ditolak.'
            : 'Pendaftaran ditolak (dibersihkan via database).',
      );
    } catch (e) {
      Get.snackbar('Gagal', 'Gagal menolak pendaftaran: ${e.toString()}');
    } finally {
      isApprovingId.value = '';
    }
  }

  // ─── Tambah pengelola oleh kelurahan ─────────────────────────────────────────
  Future<void> tambahPengelola() async {
    if (!formKey.currentState!.validate()) return;

    isSaving.value = true;
    try {
      bool createdViaFunction = false;
      try {
        final response = await LocalDataService.client.functions.invoke(
          'create-pengelola',
          body: {
            'email': emailController.text.trim(),
            'password': passwordController.text,
            'nama_lengkap': namaController.text.trim(),
            'no_hp': noHpController.text.trim().isEmpty
                ? null
                : noHpController.text.trim(),
            'bank_sampah_ids': selectedBankSampahIds.toList(),
          },
        );

        if (response.status == 200) {
          createdViaFunction = true;
        } else {
          final errorMsg = response.data['error'] ?? response.data['message'];
          debugPrint(
            'Edge Function tambah gagal: ${errorMsg ?? response.status}',
          );
        }
      } catch (e) {
        debugPrint('Edge Function tambah error: $e');
      }

      // Fallback: Panggil PostgreSQL RPC jika Edge Function tidak dapat dijangkau
      if (!createdViaFunction) {
        debugPrint('Mencoba membuat akun pengelola via RPC...');
        final rpcResponse = await LocalDataService.client.rpc(
          'create_pengelola_account',
          params: {
            'p_email': emailController.text.trim(),
            'p_password': passwordController.text,
            'p_nama_lengkap': namaController.text.trim(),
            'p_no_hp': noHpController.text.trim().isEmpty
                ? null
                : noHpController.text.trim(),
            'p_bank_sampah_ids': selectedBankSampahIds.toList(),
          },
        );

        if (rpcResponse != null && rpcResponse is Map) {
          if (rpcResponse['status'] == 'success') {
            createdViaFunction = true;
          } else {
            throw Exception(
              rpcResponse['message'] ?? 'Gagal membuat akun via RPC',
            );
          }
        } else {
          throw Exception('Gagal membuat akun via RPC: respon tidak valid');
        }
      }

      await _fetchPengelola();
      Get.back();
      Get.snackbar('Berhasil', 'Akun pengelola berhasil dibuat.');
    } catch (e) {
      Get.snackbar('Gagal', 'Gagal membuat akun pengelola: ${e.toString()}');
    } finally {
      isSaving.value = false;
    }
  }

  // ─── Update relasi bank sampah pengelola aktif ────────────────────────────────
  Future<void> updateRelasiPengelola(
    String profileId,
    List<String> bankSampahIds,
  ) async {
    isSaving.value = true;
    try {
      await LocalDataService.client
          .from(DataTables.tablePengelolaBankSampah)
          .delete()
          .eq('profile_id', profileId);

      if (bankSampahIds.isNotEmpty) {
        final relasi = bankSampahIds
            .map((bsId) => {'profile_id': profileId, 'bank_sampah_id': bsId})
            .toList();
        await LocalDataService.client
            .from(DataTables.tablePengelolaBankSampah)
            .insert(relasi);

        await LocalDataService.client
            .from(DataTables.tableProfiles)
            .update({'is_verified': true})
            .eq('id', profileId);
      } else {
        await LocalDataService.client
            .from(DataTables.tableProfiles)
            .update({'is_verified': false})
            .eq('id', profileId);
      }

      await _fetchPengelola();
      Get.snackbar('Berhasil', 'Relasi bank sampah diperbarui.');
    } catch (e) {
      Get.snackbar('Gagal', 'Gagal memperbarui relasi: ${e.toString()}');
    } finally {
      isSaving.value = false;
    }
  }

  // ─── Hapus pengelola ──────────────────────────────────────────────────────────
  Future<void> hapusPengelola(String profileId) async {
    try {
      final profileData = await LocalDataService.client
          .from(DataTables.tableProfiles)
          .select('auth_user_id')
          .eq('id', profileId)
          .single();

      final authUserId = profileData['auth_user_id'] as String;

      bool deletedViaFunction = false;
      try {
        final response = await LocalDataService.client.functions.invoke(
          'delete-pengelola',
          body: {'auth_user_id': authUserId, 'profile_id': profileId},
        );

        if (response.status == 200) {
          deletedViaFunction = true;
        } else {
          final errorMsg = response.data['error'] ?? response.data['message'];
          debugPrint(
            'Edge Function hapus gagal: ${errorMsg ?? response.status}',
          );
        }
      } catch (e) {
        debugPrint('Edge Function hapus error: $e');
      }

      // Fallback: Coba hapus via PostgreSQL RPC jika Edge Function gagal/tidak aktif
      if (!deletedViaFunction) {
        try {
          final rpcResponse = await LocalDataService.client.rpc(
            'delete_pengelola_account',
            params: {'p_auth_user_id': authUserId, 'p_profile_id': profileId},
          );
          if (rpcResponse != null &&
              rpcResponse is Map &&
              rpcResponse['status'] == 'success') {
            deletedViaFunction = true;
          }
        } catch (rpcErr) {
          debugPrint('RPC delete-pengelola error: $rpcErr');
        }
      }

      // Fallback 2: Hapus langsung dari database public schema saja jika RPC & Edge Function gagal
      if (!deletedViaFunction) {
        // Hapus relasi di pengelola_bank_sampah
        await LocalDataService.client
            .from(DataTables.tablePengelolaBankSampah)
            .delete()
            .eq('profile_id', profileId);

        // Hapus profile
        await LocalDataService.client
            .from(DataTables.tableProfiles)
            .delete()
            .eq('id', profileId);
      }

      listPengelola.removeWhere((e) => e.id == profileId);
      Get.snackbar(
        'Berhasil',
        deletedViaFunction
            ? 'Pengelola berhasil dihapus.'
            : 'Pengelola dihapus (dibersihkan via database).',
      );
    } catch (e) {
      Get.snackbar('Gagal', 'Pengelola gagal dihapus: ${e.toString()}');
    }
  }

  @override
  void onClose() {
    namaController.dispose();
    emailController.dispose();
    passwordController.dispose();
    noHpController.dispose();
    super.onClose();
  }
}
