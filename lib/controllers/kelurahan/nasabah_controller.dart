import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/local_data_service.dart';
import '../../core/constants/data_tables.dart';
import '../../core/services/session_service.dart';
import '../../models/nasabah_model.dart';
import '../../models/bank_sampah_model.dart';

class NasabahController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final namaController = TextEditingController();
  final searchController = TextEditingController();

  final listNasabah = <NasabahModel>[].obs;
  final listBankSampah = <BankSampahModel>[].obs;
  final searchQuery = ''.obs;

  final isLoading = false.obs;
  final isSaving = false.obs;

  final editData = Rx<NasabahModel?>(null);
  bool get isEditMode => editData.value != null;

  // Filtered nasabah list based on search query
  List<NasabahModel> get listNasabahFiltered {
    if (searchQuery.value.isEmpty) return listNasabah;
    final q = searchQuery.value.toLowerCase();
    return listNasabah.where((n) {
      return n.nama.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    fetchData();
  }

  Future<void> fetchData() async {
    isLoading.value = true;
    try {
      await fetchNasabah();
    } catch (e) {
      debugPrint('Error fetching nasabah data: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void onSearch(String value) {
    searchQuery.value = value;
  }

  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
  }

  Future<void> fetchNasabah() async {
    try {
      // Query unique customer names dynamically from pengelolaan_sampah transactions
      var query = LocalDataService.client
          .from(DataTables.tablePengelolaanSampah)
          .select('nama_nasabah');
      
      // If logged in as BSU operator (pengelola), restrict to their BSU only
      if (SessionService.to.isPengelola) {
        query = query.eq('bank_sampah_id', SessionService.to.activeBankSampahId);
      }
      
      final response = await query;
      final list = response as List;
      
      final Set<String> uniqueNames = {};
      for (var item in list) {
        final name = item['nama_nasabah'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          uniqueNames.add(name.trim());
        }
      }
      
      final loadedNasabah = uniqueNames
          .map((name) => NasabahModel(
                id: name,
                nama: name,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ))
          .toList();
      
      // Sort alphabetically
      loadedNasabah.sort((a, b) => a.nama.compareTo(b.nama));
      listNasabah.value = loadedNasabah;
    } catch (e) {
      debugPrint('Error fetching nasabah list: $e');
      Get.snackbar('Error', 'Gagal memuat daftar nasabah.');
    }
  }

  void initEdit(NasabahModel data) {
    editData.value = data;
    _populateForm();
  }

  void _populateForm() {
    namaController.text = editData.value!.nama;
  }

  void resetForm() {
    editData.value = null;
    formKey.currentState?.reset();
    namaController.clear();
  }

  Future<bool> simpan() async {
    if (!formKey.currentState!.validate()) return false;

    isSaving.value = true;
    try {
      if (isEditMode) {
        final oldName = editData.value!.nama;
        final newName = namaController.text.trim();

        if (oldName == newName) {
          resetForm();
          return true;
        }

        // Update the customer name across all transactions in pengelolaan_sampah
        var query = LocalDataService.client
            .from(DataTables.tablePengelolaanSampah)
            .update({'nama_nasabah': newName})
            .eq('nama_nasabah', oldName);

        if (SessionService.to.isPengelola) {
          query = query.eq('bank_sampah_id', SessionService.to.activeBankSampahId);
        }

        await query;
        Get.snackbar('Berhasil', 'Nama nasabah berhasil diperbarui di semua transaksi.');
      }
      
      resetForm();
      await fetchNasabah();
      return true;
    } catch (e) {
      debugPrint('Error saving nasabah: $e');
      Get.snackbar('Gagal', 'Gagal memperbarui nama nasabah.');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> deleteNasabah(String nama) async {
    isLoading.value = true;
    try {
      // Set nama_nasabah to null in all matching transactions
      var query = LocalDataService.client
          .from(DataTables.tablePengelolaanSampah)
          .update({'nama_nasabah': null})
          .eq('nama_nasabah', nama);

      if (SessionService.to.isPengelola) {
        query = query.eq('bank_sampah_id', SessionService.to.activeBankSampahId);
      }

      await query;
      Get.snackbar('Berhasil', 'Nasabah berhasil dihapus dari transaksi.');
      await fetchNasabah();
    } catch (e) {
      debugPrint('Error deleting nasabah: $e');
      Get.snackbar('Gagal', 'Gagal menghapus nasabah.');
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    namaController.dispose();
    searchController.dispose();
    super.onClose();
  }
}
