import 'package:flutter/material.dart';
import 'services/coop_service.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/auto_lock_wrapper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final coop = CoopService();
  coop.setAdminPortalMode(false);
  runApp(KopkarApp(coopService: coop));
}

class KopkarApp extends StatelessWidget {
  final CoopService coopService;

  const KopkarApp({super.key, required this.coopService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KOPKAR PT Budi Berlian Motor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return AutoLockWrapper(
          coopService: coopService,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const OnboardingScreen(),
    );
  }
}
