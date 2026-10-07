import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/themes/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/services/session_service.dart';
import '../../core/utils/format_helper.dart';
import '../../core/services/local_data_service.dart';
import '../../core/constants/data_tables.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../models/bank_sampah_model.dart';
import '../../models/profile_model.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/bank_sampah_map.dart';
import '../../core/widgets/wave_painter.dart';

class ProfilBankSampahView extends StatelessWidget {
  const ProfilBankSampahView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionService.to;
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: PullToRefresh(
        onRefresh: () async {},
        color: AppColors.pengelolaMain,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ───────────────────────────────────────
            SliverToBoxAdapter(child: _buildHeader(context, canPop)),

            // ── Content — ditarik naik menimpa wave ─────────
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -26),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Column(
                    children: [
                      // Hero card bank sampah
                      Obx(() {
                        final bank = session.activeBankSampah.value;
                        if (bank == null) return const SizedBox.shrink();
                        return _buildBankHeroCard(context, bank);
                      }),
                      const SizedBox(height: 16),

                      // Profil pengelola
                      Obx(() {
                        final profil = session.profile.value;
                        if (profil == null) return const SizedBox.shrink();
                        return _buildPengelolaCard(profil);
                      }),
                      const SizedBox(height: 16),

                      // Menu navigasi
                      _buildMenuCard(),
                      const SizedBox(height: 24),

                      // Logout button
                      _buildLogoutButton(),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool canPop) {
    return Stack(
      children: [
        CustomPaint(
          size: Size(MediaQuery.of(context).size.width, 215),
          painter: WavePainter.green(waveScale: 0.90),
        ),
        Positioned(
          top: -15,
          right: -10,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ),
        Positioned(
          top: 30,
          right: 60,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
            child: Row(
              children: [
                if (canPop)
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: 38,
                      height: 38,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pill nama bank sampah — di atas judul
                      Obx(
                        () => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.mintAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  SessionService.to.activeBankSampahNama,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Profil Bank Sampah',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Informasi bank sampah & akun pengelola',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Bank Hero Card ────────────────────────────────────────────────────────

  Widget _buildBankHeroCard(BuildContext context, BankSampahModel bank) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.pengelolaDark, AppColors.pengelolaMain],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.pengelolaMain.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bank.nama,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (bank.rt != null || bank.rw != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (bank.rt != null) 'RT ${bank.rt}',
                          if (bank.rw != null) 'RW ${bank.rw}',
                        ].join(' / '),
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Status badge dengan dot
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.mintAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Aktif',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),

          // Alamat
          if (bank.alamat != null) ...[
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: Colors.white.withValues(alpha: 0.75),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bank.alamat!,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Bergabung sejak
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                color: Colors.white.withValues(alpha: 0.55),
                size: 14,
              ),
              const SizedBox(width: 8),
              Text(
                'Bergabung ${FormatHelper.date(bank.createdAt)}',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),

          // ── Aksi lokasi ─────────────────────────────────
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PressableScale(
                  onTap: () => _bukaPetaLokasi(context, bank),
                  pressedScale: 0.96,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.map_rounded,
                          size: 17,
                          color: AppColors.pengelolaDark,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          bank.punyaLokasi ? 'Lihat Lokasi' : 'Setel Lokasi',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.pengelolaDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (bank.punyaLokasi) ...[
                const SizedBox(width: 10),
                PressableScale(
                  onTap: () => bukaPetunjukArah(
                    lat: bank.latitude!,
                    lng: bank.longitude!,
                    label: bank.nama,
                  ),
                  pressedScale: 0.92,
                  glowIntensity: 0.4,
                  glowColor: Colors.white,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.navigation_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Buka sheet lokasi bank sampah sendiri — dengan opsi setel/ubah pin.
  Future<void> _bukaPetaLokasi(
    BuildContext context,
    BankSampahModel bank,
  ) async {
    HapticFeedback.lightImpact();
    final setelUlang = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.pengelolaDark, AppColors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.map_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bank.punyaLokasi
                              ? 'Lokasi Tersimpan'
                              : 'Lokasi Belum Disetel',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.kelurahanDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          koordinatText(bank.latitude, bank.longitude),
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: PressableScale(
                  onTap: () => Navigator.of(ctx).pop(true),
                  pressedScale: 0.97,
                  glowIntensity: 0.4,
                  glowColor: AppColors.primary,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.secondary, AppColors.pengelolaDark],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      bank.punyaLokasi ? 'Ubah Pin Lokasi' : 'Setel Pin Lokasi',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              if (bank.punyaLokasi) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: PressableScale(
                    onTap: () {
                      Navigator.of(ctx).pop(false);
                      bukaPetunjukArah(
                        lat: bank.latitude!,
                        lng: bank.longitude!,
                        label: bank.nama,
                      );
                    },
                    pressedScale: 0.97,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.pengelolaLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Petunjuk Arah',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.pengelolaDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (setelUlang != true) return;
    if (!context.mounted) return;

    // Picker pin → simpan langsung ke Supabase + session
    final picked = await showMapPicker(
      context,
      initial: bank.punyaLokasi
          ? ll.LatLng(bank.latitude!, bank.longitude!)
          : null,
      title: 'Lokasi Bank Sampah',
    );
    if (picked == null || !context.mounted) return;

    try {
      await LocalDataService.client
          .from(DataTables.tableBankSampah)
          .update({'latitude': picked.latitude, 'longitude': picked.longitude})
          .eq('id', bank.id);
      SessionService.to.setActiveBankSampah(
        bank.copyWith(latitude: picked.latitude, longitude: picked.longitude),
      );
      if (context.mounted) {
        Get.snackbar(
          'Berhasil',
          'Lokasi bank sampah tersimpan',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success,
          colorText: Colors.white,
        );
      }
    } catch (_) {
      if (context.mounted) {
        Get.snackbar(
          'Gagal',
          'Tidak bisa menyimpan lokasi, coba lagi',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.danger,
          colorText: Colors.white,
        );
      }
    }
  }

  // ── Pengelola Card ────────────────────────────────────────────────────────

  Widget _buildPengelolaCard(ProfileModel profil) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: const Border(
          top: BorderSide(color: AppColors.pengelolaMain, width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.pengelolaMain.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.pengelolaLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.pengelolaMain,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Data Pengelola',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: Colors.grey.shade100),
          const SizedBox(height: 14),

          _InfoRow(
            icon: Icons.assignment_ind_outlined,
            label: 'Nama Lengkap',
            value: profil.namaLengkap,
            accent: AppColors.pengelolaMain,
            accentBg: AppColors.pengelolaLight,
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.email_outlined,
            label: 'Email Terdaftar',
            value: LocalDataService.currentUser?.email ?? '-',
            accent: AppColors.blueDeep,
            accentBg: AppColors.kelurahanLight,
          ),
          if (profil.noHp != null && profil.noHp!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _InfoRow(
              icon: Icons.phone_android_outlined,
              label: 'Nomor WhatsApp',
              value: profil.noHp!,
              accent: AppColors.orange,
              accentBg: AppColors.orangeContainer,
            ),
          ],
        ],
      ),
    );
  }

  // ── Menu Card ─────────────────────────────────────────────────────────────

  Widget _buildMenuCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _MenuTile(
            icon: Icons.history_rounded,
            iconBg: AppColors.kelurahanLight,
            iconColor: AppColors.blueDeep,
            label: 'Histori Pengelolaan',
            sublabel: 'Lihat data riwayat timbangan sampah',
            onTap: () => Get.toNamed(AppRoutes.historiSampah),
            isFirst: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: Colors.grey.shade100),
          ),
          _MenuTile(
            icon: Icons.swap_horiz_rounded,
            iconBg: AppColors.orangeContainer,
            iconColor: AppColors.orange,
            label: 'Ganti Bank Sampah',
            sublabel: 'Beralih ke kelola bank sampah lain',
            onTap: () => Get.toNamed(AppRoutes.pilihBankSampah),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: Colors.grey.shade100),
          ),
          _MenuTile(
            icon: Icons.people_outline_rounded,
            iconBg: AppColors.pengelolaLight,
            iconColor: AppColors.pengelolaMain,
            label: 'Kelola Nasabah',
            sublabel: 'Daftar & kelola nasabah BSU ini saja',
            onTap: () => Get.toNamed(AppRoutes.manajemenNasabah),
            isLast: true,
          ),
        ],
      ),
    );
  }

  // ── Logout Button ─────────────────────────────────────────────────────────

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () => Get.find<AuthController>().logout(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.dangerLighter, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFC62828), size: 20),
            SizedBox(width: 8),
            Text(
              'Keluar dari Akun',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFFC62828),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info Row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color accentBg;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.accentBg,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accentBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Menu Tile ─────────────────────────────────────────────────────────────────

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String sublabel;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  const _MenuTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.sublabel,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.only(top: isFirst ? 6 : 0, bottom: isLast ? 6 : 0),
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Text(
            label,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            sublabel,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
          trailing: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.pengelolaMain,
              size: 20,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
        ),
      ),
    );
  }
}

// ── Wave Painter ──────────────────────────────────────────────────────────────
