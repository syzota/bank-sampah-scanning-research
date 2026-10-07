import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/themes/app_theme.dart';
import 'core/constants/data_tables.dart';
import 'core/services/local_data_service.dart';
import 'core/services/session_service.dart';
import 'models/profile_model.dart';
import 'controllers/auth_controller.dart';
import 'app/themes/app_colors.dart';
import 'core/widgets/motion.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id_ID', null);

  try {
    await LocalDataService.initialize();
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Database penelitian gagal dibuka.\n$error'),
            ),
          ),
        ),
      ),
    );
    return;
  }

  await Get.putAsync(() async => SessionService());
  Get.put(AuthController(), permanent: true);

  // Restore the session stored in this installation's SQLite database.
  final existingUser = LocalDataService.client.auth.currentUser;
  String initialRoute = AppRoutes.login;

  if (existingUser != null) {
    try {
      final data = await LocalDataService.client
          .from(DataTables.tableProfiles)
          .select()
          .eq('auth_user_id', existingUser.id)
          .single();

      final profile = ProfileModel.fromJson(data);
      SessionService.to.setProfile(profile);

      if (profile.isKelurahan) {
        initialRoute = AppRoutes.dashboardKelurahan;
      } else if (!profile.isVerified) {
        initialRoute = AppRoutes.menungguVerifikasi;
      } else {
        // Pengelola: arahkan ke pilihBankSampah agar bisa pilih BSU aktif
        initialRoute = AppRoutes.pilihBankSampah;
      }
    } catch (_) {
      // Jika gagal restore profile, kembali ke login
      initialRoute = AppRoutes.login;
    }
  }

  runApp(BisaApp(initialRoute: initialRoute));
}

class BisaApp extends StatelessWidget {
  final String initialRoute;
  const BisaApp({super.key, required this.initialRoute});

  /// Observer navigasi global — menggerakkan progress line saat pindah page.
  static final RouteProgressObserver routeObserver = RouteProgressObserver();

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'BISA Penelitian SQLite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      initialRoute: initialRoute,
      getPages: AppPages.routes,
      navigatorObservers: [routeObserver],
      builder: (context, child) => ScrollConfiguration(
        behavior: const _SmoothScrollBehavior(),
        child: RouteProgressLine(
          observer: routeObserver,
          color: AppColors.primary,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Scroll physics halus ala iOS di semua platform + menghilangkan
/// glow scrollbar biru khas Material lama.
class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics();
      default:
        return const BouncingScrollPhysics(
          decelerationRate: ScrollDecelerationRate.fast,
        );
    }
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // tanpa glow
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
