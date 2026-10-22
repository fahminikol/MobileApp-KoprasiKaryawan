import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/coop_service.dart';
import '../services/input_sanitizer.dart';
import '../theme/app_theme.dart';
import '../models/member_model.dart';
import '../models/resignation_model.dart';
import '../models/loan_model.dart';
import '../models/admin_model.dart';
import '../models/transaction_model.dart';
import '../widgets/transfer_proof_picker.dart';
import 'login_screen.dart';
import 'user_management_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  final CoopService coopService;

  const AdminDashboardScreen({
    super.key,
    required this.coopService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: coopService,
      builder: (context, _) {
        final members = coopService.members;
        final pendingResignations = coopService.resignations
            .where((r) =>
                r.status != ResignationStatus.disbursed &&
                r.status != ResignationStatus.rejected)
            .toList();
        final pendingLoans = coopService.loans
            .where((l) => l.status == LoanStatus.pending)
            .toList();
        final pendingDeposits = coopService.pendingDeposits;
        final pendingWithdrawals = coopService.pendingWithdrawals;
        final pendingMembers = coopService.pendingMemberRegistrations;
        final pendingPinResets = coopService.pendingPinResetMembers;
        final pendingEarlySettlements = coopService.pendingEarlySettlementLoans;
        final activeLoans = coopService.loans
            .where((l) => l.status == LoanStatus.active && l.remainingBalance > 0)
            .toList();

        final now = DateTime.now();
        final alreadyExecutedThisMonth =
            coopService.isPayrollExecutedFor(now.month, now.year);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Panel Pengurus (Admin HRD)'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.shield_rounded, color: AppTheme.primaryBlue),
                tooltip: 'Keamanan Token Sesi Admin (JWT)',
                onPressed: () => _showAdminTokenSecurityDialog(context, coopService),
              ),
              IconButton(
                icon: const Icon(Icons.cloud_sync_rounded, color: AppTheme.successGreen),
                tooltip: 'Sinkronisasi ke Supabase Cloud',
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await coopService.syncWithSupabaseCloud();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? '☁️ Data koperasi berhasil disinkronkan ke Supabase Cloud!'
                            : '💾 Data tersimpan aman di database lokal (Tabel Cloud siap diaktifkan).',
                      ),
                      backgroundColor: ok ? AppTheme.successGreen : AppTheme.primaryBlue,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.table_chart_rounded, color: AppTheme.primaryBlue),
                tooltip: 'Rekap Potongan Gaji Finance',
                onPressed: () => _showPayrollPreviewSheet(context),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: AppTheme.dangerRed),
                tooltip: 'Keluar / Logout',
                onPressed: () {
                  coopService.logout();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LoginScreen(coopService: coopService),
                    ),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Admin Badge
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              coopService.currentAdmin != null
                                  ? '${coopService.currentAdmin!.role.badgeEmoji} ${coopService.currentAdmin!.name}'
                                  : 'Administrator Koperasi',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              coopService.currentAdmin != null
                                  ? '${coopService.currentAdmin!.role.label}  •  ${coopService.currentAdmin!.email}'
                                  : 'Kelola iuran, payroll, pinjaman & resign.',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11),
                            ),
                            if (coopService.currentAdmin != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Wewenang: '
                                '${coopService.currentAdmin!.canManageAdmins ? "✔ Master Admin  " : ""}'
                                '${coopService.currentAdmin!.canVerifyMembers ? "✔ Anggota/PIN  " : ""}'
                                '${coopService.currentAdmin!.canVerifyBankMutation ? "✔ Mutasi Bank  " : ""}'
                                '${coopService.currentAdmin!.canApproveFinance ? "✔ Pencairan/Payroll" : ""}',
                                style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 10.5, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // PANEL OTORISASI RBAC (ROLE-BASED ACCESS CONTROL) & JWT SCOPES
                _buildRbacAuthorizationCard(context),
                const SizedBox(height: 12),

                // Kelola Pengguna Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserManagementScreen(coopService: coopService),
                        ),
                      );
                    },
                    icon: const Icon(Icons.manage_accounts_rounded, size: 20),
                    label: const Text('Kelola Pengurus & Cari / Daftarkan Anggota'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      side: const BorderSide(color: AppTheme.primaryBlue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Kartu Rekening Resmi Koperasi PT BBM (Tujuan Transfer Setor Sukarela & Pelunasan)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryBlueLight),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlueLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primaryBlue, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Rekening Resmi Koperasi (Tujuan Transfer Anggota)',
                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${coopService.coopBankName} • ${coopService.coopBankAccountNumber}',
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: AppTheme.primaryBlueDark),
                            ),
                            Text(
                              'a.n. ${coopService.coopBankAccountHolder}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textDark),
                            ),
                          ],
                        ),
                      ),
                      if (coopService.currentAdmin?.canApproveFinance ?? true)
                        TextButton.icon(
                          onPressed: () => _showEditCoopBankDialog(context),
                          icon: const Icon(Icons.edit_rounded, size: 15),
                          label: const Text('Ubah', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Co-op Summary Stats (2x2 Cards) (#63)
                Row(
                  children: [
                    Expanded(
                      child: _buildAdminStat(
                        'Total Kas Buku Simpanan',
                        CoopService.formatRupiah(coopService.totalSavingsBookBalance),
                        Icons.account_balance_rounded,
                        AppTheme.primaryBlue,
                        AppTheme.primaryBlueLight,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAdminStat(
                        'Kas Tunai Siap Pinjam',
                        CoopService.formatRupiah(coopService.availableCashForLoans),
                        Icons.savings_rounded,
                        AppTheme.successGreen,
                        AppTheme.pastelGreenBg,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildAdminStat(
                        'Pinjaman Beredar (${activeLoans.length})',
                        CoopService.formatRupiah(coopService.totalOutstandingLoans),
                        Icons.monetization_on_rounded,
                        AppTheme.warningOrange,
                        AppTheme.pastelYellowBg,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAdminStat(
                        'Antrean Verifikasi',
                        '${pendingLoans.length + pendingResignations.length + pendingDeposits.length + pendingWithdrawals.length + pendingMembers.length + pendingPinResets.length + pendingEarlySettlements.length} Pengajuan',
                        Icons.fact_check_rounded,
                        AppTheme.dangerRed,
                        AppTheme.pastelPinkBg,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Kartu Transparansi Pembagian Bunga Pinjaman 1% ke Anggota Aktif
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.pastelGreenBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.pie_chart_rounded, color: AppTheme.successGreen, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Bagi Hasil Bunga Pinjaman 1% / Bulan',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Dibagi ${coopService.activeMemberCount} Aktif',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total Bunga 1% Pinjaman Aktif: ${CoopService.formatRupiah(coopService.totalMonthlyLoanInterestPool)} / bln  •  '
                        'Jatah per Anggota Aktif: +${CoopService.formatRupiah(coopService.monthlyInterestSharePerMember)} / bln',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // FEATURE 1: Automated Monthly Payroll Deduction Batch + Rekap Potongan Gaji Finance (#2, #6, #92)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.autorenew_rounded, color: AppTheme.primaryBlue),
                              SizedBox(width: 8),
                              Text(
                                'Payroll & Rekap Finance',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: alreadyExecutedThisMonth ? AppTheme.pastelGreenBg : AppTheme.primaryBlueLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              alreadyExecutedThisMonth
                                  ? 'Periode ${now.month}/${now.year} Selesai ✓'
                                  : 'Periode ${now.month}/${now.year}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: alreadyExecutedThisMonth ? AppTheme.successGreen : AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Karyawan baru (gajian ke-1) dipotong Rp 125.000 (100k pokok + 25k wajib).\n'
                        '• Karyawan lama dipotong Rp 25.000 (wajib) + cicilan pinjaman aktif.\n'
                        '• Bunga 1% otomatis dibagi rata ke seluruh anggota aktif!',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      // Tombol Lihat Rekap Potongan Gaji Finance (#2)
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () => _showPayrollPreviewSheet(context),
                          icon: const Icon(Icons.receipt_long_rounded, size: 18),
                          label: const Text(
                            'Lihat & Salin Tabel Rekap Potongan Gaji (Finance)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryBlue,
                            side: const BorderSide(color: AppTheme.primaryBlue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: alreadyExecutedThisMonth
                              ? null
                              : () => _confirmAndExecutePayroll(context),
                          icon: Icon(
                            alreadyExecutedThisMonth ? Icons.check_circle_rounded : Icons.flash_on_rounded,
                            size: 18,
                          ),
                          label: Text(
                            alreadyExecutedThisMonth
                                ? 'Payroll Bulan ${CoopService.formatMonthYear(now.month, now.year)} Sudah Diproses'
                                : 'Eksekusi Potongan Payroll Bulan Berjalan',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // FEATURE 1B: Verifikasi Pendaftaran Anggota Baru & Otorisasi Reset PIN Berlapis
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Verifikasi Akun & Otorisasi Reset PIN',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                    Text(
                      '${pendingMembers.length + pendingPinResets.length} Menunggu',
                      style: const TextStyle(fontSize: 12, color: AppTheme.dangerRed, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (pendingMembers.isEmpty && pendingPinResets.isEmpty)
                  _buildEmptyBox('Tidak ada pendaftaran anggota baru atau permohonan reset PIN yang menunggu verifikasi HRD.')
                else ...[
                  if (pendingMembers.isNotEmpty)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pendingMembers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final m = pendingMembers[idx];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primaryBlueLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '🆕 Pendaftaran Baru: ${m.name} (NIK: ${m.nik})',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.pastelYellowBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Menunggu HRD',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.warningOrange),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Divisi: ${m.department} • Email: ${m.email} • HP: ${m.phone}\n'
                                'Rekening: ${m.bankName} - ${m.bankAccountNumber} • PIN Karyawan: •••••• (Rahasia)',
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.35),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        if (!_requirePermission(
                                          context,
                                          coopService.currentAdmin?.canVerifyMembers ?? true,
                                          'Super Admin / Ketua / Sekretaris [admin:members:verify]',
                                        )) {
                                          return;
                                        }
                                        coopService.rejectPendingMember(m.id);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Pendaftaran ${m.name} ditolak & dihapus.')),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.dangerRed,
                                        side: const BorderSide(color: AppTheme.dangerRed),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: const Text('Tolak Akun'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        if (!_requirePermission(
                                          context,
                                          coopService.currentAdmin?.canVerifyMembers ?? true,
                                          'Super Admin / Ketua / Sekretaris [admin:members:verify]',
                                        )) {
                                          return;
                                        }
                                        coopService.approvePendingMember(m.id);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('✅ Akun ${m.name} (NIK: ${m.nik}) diverifikasi & diaktifkan!'),
                                            backgroundColor: AppTheme.successGreen,
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.successGreen,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: const Text('Verifikasi & Aktifkan'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  if (pendingMembers.isNotEmpty && pendingPinResets.isNotEmpty)
                    const SizedBox(height: 10),
                  if (pendingPinResets.isNotEmpty)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pendingPinResets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final m = pendingPinResets[idx];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.warningOrange.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '🔐 Reset PIN (Lolos 3-Faktor): ${m.name}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryBlueLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'PIN Baru: ••••••',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryBlueDark),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'NIK: ${m.nik} • Email Cocok: ${m.email} • Rek Cocok: ${m.bankName} ${m.bankAccountNumber}\n'
                                'Status Keamanan: Karyawan telah memverifikasi 3 faktor data pribadi. PIN baru tetap terenkripsi (••••••).',
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.35),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        if (!_requirePermission(
                                          context,
                                          coopService.currentAdmin?.canVerifyMembers ?? true,
                                          'Super Admin / Ketua / Sekretaris [admin:members:verify]',
                                        )) {
                                          return;
                                        }
                                        coopService.rejectPendingPinReset(m.id);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Permohonan reset PIN ${m.name} ditolak.')),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.dangerRed,
                                        side: const BorderSide(color: AppTheme.dangerRed),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: const Text('Tolak Reset'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        if (!_requirePermission(
                                          context,
                                          coopService.currentAdmin?.canVerifyMembers ?? true,
                                          'Super Admin / Ketua / Sekretaris [admin:members:verify]',
                                        )) {
                                          return;
                                        }
                                        coopService.approvePendingPinReset(m.id);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('✅ Reset PIN ${m.name} diotorisasi! Karyawan kini dapat login dengan PIN barunya.'),
                                            backgroundColor: AppTheme.successGreen,
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryBlue,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: const Text('Setujui Reset PIN'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
                const SizedBox(height: 24),

                // FEATURE 2: Verifikasi Setoran Simpanan Sukarela (#5, #15)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Verifikasi Setor Sukarela',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                    Text(
                      '${pendingDeposits.length} Menunggu',
                      style: const TextStyle(fontSize: 12, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (pendingDeposits.isEmpty)
                  _buildEmptyBox('Tidak ada setoran sukarela yang menunggu verifikasi.')
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pendingDeposits.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final dep = pendingDeposits[idx];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.primaryBlueLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(dep.memberName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(
                                  CoopService.formatRupiah(dep.amount),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.successGreen),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Catatan: ${dep.description} • ${CoopService.formatDate(dep.date)}',
                              style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                            ),
                            if (dep.proofImageBase64 != null && dep.proofImageBase64!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                onPressed: () => showTransferProofDialog(
                                  context,
                                  dep.proofImageBase64!,
                                  title: 'Bukti Transfer Setor Sukarela (${dep.memberName})',
                                  subtitle: 'Nominal: ${CoopService.formatRupiah(dep.amount)} • ${dep.description}',
                                ),
                                icon: const Icon(Icons.image_search_rounded, size: 15),
                                label: const Text('Lihat Foto Bukti Transfer Karyawan', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryBlue,
                                  side: const BorderSide(color: AppTheme.primaryBlue),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      if (!_requirePermission(
                                        context,
                                        coopService.currentAdmin?.canVerifyBankMutation ?? true,
                                        'Super Admin / Bendahara [admin:bank:verify]',
                                      )) {
                                        return;
                                      }
                                      coopService.rejectPendingDeposit(dep.id);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Setoran sukarela ${dep.memberName} ditolak.')),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.dangerRed,
                                      side: const BorderSide(color: AppTheme.dangerRed),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Tolak'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (!_requirePermission(
                                        context,
                                        coopService.currentAdmin?.canVerifyBankMutation ?? true,
                                        'Super Admin / Bendahara [admin:bank:verify]',
                                      )) {
                                        return;
                                      }
                                      coopService.approvePendingDeposit(dep.id);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('✅ Setoran ${CoopService.formatRupiah(dep.amount)} (${dep.memberName}) diverifikasi & masuk ke saldo!'),
                                          backgroundColor: AppTheme.successGreen,
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.successGreen,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Verifikasi Masuk'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),

                // FEATURE 2C: Pencairan Tarik Simpanan Sukarela (Menunggu Transfer Bendahara)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pencairan Tarik Simpanan Sukarela',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                    Text(
                      '${pendingWithdrawals.length} Menunggu',
                      style: const TextStyle(fontSize: 12, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (pendingWithdrawals.isEmpty)
                  _buildEmptyBox('Tidak ada pengajuan tarik simpanan sukarela yang menunggu pencairan.')
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pendingWithdrawals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final wd = pendingWithdrawals[idx];
                      final member = members.where((m) => m.id == wd.memberId).firstOrNull;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.primaryBlueLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(wd.memberName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(
                                  CoopService.formatRupiah(wd.amount),
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryBlueDark, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (member != null)
                              Text(
                                'Transfer ke: ${member.bankName} - ${member.bankAccountNumber} a.n. ${member.name} • Saldo Sukarela: ${CoopService.formatRupiah(member.simpananSukarela)}',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.primaryBlueDark),
                              ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      if (!_requirePermission(context, coopService.currentAdmin?.canApproveFinance ?? true, 'Bendahara / Super Admin')) return;
                                      coopService.rejectPendingWithdrawal(wd.id);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Pengajuan tarik simpanan ${wd.memberName} ditolak.')),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.dangerRed,
                                      side: const BorderSide(color: AppTheme.dangerRed),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Tolak'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      if (!_requirePermission(context, coopService.currentAdmin?.canApproveFinance ?? true, 'Bendahara / Super Admin')) return;
                                      _showDisburseWithdrawalDialog(context, wd, member);
                                    },
                                    icon: const Icon(Icons.send_to_mobile_rounded, size: 16),
                                    label: const Text('Proses Transfer & Cairkan', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryBlue,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),

                // FEATURE 3: Loan Approvals + Reject Button (#7, #18, #93)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Persetujuan Pinjaman Baru',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                    Text(
                      '${pendingLoans.length} Menunggu',
                      style: const TextStyle(fontSize: 12, color: AppTheme.warningOrange, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (pendingLoans.isEmpty)
                  _buildEmptyBox('Tidak ada pengajuan pinjaman pending.')
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pendingLoans.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, index) {
                      final l = pendingLoans[index];
                      final borrower = members.where((m) => m.id == l.memberId).firstOrNull;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFFEF3C7)),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(l.memberName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Text(
                                  CoopService.formatRupiah(l.amount),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.primaryBlue),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tujuan: ${l.purpose} • Tenor: ${l.tenorMonths} bln • Cicilan: ${CoopService.formatRupiah(l.totalMonthlyInstallment)}/bln',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                            if (borrower != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Transfer Pencairan ke: ${borrower.bankName} - ${borrower.bankAccountNumber} (${borrower.name})',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primaryBlueDark),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: borrower.bankAccountNumber));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('📋 No. Rekening ${borrower.bankName} (${borrower.bankAccountNumber}) disalin!')),
                                      );
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      child: Icon(Icons.copy_rounded, size: 15, color: AppTheme.primaryBlue),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _showRejectLoanDialog(context, l),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.dangerRed,
                                      side: const BorderSide(color: AppTheme.dangerRed),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Tolak'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showDisburseLoanDialog(context, l, borrower),
                                    icon: const Icon(Icons.send_to_mobile_rounded, size: 16),
                                    label: const Text('Proses Transfer & Cairkan'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryBlue,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),

                // FEATURE 3B: Verifikasi Pelunasan Pinjaman Dipercepat
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Verifikasi Pelunasan Dipercepat',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                    Text(
                      '${pendingEarlySettlements.length} Menunggu',
                      style: const TextStyle(fontSize: 12, color: AppTheme.successGreen, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (pendingEarlySettlements.isEmpty)
                  _buildEmptyBox('Tidak ada pengajuan pelunasan pinjaman dipercepat yang menunggu verifikasi.')
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pendingEarlySettlements.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final l = pendingEarlySettlements[idx];
                      final totalPayoff = l.remainingBalance + l.monthlyInterest;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.45)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(l.memberName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(
                                  CoopService.formatRupiah(totalPayoff),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.successGreen),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sisa Pokok: ${CoopService.formatRupiah(l.remainingBalance)} + Bunga 1%: ${CoopService.formatRupiah(l.monthlyInterest)}\n'
                              'Catatan Transfer: ${l.earlySettlementNote ?? "-"}',
                              style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.35),
                            ),
                            if (l.earlySettlementProofBase64 != null && l.earlySettlementProofBase64!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                onPressed: () => showTransferProofDialog(
                                  context,
                                  l.earlySettlementProofBase64!,
                                  title: 'Bukti Transfer Pelunasan Dipercepat (${l.memberName})',
                                  subtitle: 'Total Pelunasan: ${CoopService.formatRupiah(totalPayoff)}',
                                ),
                                icon: const Icon(Icons.image_search_rounded, size: 15),
                                label: const Text('Lihat Foto Bukti Transfer Pelunasan', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryBlue,
                                  side: const BorderSide(color: AppTheme.primaryBlue),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      if (!_requirePermission(
                                        context,
                                        coopService.currentAdmin?.canVerifyBankMutation ?? true,
                                        'Super Admin / Bendahara [admin:bank:verify]',
                                      )) {
                                        return;
                                      }
                                      coopService.rejectEarlyLoanSettlement(l.id);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Pelunasan dipercepat ${l.memberName} ditolak.')),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.dangerRed,
                                      side: const BorderSide(color: AppTheme.dangerRed),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Belum Masuk (Tolak)'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (!_requirePermission(
                                        context,
                                        coopService.currentAdmin?.canVerifyBankMutation ?? true,
                                        'Super Admin / Bendahara [admin:bank:verify]',
                                      )) {
                                        return;
                                      }
                                      coopService.settleLoanEarly(l.id);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('✅ Pelunasan ${l.memberName} (${CoopService.formatRupiah(totalPayoff)}) diverifikasi LUNAS!'),
                                          backgroundColor: AppTheme.successGreen,
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.successGreen,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Verifikasi Lunas'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),

                // FEATURE 3C: Rincian Pinjaman Beredar (Daftar Peminjam Aktif & Jadwal Jatuh Tempo)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Rincian Pinjaman Beredar (Aktif)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                    Text(
                      '${activeLoans.length} Peminjam • Total ${CoopService.formatRupiah(coopService.totalOutstandingLoans)}',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.primaryBlue, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (activeLoans.isEmpty)
                  _buildEmptyBox('Tidak ada pinjaman aktif yang sedang berjalan.')
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activeLoans.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final al = activeLoans[idx];
                      return Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${al.memberName} (${al.purpose})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Pinjaman Awal: ${CoopService.formatRupiah(al.amount)} • Tenor: ${al.paidInstallments}/${al.tenorMonths} bln (Sisa ${al.remainingTenorMonths}x potong gaji)\n'
                                    'Jatuh Tempo: Otomatis potong gaji Rp ${CoopService.formatRupiah(al.totalMonthlyInstallment)} setiap Tanggal 28',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Sisa Pokok', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                Text(
                                  CoopService.formatRupiah(al.remainingBalance),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: AppTheme.warningOrange),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),

                // FEATURE 4: Resignation Claims & Refund Approvals + Reject Button (#7, #18)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Persetujuan Klaim Resign',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                    Text(
                      '${pendingResignations.length} Menunggu',
                      style: const TextStyle(fontSize: 12, color: AppTheme.dangerRed, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (pendingResignations.isEmpty)
                  _buildEmptyBox('Tidak ada pengajuan resign pending.')
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pendingResignations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, index) {
                      final rsg = pendingResignations[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFFEE2E2)),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(rsg.memberName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Text('NIK: ${rsg.memberNik}', style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Alasan: "${rsg.reason}"',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                            ),
                            const Divider(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Cair Bersih (Termasuk SHU 1%):', style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                                Text(
                                  CoopService.formatRupiah(rsg.netRefund),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.dangerRed),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Transfer ke: ${rsg.destinationBank} - ${rsg.destinationAccountNumber} (${rsg.destinationAccountHolder})',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      if (!_requirePermission(context, coopService.currentAdmin?.canApproveFinance ?? true, 'Bendahara / Ketua / Super Admin [admin:finance:approve]')) return;
                                      coopService.rejectResignation(rsg.id, 'Pengajuan dibatalkan/ditolak HRD');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Klaim resign ${rsg.memberName} ditolak & status kembali Aktif.')),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.dangerRed,
                                      side: const BorderSide(color: AppTheme.dangerRed),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Tolak'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      if (!_requirePermission(context, coopService.currentAdmin?.canApproveFinance ?? true, 'Bendahara / Ketua / Super Admin [admin:finance:approve]')) return;
                                      _showDisburseResignationDialog(context, rsg);
                                    },
                                    icon: const Icon(Icons.send_to_mobile_rounded, size: 17),
                                    label: const Text('Proses Transfer & Tutup Akun', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.successGreen,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),

                // Reset Data Simulasi (#100)
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      coopService.resetToDefaultDemoData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🔄 Data simulasi berhasil di-reset ke pengaturan awal!')),
                      );
                    },
                    icon: const Icon(Icons.restore_rounded, size: 16, color: AppTheme.textMuted),
                    label: const Text(
                      'Reset Simulasi ke Data Awal',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRbacAuthorizationCard(BuildContext context) {
    final currentAdmin = coopService.currentAdmin;
    final activeRole = currentAdmin?.role ?? AdminRole.superAdmin;
    final scopes = coopService.activeSessionScopes.isNotEmpty
        ? coopService.activeSessionScopes
        : activeRole.grantedScopes;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_user_rounded, size: 17, color: AppTheme.primaryBlue),
                  SizedBox(width: 6),
                  Text(
                    'Otorisasi RBAC & Scope JWT Aktif',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _showRbacMatrixDialog(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlueLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.policy_rounded, size: 13, color: AppTheme.primaryBlue),
                      SizedBox(width: 4),
                      Text(
                        'Matriks RBAC',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            activeRole.permissionSummary,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.3),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: scopes
                .map(
                  (s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF93C5FD)),
                    ),
                    child: Text(
                      '🔑 $s',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryBlueDark,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          const Text(
            'Uji Cepat Hak Akses Jabatan (Simulasi Beralih Role Pengurus):',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: AdminRole.values.map((role) {
                final isSelected = activeRole == role;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      '${role.badgeEmoji} ${role.label.split(" ").take(2).join(" ")}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryBlue,
                    backgroundColor: Colors.white,
                    onSelected: (_) {
                      final switched = coopService.switchDemoAdminRole(role);
                      if (switched) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '🔄 Beralih ke jabatan ${role.badgeEmoji} ${role.label}. Scope JWT diperbarui (${role.grantedScopes.length} scopes)!',
                            ),
                            backgroundColor: AppTheme.primaryBlueDark,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showRbacMatrixDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.policy_rounded, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Matriks Otorisasi RBAC & Scope JWT',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Setiap Pengurus memiliki wewenang berbeda yang dikunci langsung di dalam Payload JWT (OAuth2 Scopes) dan dicek berlapis di Service Layer:',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.35),
                ),
                const SizedBox(height: 12),
                ...AdminRole.values.map(
                  (r) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r.badgeEmoji} ${r.label}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          r.permissionSummary,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.3),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: r.grantedScopes
                              .map(
                                (s) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlueLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    s,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlueDark,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              coopService.simulateUnauthorizedRoleAttack();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🚫 403 FORBIDDEN: Percobaan aksi tanpa wewenang RBAC berhasil diblokir & dicatat ke Audit Log!'),
                  backgroundColor: AppTheme.dangerRed,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.gpp_bad_rounded, size: 16),
            label: const Text('Simulasi Akses Ilegal (403)', style: TextStyle(fontSize: 11.5)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.dangerRed,
              side: const BorderSide(color: AppTheme.dangerRed),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Center(
        child: Text(text, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      ),
    );
  }

  Widget _buildAdminStat(String title, String value, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  void _showRejectLoanDialog(BuildContext context, LoanModel loan) {
    if (!_requirePermission(
      context,
      coopService.currentAdmin?.canApproveFinance ?? true,
      'Super Admin / Ketua / Bendahara [admin:finance:approve]',
    )) {
      return;
    }
    final reasonCtrl = TextEditingController(text: 'Plafon belum memenuhi syarat / Kas sedang diprioritaskan');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Tolak Pinjaman ${loan.memberName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Alasan Penolakan',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              coopService.rejectLoan(loan.id, reasonCtrl.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Pengajuan pinjaman ${loan.memberName} telah ditolak.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed, foregroundColor: Colors.white),
            child: const Text('Tolak Pengajuan'),
          ),
        ],
      ),
    );
  }

  // Tabel Rekap Potongan Gaji Bulan Ini untuk Finance (#2, #20)
  void _showPayrollPreviewSheet(BuildContext context) {
    final now = DateTime.now();
    final rows = coopService.getMonthlyPayrollPreview(month: now.month, year: now.year);
    final grandTotal = rows.fold<double>(0.0, (sum, r) => sum + (r['totalDeduction'] as double));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        maxChildSize: 0.94,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rekap Potongan Gaji (Untuk Finance)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                      ),
                      Text(
                        'Periode: ${CoopService.formatMonthYear(now.month, now.year)} • ${rows.length} Karyawan Aktif',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, idx) {
                    final r = rows[idx];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${idx + 1}. ${r['name']} (${r['nik']})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                              Text(
                                CoopService.formatRupiah(r['totalDeduction'] as double),
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.primaryBlue),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Divisi: ${r['department']} • '
                            'Pokok: ${CoopService.formatRupiah(r['pokok'] as double)} • '
                            'Wajib: ${CoopService.formatRupiah(r['wajib'] as double)} • '
                            'Cicilan+Bunga 1%: ${CoopService.formatRupiah(r['loanInstallment'] as double)}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL POTONGAN PAYROLL:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  Text(
                    CoopService.formatRupiah(grandTotal),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.successGreen),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final buffer = StringBuffer();
                    buffer.writeln('REKAP POTONGAN GAJI KOPKAR PT BUDI BERLIAN MOTOR');
                    buffer.writeln('Periode: ${CoopService.formatMonthYear(now.month, now.year)}');
                    buffer.writeln('------------------------------------------------');
                    for (final r in rows) {
                      buffer.writeln(
                        '${r['nik']} | ${r['name']} | Pokok: ${CoopService.formatRupiah(r['pokok'] as double)} | Wajib: ${CoopService.formatRupiah(r['wajib'] as double)} | Cicilan: ${CoopService.formatRupiah(r['loanInstallment'] as double)} | TOTAL: ${CoopService.formatRupiah(r['totalDeduction'] as double)}',
                      );
                    }
                    buffer.writeln('------------------------------------------------');
                    buffer.writeln('GRAND TOTAL: ${CoopService.formatRupiah(grandTotal)}');
                    Clipboard.setData(ClipboardData(text: buffer.toString()));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📋 Tabel Rekap Potongan Gaji berhasil disalin! Siap ditempel ke WhatsApp / Excel Finance.'),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Salin Rekap untuk Diserahkan ke Finance / Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Dialog Konfirmasi Sebelum Eksekusi Payroll (#92)
  void _confirmAndExecutePayroll(BuildContext context) {
    if (!_requirePermission(
      context,
      coopService.currentAdmin?.canExecutePayroll ?? true,
      'Super Admin / Ketua / Bendahara [admin:payroll:execute]',
    )) {
      return;
    }
    final now = DateTime.now();
    final rows = coopService.getMonthlyPayrollPreview(month: now.month, year: now.year);
    final grandTotal = rows.fold<double>(0.0, (sum, r) => sum + (r['totalDeduction'] as double));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konfirmasi Eksekusi Payroll', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'Apakah Anda yakin ingin memproses potongan gaji bulan ${CoopService.formatMonthYear(now.month, now.year)} untuk ${rows.length} karyawan aktif dengan total ${CoopService.formatRupiah(grandTotal)}?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeBatchDeduction(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
            child: const Text('Ya, Eksekusi Sekarang'),
          ),
        ],
      ),
    );
  }

  void _executeBatchDeduction(BuildContext context) {
    final now = DateTime.now();
    final result = coopService.executeMonthlyPayrollBatch(month: now.month, year: now.year);

    if (result['alreadyExecuted'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Payroll periode bulan ini sudah pernah diproses! (Proteksi Anti-Dobel Payroll)'),
          backgroundColor: AppTheme.warningOrange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.successGreen),
            SizedBox(width: 8),
            Text('Payroll Sukses Diproses', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Periode: ${CoopService.formatMonthYear(now.month, now.year)}'),
            const SizedBox(height: 8),
            Text('• ${result['month1Count']} Karyawan Baru (Gajian ke-1): dipotong Rp 125.000'),
            Text('• ${result['recurringCount']} Karyawan Lama: dipotong Rp 25.000'),
            if ((result['interestCollected'] as double? ?? 0) > 0) ...[
              const SizedBox(height: 6),
              Text(
                '• Bunga Pinjaman 1%: ${CoopService.formatRupiah(result['interestCollected'] as double)} '
                'dibagi rata ke ${result['memberCount']} anggota aktif (+${CoopService.formatRupiah(result['sharePerMember'] as double)}/orang)',
                style: const TextStyle(color: AppTheme.successGreen, fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
            ],
            const Divider(height: 20),
            Text(
              'Total Terkumpul: ${CoopService.formatRupiah(result['totalDeducted'] as double)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  void _showEditCoopBankDialog(BuildContext context) {
    final bankCtrl = TextEditingController(text: coopService.coopBankName);
    final accCtrl = TextEditingController(text: coopService.coopBankAccountNumber);
    final holderCtrl = TextEditingController(text: coopService.coopBankAccountHolder);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Pengaturan Rekening Resmi Koperasi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nomor rekening ini akan otomatis tampil di aplikasi seluruh karyawan saat mereka ingin menyetor Simpanan Sukarela atau melunasi pinjaman lebih cepat.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: bankCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama Bank Koperasi (Misal: Bank Mandiri / BCA)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: accCtrl,
                decoration: InputDecoration(
                  labelText: 'Nomor Rekening Resmi Koperasi',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: holderCtrl,
                decoration: InputDecoration(
                  labelText: 'Atas Nama Pemilik Rekening',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final bankVal = InputSanitizer.sanitizeBankName(bankCtrl.text);
              final accVal = InputSanitizer.validateBankAccount(accCtrl.text);
              final holderVal = InputSanitizer.validateName(holderCtrl.text);
              if (!accVal.isValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ ${accVal.errorMessage}'),
                    backgroundColor: AppTheme.dangerRed,
                  ),
                );
                return;
              }
              if (!holderVal.isValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ ${holderVal.errorMessage}'),
                    backgroundColor: AppTheme.dangerRed,
                  ),
                );
                return;
              }

              final ok = coopService.updateCoopBankAccount(
                bankName: bankVal,
                accountNumber: accVal.sanitizedValue,
                accountHolder: holderVal.sanitizedValue,
              );
              if (ok) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Rekening Resmi Koperasi berhasil diperbarui & disinkronkan ke seluruh anggota!'),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ Gagal memperbarui rekening koperasi!'),
                    backgroundColor: AppTheme.dangerRed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
            child: const Text('Simpan Rekening'),
          ),
        ],
      ),
    );
  }

  bool _requirePermission(BuildContext context, bool allowed, String requiredRoleLabel) {
    if (allowed) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🔒 Akses dibatasi: Tindakan ini memerlukan wewenang $requiredRoleLabel.',
        ),
        backgroundColor: AppTheme.dangerRed,
      ),
    );
    return false;
  }

  /// Modal Panduan Langkah demi Langkah Pencairan Pinjaman via Transfer Bank Koperasi
  void _showDisburseLoanDialog(BuildContext context, LoanModel loan, MemberModel? borrower) {
    if (!_requirePermission(context, coopService.currentAdmin?.canApproveFinance ?? true, 'Bendahara / Super Admin')) {
      return;
    }
    final refCtrl = TextEditingController();
    final bankName = borrower?.bankName ?? 'Bank Karyawan';
    final accNumber = borrower?.bankAccountNumber ?? '-';
    final availableCash = coopService.availableCashForLoans;
    final isCashInsufficient = loan.amount > availableCash;
    String? proofBase64;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.account_balance_rounded, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Panduan Transfer Pencairan Pinjaman',
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
              if (isCashInsufficient) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.pastelPinkBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    '⚠️ PERINGATAN KAS KOPERASI:\n'
                    'Kas Tunai Siap Dipinjamkan saat ini (${CoopService.formatRupiah(availableCash)}) '
                    'lebih kecil dari pengajuan pinjaman (${CoopService.formatRupiah(loan.amount)}). '
                    'Pastikan saldo riil rekening bank koperasi mencukupi sebelum transfer.',
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.dangerRed, fontWeight: FontWeight.w700, height: 1.35),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.pastelYellowBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warningOrange.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  '💡 PENTING (Alur Pencairan Uang Asli):\n'
                  'Aplikasi ini adalah sistem pembukuan koperasi (bukan M-Banking otomatis). '
                  'Ikuti 3 langkah mudah di bawah ini untuk mencairkan dana ke karyawan:',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textDark, height: 1.35),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Langkah 1: Salin Nomor Rekening & Nominal Karyawan',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlueDark),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlueLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Penerima: ${loan.memberName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$bankName • $accNumber',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.primaryBlueDark),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: accNumber));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('📋 No. Rekening $accNumber disalin!')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 15),
                          label: const Text('Salin Rek', style: TextStyle(fontSize: 11.5)),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nominal Cair: ${CoopService.formatRupiah(loan.amount)}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: AppTheme.successGreen),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: loan.amount.toInt().toString()));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('📋 Nominal transfer disalin!')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 15),
                          label: const Text('Salin Nominal', style: TextStyle(fontSize: 11.5)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Langkah 2: Transfer via M-Banking / Internet Banking Koperasi',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlueDark),
              ),
              const SizedBox(height: 4),
              Text(
                'Buka aplikasi bank perusahaan/koperasi Anda (${coopService.coopBankName}), lalu transfer sebesar ${CoopService.formatRupiah(loan.amount)} ke rekening $bankName $accNumber a.n. ${loan.memberName}.',
                style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.35),
              ),
              const SizedBox(height: 12),
              const Text(
                'Langkah 3: Unggah Foto Bukti Transfer & Konfirmasi',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlueDark),
              ),
              const SizedBox(height: 6),
              TransferProofPicker(
                onChanged: (b64) => proofBase64 = b64,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: refCtrl,
                decoration: InputDecoration(
                  labelText: 'Catatan / No. Referensi Bukti Transfer (Opsional)',
                  hintText: 'Contoh: Sudah TF via Mandiri Bisnis',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Belum Transfer (Batal)')),
          ElevatedButton.icon(
            onPressed: () {
              if (proofBase64 == null || proofBase64!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ Wajib unggah/masukkan foto bukti transfer terlebih dahulu!'),
                    backgroundColor: AppTheme.dangerRed,
                  ),
                );
                return;
              }
              coopService.approveLoan(loan.id, proofImageBase64: proofBase64);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✅ Pinjaman ${loan.memberName} (${CoopService.formatRupiah(loan.amount)}) beserta foto bukti TF dikonfirmasi cair!',
                  ),
                  backgroundColor: AppTheme.successGreen,
                ),
              );
            },
            icon: const Icon(Icons.check_circle_rounded, size: 17),
            label: const Text('Sudah Ditransfer — Aktifkan Pinjaman'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Modal Panduan 3 Langkah Pencairan Tarik Simpanan Sukarela ke Rekening Karyawan
  void _showDisburseWithdrawalDialog(BuildContext context, TransactionModel wd, MemberModel? member) {
    final refCtrl = TextEditingController();
    final bankName = member?.bankName ?? 'Bank Karyawan';
    final accNumber = member?.bankAccountNumber ?? '-';
    String? proofBase64;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Panduan Transfer Tarik Simpanan Sukarela',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                  color: AppTheme.pastelYellowBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warningOrange.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  '💡 Pastikan Anda mentransfer dana terlebih dahulu dari rekening koperasi ke rekening karyawan di bawah ini, lalu unggah foto bukti transfer sebelum klik "Sudah Ditransfer".',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textDark, height: 1.35),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Langkah 1: Salin Rekening & Nominal Pencairan',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlueDark),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlueLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Penerima: ${wd.memberName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$bankName • $accNumber',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.primaryBlueDark),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: accNumber));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('📋 No. Rekening $accNumber disalin!')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 15),
                          label: const Text('Salin Rek', style: TextStyle(fontSize: 11.5)),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nominal Cair: ${CoopService.formatRupiah(wd.amount)}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: AppTheme.successGreen),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: wd.amount.toInt().toString()));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('📋 Nominal penarikan disalin!')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 15),
                          label: const Text('Salin Nominal', style: TextStyle(fontSize: 11.5)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Langkah 2: Unggah Foto Bukti Transfer & Catatan',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlueDark),
              ),
              const SizedBox(height: 6),
              TransferProofPicker(
                onChanged: (b64) => proofBase64 = b64,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: refCtrl,
                decoration: InputDecoration(
                  labelText: 'Catatan / No. Referensi Transfer (Opsional)',
                  hintText: 'Contoh: Sudah TF ke rek karyawan',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton.icon(
            onPressed: () {
              if (proofBase64 == null || proofBase64!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ Wajib unggah/masukkan foto bukti transfer terlebih dahulu!'),
                    backgroundColor: AppTheme.dangerRed,
                  ),
                );
                return;
              }
              final ok = coopService.approvePendingWithdrawal(wd.id, proofImageBase64: proofBase64);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? '✅ Penarikan Simpanan Sukarela ${wd.memberName} (${CoopService.formatRupiah(wd.amount)}) beserta foto bukti TF dikonfirmasi cair!'
                        : '⚠️ Saldo Simpanan Sukarela anggota tidak mencukupi / terkunci jaminan pinjaman.',
                  ),
                  backgroundColor: ok ? AppTheme.successGreen : AppTheme.dangerRed,
                ),
              );
            },
            icon: const Icon(Icons.check_circle_rounded, size: 17),
            label: const Text('Sudah Ditransfer — Potong Saldo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Modal Panduan 3 Langkah Pencairan Pengembalian Dana Resign (Net Refund)
  void _showDisburseResignationDialog(BuildContext context, ResignationModel rsg) {
    final refCtrl = TextEditingController();
    String? proofBase64;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app_rounded, color: AppTheme.dangerRed),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Panduan Transfer Dana Bersih Resign',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                  color: AppTheme.pastelYellowBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warningOrange.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '💡 Rincian Kalkulasi Otomatis (${rsg.memberName}):\n'
                  '• Total Simpanan: ${CoopService.formatRupiah(rsg.grossRefund)}\n'
                  '• Potong Sisa Utang Pinjaman: -${CoopService.formatRupiah(rsg.loanDeduction)}\n'
                  '• Dana Bersih Ditransfer: ${CoopService.formatRupiah(rsg.netRefund)}',
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textDark, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Langkah 1: Salin Rekening Tujuan & Dana Bersih',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlueDark),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlueLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Penerima: ${rsg.destinationAccountHolder}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${rsg.destinationBank} • ${rsg.destinationAccountNumber}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.primaryBlueDark),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: rsg.destinationAccountNumber));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('📋 No. Rekening ${rsg.destinationAccountNumber} disalin!')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 15),
                          label: const Text('Salin Rek', style: TextStyle(fontSize: 11.5)),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Dana Bersih: ${CoopService.formatRupiah(rsg.netRefund)}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: AppTheme.successGreen),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: rsg.netRefund.toInt().toString()));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('📋 Nominal dana bersih resign disalin!')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 15),
                          label: const Text('Salin Nominal', style: TextStyle(fontSize: 11.5)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Langkah 2: Unggah Foto Bukti Transfer & Catat Referensi',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlueDark),
              ),
              const SizedBox(height: 6),
              TransferProofPicker(
                onChanged: (b64) => proofBase64 = b64,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: refCtrl,
                decoration: InputDecoration(
                  labelText: 'Catatan / No. Referensi Transfer (Opsional)',
                  hintText: 'Contoh: Sudah TF pencairan resign',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton.icon(
            onPressed: () {
              if (proofBase64 == null || proofBase64!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ Wajib unggah/masukkan foto bukti transfer terlebih dahulu!'),
                    backgroundColor: AppTheme.dangerRed,
                  ),
                );
                return;
              }
              coopService.approveAndDisburseResignation(rsg.id, proofImageBase64: proofBase64);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Dana resign ${rsg.memberName} (${CoopService.formatRupiah(rsg.netRefund)}) beserta foto bukti TF berhasil dicairkan & akun ditutup!'),
                  backgroundColor: AppTheme.successGreen,
                ),
              );
            },
            icon: const Icon(Icons.check_circle_rounded, size: 17),
            label: const Text('Sudah Ditransfer — Tutup Akun'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showAdminTokenSecurityDialog(BuildContext context, CoopService coop) {
    showDialog(
      context: context,
      builder: (ctx) => ListenableBuilder(
        listenable: coop,
        builder: (context, _) {
          final session = coop.currentAuthSession;
          final access = session?.accessToken;
          final refresh = session?.refreshToken;
          final admin = coop.currentAdmin;
          final isValid = coop.isSessionTokenValid;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isValid ? AppTheme.successGreen : AppTheme.dangerRed)
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isValid ? Icons.shield_rounded : Icons.gpp_bad_rounded,
                    color: isValid ? AppTheme.successGreen : AppTheme.dangerRed,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dual Token & Anti-Theft (JWT)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Access Token (15 Mnt) + Refresh Token Rotasi', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Pengurus Login:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            Text('${admin?.name} (${admin?.role.label})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Status Rotasi:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            Text(
                              isValid ? '🟢 TEROTASI AMAN' : '🔴 KEDALUWARSA / DIBLOKIR',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isValid ? AppTheme.successGreen : AppTheme.dangerRed,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Putaran Rotasi Token:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            Text(
                              'Putaran #${session?.rotationCount ?? 0}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Access Token Card
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('1. Access Token (Short-Lived 15 Mnt):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            Text(access?.remainingFormatted ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('ID: ${access?.tokenId ?? '-'}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.textMuted)),
                        const Text('🛡️ Otomatis hangus cepat agar aman jika disadap di Wi-Fi.', style: TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Refresh Token Card
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('2. Refresh Token (Rotasi Single-Use):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                            Text(refresh?.remainingFormatted ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('ID: ${refresh?.tokenId ?? '-'}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF166534))),
                        const Text('🔒 Anti-Theft: Jika ada hacker memakai ulang token lama, sistem otomatis memutus seluruh sesi!', style: TextStyle(fontSize: 9, color: Color(0xFF15803D))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // EncryptedSharedPreferences Hardware Keystore Card
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '3. Storage: EncryptedSharedPreferences',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5B21B6)),
                            ),
                            Text(
                              'AES-256 GCM',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          '🔐 Android Keystore: Kunci master hardware TEE/SE mengunci seluruh token & data admin dari ancaman USB ADB dump & root explorer.',
                          style: TextStyle(fontSize: 9, color: Color(0xFF4C1D95)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // MAC Address Token Encryption Card
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '4. Kunci Token: Hardware MAC Key',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFF1E40AF), borderRadius: BorderRadius.circular(8)),
                              child: const Text('DEVICE BOUND', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'MAC: ${coop.deviceMacAddress}',
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                        ),
                        Text(
                          'Ciphertext: ${access?.maskedEncryptedToken ?? '-'}',
                          style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFF3B82F6)),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '🔒 Anti-Mentah: Access & Refresh Token dikunci AES-256 menggunakan MAC Address fisik perangkat ini. Mustahil didekripsi jika file disalin ke komputer/HP lain!',
                          style: TextStyle(fontSize: 9, color: Color(0xFF1E3A8A)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // FLAG_SECURE & Inactivity Auto-Lock Card
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '5. Proteksi Layar & Auto-Lock',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                            ),
                            Text('AKTIF', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.successGreen)),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text('🛡️ FLAG_SECURE: Screenshot & screen recording diblokir di HP.', style: TextStyle(fontSize: 9, color: Color(0xFF166534))),
                        Text('⏱️ Inactivity Auto-Lock: Layar terkunci jika tidak ada sentuhan 3 menit.', style: TextStyle(fontSize: 9, color: Color(0xFF166534))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  coop.lockAppNow();
                },
                icon: const Icon(Icons.lock_clock_rounded, size: 15),
                label: const Text('Kunci Layar', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  side: const BorderSide(color: Color(0xFF7C3AED)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final ok = coop.simulateForeignDeviceMacAttack();
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🛡️ TERBUKTI AMAN: File dicoba didekripsi di MAC asing -> Ditolak & token gagal terbaca!'),
                        backgroundColor: Color(0xFF1E3A8A),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.phonelink_erase_rounded, size: 15),
                label: const Text('Uji MAC Asing', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E40AF),
                  side: const BorderSide(color: Color(0xFF3B82F6)),
                ),
              ),
              OutlinedButton.icon(
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
                icon: const Icon(Icons.bug_report_rounded, size: 16),
                label: const Text('Uji Replay'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.dangerRed,
                  side: const BorderSide(color: AppTheme.dangerRed),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final ok = coop.rotateTokenSession();
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🔄 Refresh Token Admin Berhasil Diputar & Token Lama Dihancurkan!'),
                        backgroundColor: AppTheme.successGreen,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Putar Token'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
