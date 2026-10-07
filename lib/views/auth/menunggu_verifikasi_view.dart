import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/themes/app_colors.dart';
import '../../app/themes/app_text_styles.dart';
import '../../app/themes/app_theme.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/data_tables.dart';
import '../../core/services/session_service.dart';
import '../../core/services/local_data_service.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../models/profile_model.dart';

class MenungguVerifikasiView extends StatefulWidget {
  const MenungguVerifikasiView({super.key});

  @override
  State<MenungguVerifikasiView> createState() => _MenungguVerifikasiViewState();
}

class _MenungguVerifikasiViewState extends State<MenungguVerifikasiView> {
  bool _isChecking = false;

  Future<void> _cekStatus() async {
    final authUserId = SessionService.to.profile.value?.authUserId;
    if (authUserId == null) return;

    setState(() => _isChecking = true);
    try {
      final data = await LocalDataService.client
          .from(DataTables.tableProfiles)
          .select()
          .eq('auth_user_id', authUserId)
          .single();

      final profile = ProfileModel.fromJson(data);
      SessionService.to.setProfile(profile);

      if (profile.isVerified) {
        Get.offAllNamed(AppRoutes.pilihBankSampah);
      } else {
        Get.snackbar(
          'Belum Diverifikasi',
          'Akun kamu belum disetujui kelurahan. Silakan hubungi kelurahan setempat.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Gagal',
        'Gagal memeriksa status. Periksa koneksi internet kamu.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: PullToRefresh(
          onRefresh: _cekStatus,
          color: AppColors.primary,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.outlineVariant),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header hijau ──────────────────────────────────────
                    _buildHeader(),

                    // ── Body ─────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        children: [
                          _buildInfoBanner(),
                          const SizedBox(height: 16),
                          _buildStepList(),
                          const SizedBox(height: 16),
                          _buildTipBanner(),
                        ],
                      ),
                    ),

                    // ── Tombol ───────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        children: [
                          _buildCekStatusButton(),
                          const SizedBox(height: 10),
                          _buildLogoutButton(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header dengan lingkaran ikon ──────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Ikon berlapis
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
              ),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Label status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Text(
              'STATUS AKUN',
              style: AppTextStyles.labelSm.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                letterSpacing: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Menunggu Verifikasi',
            style: AppTextStyles.headlineMd.copyWith(color: Colors.white),
          ),

          const SizedBox(height: 4),

          Obx(() {
            final nama = SessionService.to.profile.value?.namaLengkap ?? '';
            return Text(
              'Halo, $nama 👋',
              style: AppTextStyles.bodyMd.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Info banner ───────────────────────────────────────────────────────────

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.successContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Akun kamu sudah terdaftar. Kelurahan perlu memverifikasi dan menghubungkan kamu ke bank sampah terlebih dahulu.',
              style: AppTextStyles.bodyMd,
            ),
          ),
        ],
      ),
    );
  }

  // ── Daftar langkah ────────────────────────────────────────────────────────

  Widget _buildStepList() {
    return Column(
      children: [
        _StepTile(
          icon: Icons.check_rounded,
          iconColor: AppColors.success,
          iconBg: AppColors.successContainer,
          title: 'Akun terdaftar',
          subtitle: 'Data berhasil disimpan',
          isDone: true,
        ),
        const SizedBox(height: 8),
        _StepTile(
          icon: Icons.loop_rounded,
          iconColor: AppColors.onPrimary,
          iconBg: AppColors.primary,
          title: 'Verifikasi kelurahan',
          subtitle: 'Sedang menunggu persetujuan',
          isActive: true,
        ),
        const SizedBox(height: 8),
        _StepTile(
          icon: Icons.storefront_rounded,
          iconColor: AppColors.outline,
          iconBg: AppColors.surfaceHigh,
          title: 'Akses bank sampah',
          subtitle: 'Belum tersedia',
          isDisabled: true,
        ),
      ],
    );
  }

  // ── Tips banner ───────────────────────────────────────────────────────────

  Widget _buildTipBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_outlined,
            size: 16,
            color: AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tekan "Cek Status" setelah kelurahan menyetujui akunmu.',
              style: AppTextStyles.labelSm,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tombol cek status ─────────────────────────────────────────────────────

  Widget _buildCekStatusButton() {
    return AppButton(
      label: 'Cek Status',
      onPressed: _cekStatus,
      isLoading: _isChecking,
      icon: Icons.refresh_rounded,
    );
  }

  // ── Tombol keluar ─────────────────────────────────────────────────────────

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () => Get.find<AuthController>().logout(),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Keluar'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurfaceVariant,
          side: const BorderSide(color: AppColors.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
      ),
    );
  }
}

// ─── Komponen: Tile langkah ───────────────────────────────────────────────────

class _StepTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final bool isDone;
  final bool isActive;
  final bool isDisabled;

  const _StepTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.isDone = false,
    this.isActive = false,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryContainer.withValues(alpha: 0.15)
              : AppColors.surfaceLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isActive ? AppColors.primaryContainer : AppColors.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.labelLg.copyWith(
                      color: isActive
                          ? AppColors.primary
                          : AppColors.onBackground,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.labelSm.copyWith(
                      color: isActive
                          ? AppColors.primaryContainer
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
