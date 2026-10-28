import 'package:flutter/material.dart';
import '../services/coop_service.dart';
import '../services/input_sanitizer.dart';
import '../theme/app_theme.dart';
import 'main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  final CoopService coopService;

  const LoginScreen({
    super.key,
    required this.coopService,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers (Password & PIN dikosongkan demi keamanan saat Logout #31)
  final _nikController = TextEditingController();
  final _pinController = TextEditingController();

  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _nikController.dispose();
    _pinController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdminApp = widget.coopService.isAdminPortalOnly;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),

                  // 1. App Logo & Company Header
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: isAdminApp
                          ? const LinearGradient(
                              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                            )
                          : AppTheme.cardGradient,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Icon(
                      isAdminApp
                          ? Icons.admin_panel_settings_rounded
                          : Icons.account_balance_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isAdminApp ? 'KOPKAR ADMIN PORTAL' : 'KOPKAR',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textDark,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'PT Budi Berlian Motor',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAdminApp
                        ? 'Sistem Manajemen Pengurus, HRD, Payroll & Persetujuan Koperasi'
                        : 'Aplikasi Anggota — Simpanan, Pinjaman Bunga 1% & Klaim Resign',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Badge Identitas Aplikasi (Terpisah Murni Antara User vs Admin)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isAdminApp
                          ? const Color(0xFFFEF3C7)
                          : AppTheme.pastelBlueBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAdminApp
                              ? Icons.verified_user_rounded
                              : Icons.person_pin_rounded,
                          size: 16,
                          color: isAdminApp
                              ? AppTheme.warningOrange
                              : AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isAdminApp
                              ? 'Khusus Pengurus Koperasi & Admin HRD'
                              : 'Khusus Karyawan / Anggota Koperasi',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: isAdminApp
                                ? const Color(0xFFB45309)
                                : AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Form Input Container (Murni sesuai aplikasi: Karyawan atau Admin)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: AppTheme.softShadow,
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: isAdminApp ? _buildAdminForm() : _buildMemberForm(),
                  ),
                  const SizedBox(height: 20),

                  // 4. Footer Keamanan Resmi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 15,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          isAdminApp
                              ? 'Otorisasi Terenkripsi Pengurus KOPKAR PT Budi Berlian Motor'
                              : 'Hubungi Admin HRD jika Anda lupa PIN atau belum terdaftar',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLockoutSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🛡️ Keamanan Aktif: Akun sedang dikunci sementara! Tunggu ${widget.coopService.remainingLockoutSeconds} detik.',
        ),
        backgroundColor: AppTheme.dangerRed,
      ),
    );
  }

  // Member Login Form
  Widget _buildMemberForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NIK (Nomor Induk Karyawan)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _nikController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Masukkan NIK karyawan',
            prefixIcon: const Icon(Icons.badge_outlined, size: 20, color: AppTheme.primaryBlue),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'PIN Keamanan (6 Digit Angka)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            TextButton(
              onPressed: () => _showForgotPinDialog(context),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 24),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Lupa PIN?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.primaryBlue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Masukkan 6 digit PIN rahasia Anda',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppTheme.primaryBlue),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              if (widget.coopService.isLoginLockedOut) {
                _showLockoutSnack();
                return;
              }
              final ok = widget.coopService.loginAsMember(
                _nikController.text,
                _pinController.text,
              );
              if (ok) {
                _navigateDashboard(initialTab: 0);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      widget.coopService.lastLoginError ??
                          '❌ NIK atau PIN salah!',
                    ),
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Masuk sebagai Karyawan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),

        // Tombol Pendaftaran Mandiri Karyawan Baru (Tanpa Admin Tahu PIN Rahasianya)
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: () => _showSelfRegisterMemberDialog(context),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text(
              'Belum Punya Akun? Daftar Anggota Baru',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
              side: const BorderSide(color: AppTheme.primaryBlue),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  // Admin Login Form
  Widget _buildAdminForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email Pengurus Koperasi',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _adminEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'Masukkan email pengurus',
            prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20, color: AppTheme.primaryBlue),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),

        const Text(
          'Password Admin',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _adminPasswordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: 'Masukkan password admin',
            prefixIcon: const Icon(Icons.key_rounded, size: 20, color: AppTheme.primaryBlue),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              if (widget.coopService.isLoginLockedOut) {
                _showLockoutSnack();
                return;
              }
              final ok = widget.coopService.loginAsAdmin(
                _adminEmailController.text,
                _adminPasswordController.text,
              );
              if (ok) {
                _navigateDashboard(initialTab: 0);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      widget.coopService.lastLoginError ??
                          '❌ Email atau Password Admin salah!',
                    ),
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Masuk ke Panel Pengurus', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  void _navigateDashboard({required int initialTab}) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MainNavigationScreen(initialIndex: initialTab),
      ),
    );
  }

  /// Dialog Lupa PIN Berlapis (Verifikasi 3-Faktor: NIK + Email Terdaftar + No. Rekening Bank Lengkap + Otorisasi Admin HRD)
  void _showForgotPinDialog(BuildContext context) {
    final nikCtrl = TextEditingController(text: _nikController.text);
    final emailCtrl = TextEditingController();
    final rekCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Verifikasi Berlapis Reset PIN',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlueLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '🔒 Keamanan Anti-Bobol 2 Lapis:\n'
                  '1. Wajib cocokkan 3 data sekaligus: NIK + Email Terdaftar + Nomor Rekening Bank Lengkap.\n'
                  '2. Wajib disetujui Admin HRD sebelum PIN baru aktif (PIN baru Anda tetap disensor •••••• sehingga Admin tidak tahu angkanya).',
                  style: TextStyle(fontSize: 11, color: AppTheme.primaryBlueDark, height: 1.35),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nikCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '1. NIK Karyawan'),
              ),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: '2. Email Resmi Terdaftar',
                  hintText: 'Contoh: budi.santoso@budiberlian.co.id',
                ),
              ),
              TextField(
                controller: rekCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '3. Nomor Rekening Bank Pribadi Lengkap',
                ),
              ),
              TextField(
                controller: newPinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Buat PIN Rahasia Baru (6 Digit Angka)',
                  helperText: 'Dienkripsi •••••• & menunggu otorisasi Admin HRD',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final pinVal = InputSanitizer.validatePin(newPinCtrl.text, disallowWeak: true);
              if (!pinVal.isValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ ${pinVal.errorMessage}'),
                    backgroundColor: AppTheme.dangerRed,
                  ),
                );
                return;
              }
              final ok = widget.coopService.requestPinResetWithMultiFactor(
                nik: nikCtrl.text,
                email: emailCtrl.text,
                bankAccountNumber: rekCtrl.text,
                newPin: newPinCtrl.text,
              );
              if (ok) {
                Navigator.pop(ctx);
                _nikController.text = nikCtrl.text.trim();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '✅ Verifikasi 3-Faktor Berhasil! Permohonan Reset PIN (••••••) telah dikirim & menunggu klik Setujui dari Admin HRD.',
                    ),
                    backgroundColor: AppTheme.successGreen,
                    duration: Duration(seconds: 5),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      widget.coopService.lastLoginError ??
                          '❌ Verifikasi 3-Faktor Gagal: NIK, Email, atau Nomor Rekening tidak cocok!',
                    ),
                    backgroundColor: AppTheme.dangerRed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ajukan Reset PIN'),
          ),
        ],
      ),
    );
  }

  /// Dialog Pendaftaran Mandiri Karyawan Baru (Karyawan membuat PIN rahasia sendiri + Wajib Verifikasi Admin HRD sebelum aktif)
  void _showSelfRegisterMemberDialog(BuildContext context) {
    final nikCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final deptCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final bankCtrl = TextEditingController(text: 'BCA');
    final rekCtrl = TextEditingController();
    final pinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pendaftaran Anggota Baru',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlueLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '🛡️ Verifikasi Karyawan Resmi PT BBM:\n'
                  '• Pendaftaran akan masuk ke antrean Verifikasi Admin HRD agar orang luar tidak bisa membuat akun palsu.\n'
                  '• PIN 6-Digit yang Anda buat bersifat rahasia (••••••) dan tidak terlihat oleh Admin.',
                  style: TextStyle(fontSize: 11, color: AppTheme.primaryBlueDark, height: 1.35),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nikCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'NIK (Nomor Induk Karyawan)'),
              ),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Lengkap Sesuai KTP'),
              ),
              TextField(
                controller: deptCtrl,
                decoration: const InputDecoration(labelText: 'Departemen / Divisi'),
              ),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email Resmi Karyawan (Wajib untuk Verifikasi)'),
              ),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Nomor HP / WhatsApp Aktif'),
              ),
              TextField(
                controller: bankCtrl,
                decoration: const InputDecoration(labelText: 'Nama Bank Pribadi (BCA/Mandiri/BRI/BNI)'),
              ),
              TextField(
                controller: rekCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nomor Rekening Bank Pribadi (Min. 8 Angka)'),
              ),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Buat PIN Rahasia Anda (6 Digit Angka)',
                  helperText: 'Hanya Anda yang mengetahui PIN ini (Admin melihat ••••••)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final nikVal = InputSanitizer.validateNik(nikCtrl.text);
              if (!nikVal.isValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ ${nikVal.errorMessage}'), backgroundColor: AppTheme.dangerRed),
                );
                return;
              }
              final nameVal = InputSanitizer.validateName(nameCtrl.text);
              if (!nameVal.isValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ ${nameVal.errorMessage}'), backgroundColor: AppTheme.dangerRed),
                );
                return;
              }
              final emailVal = InputSanitizer.validateEmail(emailCtrl.text);
              if (!emailVal.isValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ ${emailVal.errorMessage}'), backgroundColor: AppTheme.dangerRed),
                );
                return;
              }
              final phoneVal = InputSanitizer.validatePhone(phoneCtrl.text);
              if (!phoneVal.isValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ ${phoneVal.errorMessage}'), backgroundColor: AppTheme.dangerRed),
                );
                return;
              }
              final rekVal = InputSanitizer.validateBankAccount(rekCtrl.text);
              if (!rekVal.isValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ ${rekVal.errorMessage}'), backgroundColor: AppTheme.dangerRed),
                );
                return;
              }
              final pinVal = InputSanitizer.validatePin(pinCtrl.text, disallowWeak: true);
              if (!pinVal.isValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ ${pinVal.errorMessage}'), backgroundColor: AppTheme.dangerRed),
                );
                return;
              }
              final ok = widget.coopService.registerMember(
                nik: nikCtrl.text,
                name: nameCtrl.text,
                department: deptCtrl.text,
                email: emailCtrl.text,
                phone: phoneCtrl.text,
                joinDate: DateTime.now(),
                bankName: bankCtrl.text,
                bankAccountNumber: rekVal.sanitizedValue,
                initialPin: pinVal.sanitizedValue,
                requireHrVerification: true,
              );
              if (ok) {
                Navigator.pop(ctx);
                _nikController.text = nikCtrl.text.trim();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '✅ Pendaftaran terkirim! Akun Anda menunggu verifikasi Admin HRD sebelum dapat digunakan login.',
                    ),
                    backgroundColor: AppTheme.successGreen,
                    duration: Duration(seconds: 5),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ Pendaftaran Gagal: NIK tersebut sudah terdaftar! Gunakan menu Lupa PIN jika Anda sudah punya akun.'),
                    backgroundColor: AppTheme.dangerRed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Kirim Pendaftaran'),
          ),
        ],
      ),
    );
  }
}
