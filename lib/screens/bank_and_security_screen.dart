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
                              'Proteksi Keamanan Berlapis (Aktif 24/7)',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Seluruh sistem keamanan Anti-Maling (Dual-Token Rotasi, Enkripsi MAC Address, Anti-Screenshot, Auto-Lock & Anti-CSRF) berjalan otomatis di latar belakang.',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

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
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryBlueLight,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      member.bankName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.primaryBlue,
                                        fontSize: 14,
                                      ),
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
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.pastelGreenBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
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
                          Expanded(
                            child: Text(
                              'Atas Nama: ${member.bankAccountHolder} (Sesuai NIK)',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'No. Rek: ${member.bankAccountNumber}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                            ),
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
                  'Pengaturan PIN & Proteksi Otomatis',
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

                      _buildAlwaysOnProtectionTile(
                        icon: Icons.gpp_good_rounded,
                        iconColor: AppTheme.successGreen,
                        iconBg: AppTheme.pastelGreenBg,
                        title: 'Proteksi Anti-Maling & Enkripsi Perangkat',
                        subtitle: 'Dual-Token Rotasi Otomatis, Penguncian MAC Address Hardware AES-256, Anti-IDOR & Anti-CSRF berjalan terus di latar belakang.',
                      ),
                      const Divider(height: 1),

                      _buildAlwaysOnProtectionTile(
                        icon: Icons.screen_lock_portrait_rounded,
                        iconColor: AppTheme.primaryBlue,
                        iconBg: const Color(0xFFEFF6FF),
                        title: 'Anti-Screenshot & Intip Layar (FLAG_SECURE)',
                        subtitle: 'Otomatis mencegah tangkapan layar, rekaman video & menyamarkan tampilan di Recent Apps.',
                      ),
                      const Divider(height: 1),

                      _buildAlwaysOnProtectionTile(
                        icon: Icons.timer_outlined,
                        iconColor: const Color(0xFF7C3AED),
                        iconBg: const Color(0xFFF5F3FF),
                        title: 'Kunci Otomatis (Auto-Lock 3 Menit)',
                        subtitle: 'Otomatis mengunci layar aplikasi jika tidak ada aktivitas selama 3 menit.',
                      ),
                      const Divider(height: 1),

                      _buildAlwaysOnProtectionTile(
                        icon: Icons.verified_user_rounded,
                        iconColor: AppTheme.successGreen,
                        iconBg: AppTheme.pastelGreenBg,
                        title: 'Verifikasi Berlapis Bendahara & HRD',
                        subtitle: 'Setoran sukarela, pinjaman & pencairan resign wajib diverifikasi oleh Pengurus Koperasi.',
                      ),
                    ],
                  ),
                ),
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

  Widget _buildAlwaysOnProtectionTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.pastelGreenBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'AKTIF OTOMATIS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.successGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: bankOptions.map((b) {
                  return DropdownMenuItem(
                    value: b['name'],
                    child: Text(
                      '${b['name']} (${b['desc']})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
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
}
