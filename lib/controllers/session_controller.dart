import 'package:get/get.dart';

import '../core/services/local_data_service.dart';
import '../core/services/session_service.dart';
import '../core/constants/data_tables.dart';
import '../models/bank_sampah_model.dart';
import '../app/routes/app_routes.dart';

class SessionController extends GetxController {
  final listBankSampah = <BankSampahModel>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchBankSampahSaya();
  }

  Future<void> fetchBankSampahSaya() async {
    isLoading.value = true;
    try {
      final profileId = SessionService.to.profile.value?.id;
      if (profileId == null) return;

      // Ambil bank sampah yang terhubung dengan pengelola ini
      final data = await LocalDataService.client
          .from(DataTables.tablePengelolaBankSampah)
          .select('bank_sampah_id, bank_sampah(*)')
          .eq('profile_id', profileId);

      listBankSampah.value = (data as List)
          .map(
            (e) => BankSampahModel.fromJson(
              e['bank_sampah'] as Map<String, dynamic>,
            ),
          )
          .where((b) => b.isActive)
          .toList();
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat daftar bank sampah.');
    } finally {
      isLoading.value = false;
    }
  }

  void pilihBankSampah(BankSampahModel bankSampah) {
    SessionService.to.setActiveBankSampah(bankSampah);
    Get.offAllNamed(AppRoutes.dashboardPengelola);
  }
}
