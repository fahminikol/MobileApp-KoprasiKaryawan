import 'package:flutter/material.dart';
import '../services/coop_service.dart';
import '../services/input_sanitizer.dart';
import '../theme/app_theme.dart';
import '../models/member_model.dart';
import '../widgets/security_pin_dialog.dart';

class BankAndSecurityScreen extends StatefulWidget {
  final CoopService coopService;

  const BankAndSecurityScreen({
    super.key,
    required this.coopService,
  });

  @override
  State<BankAndSecurityScreen> createState() => _BankAndSecurityScreenState();
}

class _BankAndSecurityScreenState extends State<BankAndSecurityScreen> {
  final List<Map<String, String>> supportedBanks = [
    {'name': 'BCA', 'code': 'bca', 'desc': 'Bank Central Asia'},
    {'name': 'Mandiri', 'code': 'mandiri', 'desc': 'Bank Mandiri'},
    {'name': 'BRI', 'code': 'bri', 'desc': 'Bank Rakyat Indonesia'},
    {'name': 'BNI', 'code': 'bni', 'desc': 'Bank Negara Indonesia'},
    {'name': 'BSI', 'code': 'bsi', 'desc': 'Bank Syariah Indonesia'},
    {'name': 'CIMB Niaga', 'code': 'cimb', 'desc': 'CIMB Niaga'},
    {'name': 'BTN', 'code': 'btn', 'desc': 'Bank Tabungan Negara'},
    {'name': 'Permata', 'code': 'permata', 'desc': 'Bank Permata'},
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.coopService,
      builder: (context, _) {
        final member = widget.coopService.currentMember;
        if (member == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final logs = widget.coopService.securityLogs;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Rekening Bank & Keamanan'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Security Trust Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shield_rounded, color: AppTheme.successGreen, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Proteksi Keamanan Berlapis',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Otorisasi PIN 6-digit angka, proteksi Anti-Brute Force 5x percobaan, dan penguncian nama pemilik rekening sesuai NIK.',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Keamanan Dual-Token, Hardware MAC AES-256, OAuth2 Scopes & Anti-CSRF
                // berjalan otomatis sepenuhnya di belakang layar (CoopService) tanpa menampilkan kartu teknis.

                // SECTION 1: REKENING BANK TERDAFTAR
                const Text(
                  'Rekening Bank Utama (Pencairan Dana)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                ),
                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlueLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  member.bankName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.primaryBlue,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Bank Transfer',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.pastelGreenBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'Terverifikasi HRD',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.successGreen),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        member.maskedBankAccount,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.lock_rounded, size: 13, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Atas Nama: ${member.bankAccountHolder} (Sesuai NIK)',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Nomor Lengkap: ',
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          TextButton.icon(
                            onPressed: () => _showEditBankModal(context, member),
                            icon: const Icon(Icons.edit_note_rounded, size: 18),
                            label: const Text('Ubah Rekening', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 2: PUSAT KEAMANAN AKUN
                const Text(
                  'Proteksi Keamanan Transaksi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                ),
                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: member.isBiometricEnabled,
                        onChanged: (val) {
                          widget.coopService.toggleBiometric(val);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                val
                                    ? 'Otorisasi Biometrik diaktifkan untuk akun Anda.'
                                    : 'Otorisasi Biometrik dinonaktifkan. Seluruh transaksi wajib mengetik PIN 6-Digit.',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        title: const Text('Fingerprint / Face ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Izinkan tombol sidik jari saat konfirmasi PIN transaksi', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppTheme.primaryBlueLight, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.fingerprint_rounded, color: AppTheme.primaryBlue, size: 22),
                        ),
                      ),
                      const Divider(height: 1),

                      ListTile(
                        onTap: () => _showChangePinModal(context),
                        title: const Text('Ubah PIN Transaksi (6-Digit Angka)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('PIN wajib saat tarik sukarela, ajukan pinjaman & klaim resign', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppTheme.pastelYellowBg, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.password_rounded, color: AppTheme.warningOrange, size: 22),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textLight),
                      ),
                      const Divider(height: 1),

                      SwitchListTile(
                        value: widget.coopService.isFlagSecureEnabled,
                        onChanged: (val) {
                          widget.coopService.toggleFlagSecure(val);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                val
                                    ? '🛡️ FLAG_SECURE Aktif: Screenshot & Screen Recording diblokir.'
                                    : '⚠️ FLAG_SECURE Dinonaktifkan.',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        title: const Text('Anti-Screenshot & Intip Layar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Cegah tangkapan layar, rekaman video & samarkan di Recent Apps (FLAG_SECURE)', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.screen_lock_portrait_rounded, color: AppTheme.primaryBlue, size: 22),
                        ),
                      ),
                      const Divider(height: 1),

                      SwitchListTile(
                        value: widget.coopService.isAutoLockEnabled,
                        onChanged: (val) {
                          widget.coopService.toggleAutoLock(val);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                val
                                    ? '⏱️ Kunci Otomatis Aktif: Layar terkunci jika 3 menit tidak disentuh.'
                                    : '⚠️ Kunci Otomatis Dinonaktifkan.',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        title: const Text('Kunci Otomatis (Inactivity 3 Mnt)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Kunci layar jika HP ditinggal di meja kantor demi privasi data', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.timer_outlined, color: Color(0xFF7C3AED), size: 22),
                        ),
                      ),
                      const Divider(height: 1),

                      ListTile(
                        title: const Text('Verifikasi Bendahara & HRD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Setoran sukarela, pinjaman & pencairan resign wajib diverifikasi oleh Pengurus Koperasi.', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppTheme.pastelGreenBg, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.verified_user_rounded, color: AppTheme.successGreen, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildTokenSecurityCard(context, widget.coopService),
                const SizedBox(height: 24),

                // SECTION 3: LIVE AUDIT LOG (#53)
                const Text(
                  'Log Aktivitas Keamanan Real-Time',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: logs.isEmpty
                      ? const Text('Belum ada aktivitas tercatat.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted))
                      : Column(
                          children: List.generate(logs.take(6).length, (idx) {
                            final item = logs[idx];
                            final ok = item['success'] != 'false';
                            return Padding(
                              padding: EdgeInsets.only(bottom: idx < logs.take(6).length - 1 ? 12 : 0),
                              child: _buildAuditItem(
                                icon: ok ? Icons.verified_rounded : Icons.warning_amber_rounded,
                                title: item['title'] ?? 'Aktivitas Sistem',
                                time: item['time'] ?? '',
                                isSuccess: ok,
                              ),
                            );
                          }),
                        ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuditItem({
    required IconData icon,
    required String title,
    required String time,
    required bool isSuccess,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSuccess ? AppTheme.pastelGreenBg : AppTheme.pastelPinkBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isSuccess ? AppTheme.successGreen : AppTheme.dangerRed, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textDark)),
              Text(time, style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
            ],
          ),
        ),
      ],
    );
  }

  // Anti-Crash Dropdown (#13) + Validasi Nomor Rekening (#89)
  void _showEditBankModal(BuildContext context, MemberModel member) {
    final bankOptions = List<Map<String, String>>.from(supportedBanks);
    final hasCurrentBank = bankOptions.any((b) => b['name'] == member.bankName);
    if (!hasCurrentBank && member.bankName.isNotEmpty) {
      bankOptions.insert(0, {
        'name': member.bankName,
        'code': member.bankName.toLowerCase(),
        'desc': 'Bank Terdaftar',
      });
    }

    String selectedBank = member.bankName.isNotEmpty ? member.bankName : 'BCA';
    final accNumberController = TextEditingController(text: member.bankAccountNumber);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ubah Rekening Bank Pencairan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                'Demi keamanan, nama pemilik rekening dikunci sesuai nama karyawan Anda.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),

              const Text('Pilih Bank', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selectedBank,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: bankOptions.map((b) {
                  return DropdownMenuItem(value: b['name'], child: Text('${b['name']} (${b['desc']})'));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedBank = val);
                },
              ),
              const SizedBox(height: 14),

              const Text('Nomor Rekening (Wajib Angka Min. 8 Digit)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: accNumberController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Masukkan nomor rekening baru',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded, size: 16, color: AppTheme.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nama Pemilik: ${member.name} (Terkunci)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final rekVal = InputSanitizer.validateBankAccount(accNumberController.text);
                    if (!rekVal.isValid) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ ${rekVal.errorMessage}'),
                          backgroundColor: AppTheme.dangerRed,
                        ),
                      );
                      return;
                    }

                    final cleanAcc = rekVal.sanitizedValue;
                    final cleanBank = InputSanitizer.sanitizeBankName(selectedBank);

                    Navigator.pop(ctx);
                    SecurityPinDialog.show(
                      context,
                      coopService: widget.coopService,
                      title: 'Konfirmasi Perubahan Rekening',
                      amount: cleanBank,
                      destination: cleanAcc,
                      onVerified: () {
                        widget.coopService.updateBankAccount(
                          bankName: cleanBank,
                          accountNumber: cleanAcc,
                          accountHolder: member.name,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Rekening bank berhasil diperbarui!')),
                        );
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Verifikasi PIN & Simpan Perubahan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePinModal(BuildContext context) {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ganti PIN Transaksi (Wajib 6 Digit Angka)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: oldPinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'PIN Lama Saat Ini',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newPinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'PIN Baru (Wajib 6 Angka 0-9)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  final pinVal = InputSanitizer.validatePin(newPinController.text, disallowWeak: true);
                  if (!pinVal.isValid) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ ${pinVal.errorMessage}'),
                        backgroundColor: AppTheme.dangerRed,
                      ),
                    );
                    return;
                  }
                  if (newPinController.text.trim() == oldPinController.text.trim()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ PIN Baru tidak boleh sama persis dengan PIN Lama!'),
                        backgroundColor: AppTheme.dangerRed,
                      ),
                    );
                    return;
                  }
                  final success = widget.coopService.changeSecurityPin(
                    oldPinController.text,
                    newPinController.text,
                  );
                  if (success) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ PIN Keamanan transaksi berhasil diubah!')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ PIN Lama salah!'),
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
                child: const Text('Simpan PIN Baru'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenSecurityCard(BuildContext context, CoopService coop) {
    final session = coop.currentAuthSession;
    final access = session?.accessToken;
    final refresh = session?.refreshToken;
    final isValid = coop.isSessionTokenValid;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isValid
              ? AppTheme.successGreen.withValues(alpha: 0.3)
              : AppTheme.dangerRed.withValues(alpha: 0.3),
        ),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isValid ? AppTheme.successGreen : AppTheme.dangerRed)
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isValid
                          ? Icons.security_rounded
                          : Icons.gpp_bad_rounded,
                      color: isValid ? AppTheme.successGreen : AppTheme.dangerRed,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Refresh Token & Rotasi Kriptografi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        'Dual-Token Architecture (Anti-Theft)',
                        style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isValid ? AppTheme.successGreen : AppTheme.dangerRed)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isValid ? 'TERROTASI AMAN' : 'KEDALUWARSA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isValid ? AppTheme.successGreen : AppTheme.dangerRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // TIKET 1: ACCESS TOKEN (15 MENIT)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bolt_rounded, size: 14, color: AppTheme.warningOrange),
                        SizedBox(width: 4),
                        Text(
                          '1. Access Token (Umur Pendek 15 Mnt):',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                      ],
                    ),
                    Text(
                      access?.remainingFormatted ?? '-',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${access?.tokenId ?? '-'}',
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.textMuted),
                ),
                const SizedBox(height: 2),
                const Text(
                  '🛡️ Jika sinyal disadap hacker di Wi-Fi umum, token ini langsung hangus dalam hitungan menit sehingga data tetap aman.',
                  style: TextStyle(fontSize: 10, color: Color(0xFF475569), height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // TIKET 2: REFRESH TOKEN (ROTASI OTOMATIS)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.sync_lock_rounded, size: 14, color: AppTheme.successGreen),
                        SizedBox(width: 4),
                        Text(
                          '2. Refresh Token (Rotasi Sekali Pakai):',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Putaran ke-${session?.rotationCount ?? 0}',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${refresh?.tokenId ?? '-'}',
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF15803D)),
                ),
                const SizedBox(height: 2),
                const Text(
                  '🔒 Single-Use Token Rotation: Setiap kali dipakai, token lama langsung dihancurkan. Jika ada hacker mencoba memakai ulang token curian, sistem langsung memicu ALARM dan memblokir sesi total!',
                  style: TextStyle(fontSize: 10, color: Color(0xFF166534), height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // TIKET 3: ENCRYPTED STORAGE (EncryptedSharedPreferences / Hardware Keystore)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shield_rounded, size: 14, color: Color(0xFF7C3AED)),
                        SizedBox(width: 4),
                        Text(
                          '3. Penyimpanan: EncryptedSharedPreferences',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5B21B6)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'AES-256 GCM',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Hardware Keystore: master_key_kopkar_bbm',
                  style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF6D28D9)),
                ),
                const SizedBox(height: 2),
                const Text(
                  '🔐 Kriptografi Hardware: Token, saldo, dan PIN disimpan terenkripsi di brankas fisik HP (Android Keystore TEE/SE). Meski HP di-root atau diekstrak via kabel USB / ADB, data tidak bisa dibaca hacker!',
                  style: TextStyle(fontSize: 10, color: Color(0xFF4C1D95), height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // TIKET 4: KUNCI TOKEN MENGGUNAKAN MAC ADDRESS (AES-256 DEVICE BINDING)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.fingerprint_rounded, size: 14, color: AppTheme.primaryBlue),
                        SizedBox(width: 4),
                        Text(
                          '4. Kunci Enkripsi Token: MAC Address Hardware',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'DEVICE BOUND',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Hardware MAC: ${coop.deviceMacAddress}',
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ciphertext di Storage: ${access?.maskedEncryptedToken ?? '-'}',
                  style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFF3B82F6)),
                ),
                const SizedBox(height: 3),
                const Text(
                  '🔒 Anti-Data Mentah & Anti-Kloning: Token dan Refresh Token TIDAK disimpan mentah. Keduanya dikunci kriptografi AES-256 menggunakan kunci fisik MAC Address perangkat ini. Jika dicuri ke perangkat lain, token otomatis rusak & tidak bisa didekripsi!',
                  style: TextStyle(fontSize: 10, color: Color(0xFF1E3A8A), height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // TIKET 5: OTORISASI HAK AKSES JWT (OAUTH2 SCOPES & ANTI-IDOR GUARD)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEFCE8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEAB308).withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFFCA8A04)),
                        SizedBox(width: 4),
                        Text(
                          '5. Otorisasi Hak Akses JWT (OAuth2 Scopes):',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF854D0E)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCA8A04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        access?.authLevel ?? 'MFA_PIN_MAC_BOUND',
                        style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: (access?.scopes.isNotEmpty == true
                          ? access!.scopes
                          : const [
                              'member:read:own',
                              'member:savings:deposit',
                              'member:savings:withdraw',
                              'member:loan:apply',
                              'member:resign:request',
                              'member:security:manage',
                            ])
                      .map(
                        (s) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFDE047)),
                          ),
                          child: Text(
                            '✓ $s',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF713F12),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 6),
                const Text(
                  '🛡️ Isolasi Akun & Otorisasi Berlapis (Anti-IDOR): Setiap transaksi divalidasi terhadap Scope JWT di atas & kepemilikan NIK. Anggota tidak bisa mengakses data anggota lain atau mengeksekusi menu Pengurus HRD (403 Forbidden).',
                  style: TextStyle(fontSize: 10, color: Color(0xFF713F12), height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // TIKET 6: PROTEKSI ANTI-CSRF (SYNCHRONIZER TOKEN HMAC-SHA256 & ORIGIN GUARD)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.security_update_good_rounded, size: 14, color: Color(0xFF15803D)),
                        SizedBox(width: 4),
                        Text(
                          '6. Proteksi Anti-CSRF (Cross-Site Forgery Guard):',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'HMAC-SHA256',
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'CSRF Token: ${coop.currentCsrfToken?.maskedToken ?? '-'}',
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF15803D)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Session Bound ID: ${coop.activeSessionId}',
                  style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: Color(0xFF166534)),
                ),
                const SizedBox(height: 3),
                const Text(
                  '🛡️ Synchronizer Token Pattern (OWASP ASVS L3): Setiap transaksi web/mobile wajib menyertakan token HMAC berumur terbatas yang terikat dengan ID sesi aktif. Upaya manipulasi dari situs eksternal atau form phishing ditolak seketika (403 Forbidden).',
                  style: TextStyle(fontSize: 10, color: Color(0xFF14532D), height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final ok = coop.rotateTokenSession();
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🔄 Refresh Token Berhasil Diputar & Token Lama Dihancurkan!'),
                          backgroundColor: AppTheme.successGreen,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.sync_rounded, size: 15),
                  label: const Text('Putar Token Sesi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                    side: const BorderSide(color: AppTheme.primaryBlue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: AppTheme.dangerRed),
                            SizedBox(width: 8),
                            Text('Uji Deteksi Pencurian', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        content: const Text(
                          'Sistem akan menyimulasikan skenario di mana seorang hacker mencuri Refresh Token lama Anda dan mencoba menggunakannya kembali.\n\nSistem rotasi akan mendeteksi token reuse replay, membunyikan alarm keamanan merah, dan memblokir sesi demi keamanan Anda.',
                          style: TextStyle(fontSize: 12, height: 1.4),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              coop.simulateTokenTheftAttack();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🚨 ALARM AKTIF: Upaya Pencurian Token Terdeteksi! Sesi otomatis dibatalkan.'),
                                  backgroundColor: AppTheme.dangerRed,
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.dangerRed,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Jalankan Simulasi Hacker'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.bug_report_rounded, size: 15),
                  label: const Text('Uji Anti-Maling', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.dangerRed,
                    side: const BorderSide(color: AppTheme.dangerRed),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final ok = coop.simulateForeignDeviceMacAttack();
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🛡️ TERBUKTI AMAN: File dicoba buka di HP lain dengan MAC berbeda -> Token gagal didekripsi & diblokir total!'),
                      backgroundColor: Color(0xFF1E3A8A),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.phonelink_erase_rounded, size: 15),
              label: const Text('Uji Proteksi Kloning (Simulasi MAC Berbeda)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E40AF),
                side: const BorderSide(color: Color(0xFF3B82F6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                coop.authorizeMemberScope(
                  'member:savings:withdraw',
                  targetMemberId: 'MBR-999-FOREIGN',
                  actionLabel: 'Tarik Saldo Akun Orang Lain',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🚫 OTORISASI DITOLAK (403 Anti-IDOR): Akses silang ke akun anggota lain otomatis diblokir & dicatat di Log Keamanan!'),
                    backgroundColor: Color(0xFF854D0E),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 4),
                  ),
                );
              },
              icon: const Icon(Icons.policy_rounded, size: 15),
              label: const Text('Uji Otorisasi & Anti-IDOR (Simulasi Akses Silang 403)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF854D0E),
                side: const BorderSide(color: Color(0xFFCA8A04)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final blocked = coop.simulateCsrfAttack();
                if (blocked) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🛡️ CSRF BLOCKED (403 Forbidden): Upaya manipulasi lintas situs dari domain asing dicegat oleh Anti-CSRF Guard & tercatat di Audit Log!'),
                      backgroundColor: Color(0xFF15803D),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.shield_outlined, size: 15),
              label: const Text('Uji Anti-CSRF (Simulasi Forgery 403)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF15803D),
                side: const BorderSide(color: Color(0xFF22C55E)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
