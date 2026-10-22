import 'package:flutter/material.dart';
import '../services/coop_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import 'user_dashboard_screen.dart';
import 'savings_detail_screen.dart';
import 'loan_screen.dart';
import 'resignation_screen.dart';
import 'admin_dashboard_screen.dart';
import 'user_management_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final CoopService _coopService = CoopService();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  /// Wajib verifikasi Email & Password Admin jika karyawan biasa menekan ikon Admin (#1)
  void _handleOpenAdmin(BuildContext context) {
    if (_coopService.isAdminMode && _coopService.currentAdmin != null) {
      setState(() {
        _currentIndex = 4;
      });
      return;
    }

    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primaryBlue),
                SizedBox(width: 8),
                Text(
                  'Otorisasi Pengurus (Admin HRD)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Halaman ini khusus Pengurus Koperasi / HRD. Masukkan Email & Password Admin untuk melanjutkan.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Admin',
                prefixIcon: const Icon(Icons.email_outlined, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password Admin',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  final ok = _coopService.loginAsAdmin(
                    emailCtrl.text,
                    passCtrl.text,
                  );
                  if (ok) {
                    Navigator.pop(ctx);
                    setState(() {
                      _currentIndex = 4;
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _coopService.lastLoginError ??
                              '❌ Email atau Password Admin salah!',
                        ),
                        backgroundColor: AppTheme.dangerRed,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Verifikasi & Buka Panel Admin',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _coopService,
      builder: (context, _) {
        // 1. MODE APLIKASI / WEB KHUSUS ADMIN HRD & PENGURUS (Murni Tanpa Menu Pribadi Karyawan)
        if (_coopService.isAdminPortalOnly) {
          final adminPages = [
            AdminDashboardScreen(coopService: _coopService),
            UserManagementScreen(coopService: _coopService),
          ];
          final safeAdminIndex = _currentIndex.clamp(0, adminPages.length - 1);

          return Scaffold(
            backgroundColor: AppTheme.scaffoldBackground,
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: IndexedStack(
                  index: safeAdminIndex,
                  children: adminPages,
                ),
              ),
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Center(
                  heightFactor: 1.0,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: BottomNavigationBar(
                      currentIndex: safeAdminIndex,
                      onTap: (idx) => setState(() => _currentIndex = idx),
                      backgroundColor: Colors.white,
                      elevation: 0,
                      selectedItemColor: AppTheme.primaryBlue,
                      unselectedItemColor: AppTheme.textMuted,
                      selectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                      items: const [
                        BottomNavigationBarItem(
                          icon: Icon(Icons.dashboard_customize_rounded),
                          label: 'Dashboard & Persetujuan',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.manage_accounts_rounded),
                          label: 'Kelola Anggota & Pengurus',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // 2. MODE APLIKASI KHUSUS KARYAWAN / ANGGOTA (Murni 4 Menu Karyawan)
        final List<Widget> memberPages = [
          UserDashboardScreen(
            coopService: _coopService,
            onOpenAdmin: () => _handleOpenAdmin(context),
          ),
          SavingsDetailScreen(coopService: _coopService),
          LoanScreen(coopService: _coopService),
          ResignationScreen(coopService: _coopService),
        ];

        final maxIndex = memberPages.length - 1;
        final safeIndex = _currentIndex.clamp(0, maxIndex);

        return Scaffold(
          body: IndexedStack(
            index: safeIndex,
            children: memberPages,
          ),
          bottomNavigationBar: CustomBottomNavBar(
            currentIndex: safeIndex,
            showAdminTab: false,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
        );
      },
    );
  }
}
