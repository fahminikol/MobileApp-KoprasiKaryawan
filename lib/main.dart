import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/coop_service.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'widgets/auto_lock_wrapper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final coop = CoopService();
  final bool isAdminFlavor = appFlavor == 'admin' ||
      const String.fromEnvironment('FLUTTER_APP_FLAVOR') == 'admin';
  coop.setAdminPortalMode(isAdminFlavor);
  runApp(KopkarApp(coopService: coop));
}

class KopkarApp extends StatelessWidget {
  final CoopService coopService;

  const KopkarApp({super.key, required this.coopService});

  @override
  Widget build(BuildContext context) {
    final isAdmin = coopService.isAdminPortalOnly;
    return MaterialApp(
      title: isAdmin
          ? 'KOPKAR ADMIN — PT Budi Berlian Motor'
          : 'KOPKAR PT Budi Berlian Motor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return AutoLockWrapper(
          coopService: coopService,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: isAdmin
          ? LoginScreen(coopService: coopService)
          : OnboardingScreen(coopService: coopService),
    );
  }
}
