import 'package:flutter/material.dart';
import 'services/coop_service.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'widgets/auto_lock_wrapper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final coopService = CoopService();
  coopService.setAdminPortalMode(true);
  runApp(KopkarAdminApp(coopService: coopService));
}

class KopkarAdminApp extends StatelessWidget {
  final CoopService coopService;

  const KopkarAdminApp({
    super.key,
    required this.coopService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KOPKAR Admin Portal - PT Budi Berlian Motor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return AutoLockWrapper(
          coopService: coopService,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: LoginScreen(coopService: coopService),
    );
  }
}
