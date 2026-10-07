import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/services/local_errors.dart';

import '../core/services/local_data_service.dart';
import '../core/services/session_service.dart';
import '../core/constants/data_tables.dart';
import '../models/profile_model.dart';
import '../models/bank_sampah_model.dart';
import '../app/routes/app_routes.dart';
import '../core/utils/validator.dart';
import '../core/widgets/app_widgets.dart';
import '../app/themes/app_colors.dart';
import '../app/themes/app_text_styles.dart';
import '../app/themes/app_theme.dart';

class AuthController extends GetxController {
  // Form keys
  final loginFormKey = GlobalKey<FormState>();
  final registerFormKey = GlobalKey<FormState>();
  final forgotPasswordFormKey = GlobalKey<FormState>();

  // Text controllers — login
  final emailController =
      TextEditingController(text: 'pengurus@demo.local');

  final passwordController =
      TextEditingController(text: 'penelitian123');

  // Text controllers — register
  final regNamaController = TextEditingController();
  final regEmailController = TextEditingController();
  final regPasswordController = TextEditingController();
  final regConfirmPasswordController = TextEditingController();
  final regNoHpController = TextEditingController();

  // Text controllers — forgot password
  final forgotEmailController = TextEditingController();

  // State
  final isLoading = false.obs;
  final isLoadingBankSampah = false.obs;
  final isPasswordVisible = false.obs;
  final isConfirmPasswordVisible = false.obs;
  final isResetting = false.obs;

  // Daftar bank sampah untuk pilihan saat registrasi
  final listBankSampahRegister = <BankSampahModel>[].obs;
  final selectedBankSampahRegister = <String>[].obs;

  void togglePasswordVisibility() =>
      isPasswordVisible.value = !isPasswordVisible.value;

  void toggleConfirmPasswordVisibility() =>
      isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;

  // ─── Fetch bank sampah untuk form registrasi ─────────────────────────────────
  // Dipanggil saat halaman register dibuka (onInit RegisterView tidak ada,
  // jadi panggil dari initState atau didChangeDependencies via StatefulWidget,
  // atau bisa juga dipanggil langsung dari build pertama kali).
  Future<void> fetchBankSampahUntukRegister({bool force = false}) async {
    if (!force && listBankSampahRegister.isNotEmpty) return; // sudah dimuat
    isLoadingBankSampah.value = true;
    try {
      final data = await LocalDataService.client
          .from(DataTables.tableBankSampah)
          .select()
          .eq('is_active', true)
          .order('nama');
      listBankSampahRegister.value = (data as List)
          .map((e) => BankSampahModel.fromJson(e))
          .toList();
    } catch (_) {
      // Gagal muat bank sampah tidak fatal — user tetap bisa daftar
    } finally {
      isLoadingBankSampah.value = false;
    }
  }

  // ─── Login ──────────────────────────────────────────────────────────────────
  Future<void> login() async {
    if (!loginFormKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      final response = await LocalDataService.client.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (response.user == null) {
        _showError('Login gagal. Periksa email dan password kamu.');
        return;
      }

      await _loadProfileAndNavigate(response.user!.id);
    } on LocalAuthException catch (e) {
      _showError(_mapAuthError(e.message));
    } catch (e) {
      _showError('Gagal membuka akun lokal: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Register ────────────────────────────────────────────────────────────────
  Future<void> register() async {
    if (!registerFormKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      final response = await LocalDataService.client.auth.signUp(
        email: regEmailController.text.trim(),
        password: regPasswordController.text,
      );

      if (response.user == null) {
        _showError('Registrasi gagal. Coba lagi.');
        return;
      }

      final userId = response.user!.id;

      try {
        final inserted = await LocalDataService.client
            .from(DataTables.tableProfiles)
            .insert({
              'auth_user_id': userId,
              'nama_lengkap': regNamaController.text.trim(),
              'no_hp': regNoHpController.text.trim().isEmpty
                  ? null
                  : regNoHpController.text.trim(),
              'role': 'pengelola',
              'is_verified': false,
              // Simpan pilihan bank sampah sebagai referensi untuk kelurahan
              'bank_sampah_pilihan': selectedBankSampahRegister.toList(),
            })
            .select()
            .single();

        final profile = ProfileModel.fromJson(inserted);
        SessionService.to.setProfile(profile);
      } on LocalDataException catch (e) {
        await LocalDataService.client.auth.signOut();
        _showError('Gagal simpan profil: [${e.code}] ${e.message}');
        return;
      } catch (profileError) {
        await LocalDataService.client.auth.signOut();
        _showError('Gagal simpan profil: $profileError');
        return;
      }

      Get.offAllNamed(AppRoutes.menungguVerifikasi);
    } on LocalAuthException catch (e) {
      _showError(_mapAuthError(e.message));
    } catch (e) {
      _showError('Registrasi lokal gagal: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Logout ──────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    isLoading.value = true;
    try {
      await LocalDataService.client.auth.signOut();
      Get.offAllNamed(AppRoutes.login);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SessionService.to.clearSession();
      });
    } catch (e) {
      _showError('Gagal logout. Coba lagi.');
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Load profile & navigasi sesuai role & status verifikasi ─────────────────
  Future<void> _loadProfileAndNavigate(String authUserId) async {
    final data = await LocalDataService.client
        .from(DataTables.tableProfiles)
        .select()
        .eq('auth_user_id', authUserId)
        .single();

    final profile = ProfileModel.fromJson(data);
    SessionService.to.setProfile(profile);

    if (profile.isKelurahan) {
      Get.offAllNamed(AppRoutes.dashboardKelurahan);
    } else if (!profile.isVerified) {
      Get.offAllNamed(AppRoutes.menungguVerifikasi);
    } else {
      Get.offAllNamed(AppRoutes.pilihBankSampah);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────
  String _mapAuthError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Email atau password salah.';
    }
    if (message.contains('Email not confirmed')) {
      return 'Email belum dikonfirmasi. Periksa inbox kamu.';
    }
    if (message.contains('User already registered')) {
      return 'Email sudah terdaftar. Silakan login.';
    }
    return 'Terjadi kesalahan. Coba lagi.';
  }

  void _showError(String message) {
    Get.snackbar(
      'Gagal',
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }

  void goToRegister() => Get.toNamed(AppRoutes.register);
  void goToLogin() => Get.back();

  // ─── Forgot Password ────────────────────────────────────────────────────────
  Future<void> forgotPassword() async {
    forgotEmailController.clear();
    isResetting.value = false;

    Get.dialog(
      Dialog(
        backgroundColor: AppColors.surfaceLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: forgotPasswordFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Reset Password',
                    style: AppTextStyles.titleLg.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Masukkan alamat email terdaftar untuk menerima instruksi pengaturan ulang kata sandi.',
                    style: AppTextStyles.bodyMd,
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    controller: forgotEmailController,
                    label: 'Email',
                    hint: 'Masukkan email terdaftar',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: AppValidator.email,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          if (!isResetting.value) {
                            Get.back();
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.outline,
                        ),
                        child: const Text('Batal'),
                      ),
                      const SizedBox(width: 12),
                      Obx(
                        () => _GradientResetButton(
                          label: 'Kirim',
                          isLoading: isResetting.value,
                          onPressed: () async {
                            if (!forgotPasswordFormKey.currentState!.validate())
                              return;

                            isResetting.value = true;
                            try {
                              await LocalDataService.client.auth
                                  .resetPasswordForEmail(
                                    forgotEmailController.text.trim(),
                                  );
                              Get.back();
                              AppSnackbar.success(
                                'Email reset password telah dikirim. Periksa inbox kamu.',
                              );
                            } on LocalAuthException catch (e) {
                              AppSnackbar.error(
                                _mapResetPasswordError(e.message),
                              );
                            } catch (e) {
                              AppSnackbar.error(
                                'Terjadi kesalahan sistem. Silakan coba lagi.',
                              );
                            } finally {
                              isResetting.value = false;
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  String _mapResetPasswordError(String message) {
    if (message.toLowerCase().contains('user not found')) {
      return 'Email tidak terdaftar.';
    }
    if (message.toLowerCase().contains('too many requests') ||
        message.toLowerCase().contains('rate limit')) {
      return 'Terlalu banyak permintaan reset. Silakan coba beberapa saat lagi.';
    }
    if (message.toLowerCase().contains('invalid email')) {
      return 'Format email tidak valid.';
    }
    return message;
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    regNamaController.dispose();
    regEmailController.dispose();
    regPasswordController.dispose();
    regConfirmPasswordController.dispose();
    regNoHpController.dispose();
    forgotEmailController.dispose();
    super.onClose();
  }
}

class _GradientResetButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GradientResetButton({
    required this.label,
    required this.isLoading,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.secondary, AppColors.primary],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
          onPressed: isLoading ? null : onPressed,
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                )
              : Text(
                  label,
                  style: AppTextStyles.labelLg.copyWith(
                    color: AppColors.onPrimary,
                  ),
                ),
        ),
      ),
    );
  }
}
