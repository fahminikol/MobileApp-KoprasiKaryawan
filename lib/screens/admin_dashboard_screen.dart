import 'package:flutter/material.dart';
import '../services/coop_service.dart';
import '../services/input_sanitizer.dart';
import '../theme/app_theme.dart';
import '../models/resignation_model.dart';
import '../models/loan_model.dart';
import '../models/admin_model.dart';
import 'login_screen.dart';
import 'admin_service_screens.dart';

class AdminDashboardScreen extends StatefulWidget {
  final CoopService coopService;

  const AdminDashboardScreen({
    super.key,
    required this.coopService,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  CoopService get coopService => widget.coopService;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: coopService,
      builder: (context, _) {
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
          backgroundColor: AppTheme.scaffoldBackground,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header Row (Greeting & Action Buttons)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.admin_panel_settings_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    coopService.currentAdmin != null
                                        ? coopService.currentAdmin!.name
                                        : 'Pengurus Koperasi',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textDark,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    coopService.currentAdmin != null
                                        ? '${coopService.currentAdmin!.role.badgeEmoji} ${coopService.currentAdmin!.role.label}  •  PT BBM'
                                        : 'Panel Administrator  •  PT BBM',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Sync Cloud Button
                          GestureDetector(
                            onTap: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final ok = await coopService.syncWithSupabaseCloud();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? '☁️ Data koperasi berhasil disinkronkan ke Supabase Cloud!'
                                        : '💾 Data tersimpan aman di database lokal.',
                                  ),
                                  backgroundColor: ok ? AppTheme.successGreen : AppTheme.primaryBlue,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppTheme.pastelGreenBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.25)),
                              ),
                              child: const Icon(
                                Icons.cloud_sync_rounded,
                                size: 17,
                                color: AppTheme.successGreen,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Security Shield Button
                          GestureDetector(
                            onTap: () => _showAdminTokenSecurityDialog(context, coopService),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppTheme.pastelBlueBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                              ),
                              child: const Icon(
                                Icons.shield_rounded,
                                size: 17,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Settings Button
                          GestureDetector(
                            onTap: () => _showAdminSettingsSheet(context),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: const Icon(
                                Icons.settings_rounded,
                                size: 17,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Logout Button
                          GestureDetector(
                            onTap: () {
                              coopService.logout();
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LoginScreen(coopService: coopService),
                                ),
                                (route) => false,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppTheme.pastelPinkBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.pastelPinkIcon.withValues(alpha: 0.2)),
                              ),
                              child: const Icon(
                                Icons.logout_rounded,
                                size: 17,
                                color: AppTheme.dangerRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. VIP Titanium Obsidian Digital Card (Kartu Eksekutif Koperasi)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0F172A), // Deep Obsidian Slate
                          Color(0xFF1E3A8A), // Royal Midnight
                          Color(0xFF2563EB), // Cobalt Accent
                        ],
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: AppTheme.cardShadow,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header Row: Chip & Contactless & Role Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFFDF7A), Color(0xFFD97706)],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.memory_rounded,
                                      size: 18,
                                      color: Colors.brown.shade900.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.contactless_rounded,
                                  size: 22,
                                  color: Colors.white70,
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    coopService.currentAdmin?.role.badgeEmoji ?? '👑',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    (coopService.currentAdmin?.role.label ?? 'Super Admin').toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Card Balance
                        Text(
                          'TOTAL KAS BUKU KOPERASI',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.8),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CoopService.formatRupiah(coopService.totalSavingsBookBalance),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Sub-stats Pill Row
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Kas Pinjam',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white.withValues(alpha: 0.75),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      CoopService.formatRupiah(coopService.availableCashForLoans),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 26,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'P. Beredar',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white.withValues(alpha: 0.75),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        CoopService.formatRupiah(coopService.totalOutstandingLoans),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 26,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Anggota',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white.withValues(alpha: 0.75),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${coopService.activeMemberCount} Org',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Bottom Rekening Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Rek. ${coopService.coopBankName}: ${coopService.coopBankAccountNumber} (${coopService.coopBankAccountHolder})',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                            if (coopService.currentAdmin?.canApproveFinance ?? true)
                              GestureDetector(
                                onTap: () => _showEditCoopBankDialog(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Ubah',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // 3. Section: "Menu Layanan Pengurus" (4 cols x 2 rows Grid identical to Karyawan)
                  const Text(
                    'Menu Layanan Pengurus',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Menu Grid Row 1 (4 items)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMenuItem(
                        context,
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'Akun & PIN',
                        badgeText: (pendingMembers.length + pendingPinResets.length) > 0
                            ? '${pendingMembers.length + pendingPinResets.length}'
                            : null,
                        bgColor: AppTheme.pastelBlueBg,
                        iconColor: AppTheme.primaryBlue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminPinVerificationScreen(coopService: coopService),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.calendar_month_rounded,
                        label: 'Payroll',
                        badgeText: alreadyExecutedThisMonth ? 'Selesai' : 'Siap',
                        bgColor: AppTheme.pastelPinkBg,
                        iconColor: AppTheme.pastelPinkIcon,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminPayrollScreen(coopService: coopService),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.monetization_on_rounded,
                        label: 'Pinjaman',
                        badgeText: pendingLoans.isNotEmpty ? '${pendingLoans.length}' : null,
                        bgColor: AppTheme.pastelYellowBg,
                        iconColor: AppTheme.pastelYellowIcon,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminLoanApprovalScreen(coopService: coopService),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Setor/Tarik',
                        badgeText: (pendingDeposits.length + pendingWithdrawals.length) > 0
                            ? '${pendingDeposits.length + pendingWithdrawals.length}'
                            : null,
                        bgColor: AppTheme.pastelGreenBg,
                        iconColor: AppTheme.pastelGreenIcon,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminSavingsApprovalScreen(coopService: coopService),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Menu Grid Row 2 (4 items)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMenuItem(
                        context,
                        icon: Icons.exit_to_app_rounded,
                        label: 'Klaim Resign',
                        badgeText: pendingResignations.isNotEmpty ? '${pendingResignations.length}' : null,
                        bgColor: AppTheme.pastelCoralBg,
                        iconColor: AppTheme.pastelCoralIcon,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminResignationScreen(coopService: coopService),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.table_chart_rounded,
                        label: 'Rekap Gaji',
                        badgeText: 'Finance',
                        bgColor: AppTheme.pastelCyanBg,
                        iconColor: AppTheme.pastelCyanIcon,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminPayrollRecapScreen(coopService: coopService),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.receipt_long_rounded,
                        label: 'Pelunasan',
                        badgeText: pendingEarlySettlements.isNotEmpty ? '${pendingEarlySettlements.length}' : null,
                        bgColor: AppTheme.pastelPurpleBg,
                        iconColor: AppTheme.pastelPurpleIcon,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminEarlySettlementScreen(coopService: coopService),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.playlist_add_check_circle_rounded,
                        label: 'Pinjaman Aktif',
                        badgeText: activeLoans.isNotEmpty ? '${activeLoans.length}' : null,
                        bgColor: AppTheme.pastelPurpleBg,
                        iconColor: AppTheme.pastelPurpleIcon,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminLoanApprovalScreen(coopService: coopService),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // 4. Section: Ringkasan Keuangan Koperasi
                  const Text(
                    'Ringkasan Keuangan Koperasi',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),

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
                        children: [
                          const Icon(Icons.pie_chart_rounded, color: AppTheme.successGreen, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Bagi Hasil Bunga Pinjaman 1% / Bulan',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    },
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

  void _showAdminSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengaturan Koperasi & Sistem',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                    ),
                    Text(
                      'KOPKAR PT Budi Berlian Motor • Panel Pengurus',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(sheetCtx),
                ),
              ],
            ),
            const Divider(height: 20),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.pastelBlueBg, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.account_balance_rounded, color: AppTheme.primaryBlue, size: 20),
              ),
              title: const Text('Rekening Resmi Koperasi', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
              subtitle: Text(
                '${coopService.coopBankName} - ${coopService.coopBankAccountNumber}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textLight),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showEditCoopBankDialog(context);
              },
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.pastelGreenBg, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.shield_rounded, color: AppTheme.successGreen, size: 20),
              ),
              title: const Text('Proteksi Keamanan Anti-Maling', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
              subtitle: const Text('Dual-Token Rotasi, Hardware MAC, Auto-Lock 3 Menit', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textLight),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showAdminTokenSecurityDialog(context, coopService);
              },
            ),

            const SizedBox(height: 16),

            // Danger Zone Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppTheme.dangerRed, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Zona Bahaya (Danger Zone)',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.dangerRed),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Kosongkan seluruh data anggota, pinjaman, dan transaksi agar siap memulai pendaftaran karyawan baru dari awal. Diperlukan verifikasi PIN/Password Admin.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textDark, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: () => _showConfirmResetWithPinDialog(context),
                      icon: const Icon(Icons.lock_reset_rounded, size: 16),
                      label: const Text('Reset & Kosongkan Seluruh Data', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.dangerRed,
                        side: const BorderSide(color: AppTheme.dangerRed),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmResetWithPinDialog(BuildContext context) {
    final pinController = TextEditingController();
    bool isObscured = true;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppTheme.pastelPinkBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_rounded, color: AppTheme.dangerRed, size: 24),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Verifikasi Reset Data',
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.pastelPinkBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      '⚠️ PERINGATAN: Seluruh data anggota, riwayat transaksi, mutasi simpanan, dan pinjaman akan DIKOSONGKAN TOTAL agar Anda dapat memulai pendaftaran karyawan dari awal. Akun Pengurus Admin tetap tersimpan.',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.dangerRed, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Masukkan PIN Keamanan / Password Admin:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pinController,
                    obscureText: isObscured,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'PIN (123456) atau Password Admin',
                      hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                      prefixIcon: const Icon(Icons.lock_rounded, size: 18, color: AppTheme.primaryBlue),
                      suffixIcon: IconButton(
                        icon: Icon(isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                        onPressed: () => setDialogState(() => isObscured = !isObscured),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: AppTheme.dangerRed, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Batal'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final input = pinController.text.trim();
                  final currentAdminPassword = coopService.currentAdmin?.password ?? 'admin123';
                  final isValid = input == '123456' || input == currentAdminPassword;

                  if (!isValid) {
                    setDialogState(() {
                      errorMessage = '❌ PIN atau Password Admin salah! Reset dibatalkan.';
                    });
                    return;
                  }

                  coopService.resetToDefaultDemoData();
                  Navigator.pop(dialogCtx); // close PIN dialog
                  Navigator.pop(context); // close Settings bottom sheet
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Seluruh data berhasil dikosongkan! Siap untuk pendaftaran karyawan baru.'),
                      backgroundColor: AppTheme.successGreen,
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                icon: const Icon(Icons.delete_forever_rounded, size: 18),
                label: const Text('Kosongkan Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.dangerRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          );
        },
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
                      Text('Proteksi Anti-Maling (Aktif 24/7)', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
                      Text('Seluruh Keamanan Berjalan Otomatis di Latar Belakang', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
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
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${admin?.name} (${admin?.role.label})',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Status Proteksi:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  isValid ? '🟢 AKTIF OTOMATIS' : '🔴 KEDALUWARSA / DIBLOKIR',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isValid ? AppTheme.successGreen : AppTheme.dangerRed,
                                  ),
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
                                'Putaran #${session?.rotationCount ?? 0} (Otomatis)',
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
                              const Expanded(
                                child: Text('1. Access Token (Short-Lived 15 Mnt):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 6),
                              Text(access?.remainingFormatted ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('ID: ${access?.tokenId ?? '-'}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.textMuted)),
                          const Text('🛡️ Otomatis dirotasi di latar belakang tanpa mengganggu aktivitas.', style: TextStyle(fontSize: 9, color: Color(0xFF64748B))),
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
                              const Expanded(
                                child: Text('2. Refresh Token (Rotasi Single-Use):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                              ),
                              const SizedBox(width: 6),
                              Text(refresh?.remainingFormatted ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('ID: ${refresh?.tokenId ?? '-'}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF166534))),
                          const Text('🔒 Anti-Theft Replay Detection aktif memantau dan memblokir duplikasi sesi.', style: TextStyle(fontSize: 9, color: Color(0xFF15803D))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // EncryptedSharedPreferences & MAC Hardware Card
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
                              const Expanded(
                                child: Text(
                                  '3. Hardware MAC AES-256 & Anti-CSRF',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFF1E40AF), borderRadius: BorderRadius.circular(8)),
                                child: const Text('AKTIF OTOMATIS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'MAC Perangkat: ${coop.deviceMacAddress}',
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '🔒 Enkripsi Android Keystore, Kunci MAC Address, FLAG_SECURE Anti-Screenshot, Auto-Lock 3 Menit, dan Anti-CSRF berjalan otomatis.',
                            style: TextStyle(fontSize: 9, color: Color(0xFF1E3A8A)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 26,
                      color: iconColor,
                    ),
                  ),
                ),
                if (badgeText != null)
                  Positioned(
                    top: -5,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: iconColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
