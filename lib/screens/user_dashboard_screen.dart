import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/coop_service.dart';
import '../theme/app_theme.dart';
import '../models/member_model.dart';
import '../widgets/security_pin_dialog.dart';
import '../widgets/transfer_proof_picker.dart';
import 'savings_detail_screen.dart';
import 'resignation_screen.dart';
import 'loan_screen.dart';
import 'bank_and_security_screen.dart';
import 'login_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  final CoopService coopService;
  final VoidCallback onOpenAdmin;

  const UserDashboardScreen({
    super.key,
    required this.coopService,
    required this.onOpenAdmin,
  });

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  bool _hideNotificationBanner = false;
  bool _isBalanceHidden = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.coopService,
      builder: (context, _) {
        final member = widget.coopService.currentMember;
        if (member == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final latestTx = widget.coopService.currentMemberTransactions.firstOrNull;

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBackground,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Top Modern Header Bar
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            member.name.isNotEmpty ? member.name[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Halo, ${member.name.split(" ").first} 👋',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textDark,
                                      letterSpacing: -0.4,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${member.department} • PT Budi Berlian Motor',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (widget.coopService.isAdminPortalOnly) ...[
                            GestureDetector(
                              onTap: widget.onOpenAdmin,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlueLight,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.admin_panel_settings_rounded, size: 15, color: AppTheme.primaryBlue),
                                    SizedBox(width: 4),
                                    Text(
                                      'Admin',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          GestureDetector(
                            onTap: () {
                              widget.coopService.logout();
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LoginScreen(coopService: widget.coopService),
                                ),
                                (route) => false,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.pastelPinkBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.pastelPinkIcon.withValues(alpha: 0.2)),
                              ),
                              child: const Icon(
                                Icons.logout_rounded,
                                size: 18,
                                color: AppTheme.dangerRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. VIP Titanium Digital Member Card
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
                        // Card Header Row: Chip & Contactless & Brand
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
                                  const Icon(Icons.verified_rounded, size: 12, color: Colors.amberAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    'NIK ${member.nik}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Balance Label + Eye Toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL SALDO SIMPANAN',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.7),
                                letterSpacing: 0.8,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _isBalanceHidden = !_isBalanceHidden),
                              child: Row(
                                children: [
                                  Icon(
                                    _isBalanceHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    size: 15,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isBalanceHidden ? 'Tampilkan' : 'Sembunyikan',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Big Bold Amount
                        Text(
                          _isBalanceHidden ? 'Rp ••••••••' : CoopService.formatRupiah(member.totalSavings),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),

                        if (member.activeLoanBalance > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.amberAccent.withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 13, color: Colors.amberAccent),
                                const SizedBox(width: 5),
                                Text(
                                  'Sisa Pinjaman: ${_isBalanceHidden ? "Rp •••••" : CoopService.formatRupiah(member.activeLoanBalance)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.amberAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),
                        Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        const SizedBox(height: 12),

                        // Card Footer: Member Name & Sub-balances breakdown pill
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.name.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${member.statusLabel} • ${member.membershipMonths} Bulan',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'SHU: ${_isBalanceHidden ? "••••" : CoopService.formatRupiah(member.saldoBagiHasilBunga)}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6EE7B7), // Emerald accent
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. Quick Actions Dock (Floating Bar Under Card)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppTheme.softShadow,
                      border: Border.all(color: AppTheme.borderLight, width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildQuickAction(
                          icon: Icons.add_circle_outline_rounded,
                          label: 'Setor',
                          color: AppTheme.primaryBlue,
                          onTap: () => _showSukarelaActionSheet(context, member),
                        ),
                        _buildQuickAction(
                          icon: Icons.arrow_circle_up_rounded,
                          label: 'Tarik Tunai',
                          color: AppTheme.successGreen,
                          onTap: () => _showSukarelaActionSheet(context, member),
                        ),
                        _buildQuickAction(
                          icon: Icons.monetization_on_outlined,
                          label: 'Pinjaman 1%',
                          color: AppTheme.warningOrange,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LoanScreen(coopService: widget.coopService),
                              ),
                            );
                          },
                        ),
                        _buildQuickAction(
                          icon: Icons.pie_chart_outline_rounded,
                          label: 'Info SHU',
                          color: AppTheme.purpleAccent,
                          onTap: () => _showShuTransparencyModal(context, member),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. Section: "Menu Layanan"
                  const Text(
                    'Menu Layanan',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Menu Grid (4 cols x 2 rows)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMenuItem(
                        context,
                        icon: Icons.calendar_month_rounded,
                        label: 'Potongan',
                        badgeText: 'Payroll',
                        bgColor: AppTheme.pastelBlueBg,
                        iconColor: AppTheme.pastelBlueIcon,
                        onTap: () => _showPayrollExplanation(context, member),
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.savings_rounded,
                        label: 'Simpanan',
                        badgeText: 'Pokok/Wajib',
                        bgColor: AppTheme.pastelPinkBg,
                        iconColor: AppTheme.pastelPinkIcon,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SavingsDetailScreen(coopService: widget.coopService),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.monetization_on_rounded,
                        label: 'Pinjaman',
                        badgeText: '1% Flat',
                        bgColor: AppTheme.pastelYellowBg,
                        iconColor: AppTheme.pastelYellowIcon,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LoanScreen(coopService: widget.coopService),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Sukarela',
                        badgeText: 'Fleksibel',
                        bgColor: AppTheme.pastelGreenBg,
                        iconColor: AppTheme.pastelGreenIcon,
                        onTap: () => _showSukarelaActionSheet(context, member),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMenuItem(
                        context,
                        icon: Icons.exit_to_app_rounded,
                        label: 'Klaim Resign',
                        badgeText: '100% Hak',
                        bgColor: AppTheme.pastelCoralBg,
                        iconColor: AppTheme.pastelCoralIcon,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ResignationScreen(coopService: widget.coopService),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.pie_chart_rounded,
                        label: 'Info SHU 1%',
                        badgeText: 'Bagi Rata',
                        bgColor: AppTheme.pastelCyanBg,
                        iconColor: AppTheme.pastelCyanIcon,
                        onTap: () => _showShuTransparencyModal(context, member),
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.receipt_long_rounded,
                        label: 'Mutasi',
                        badgeText: 'Realtime',
                        bgColor: AppTheme.pastelPurpleBg,
                        iconColor: AppTheme.pastelPurpleIcon,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SavingsDetailScreen(coopService: widget.coopService),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.security_rounded,
                        label: 'Bank & PIN',
                        badgeText: 'AES-256',
                        bgColor: AppTheme.pastelIndigoBg,
                        iconColor: AppTheme.pastelIndigoIcon,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BankAndSecurityScreen(coopService: widget.coopService),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // 5. Section: "Notifikasi Real-Time" (#14, #41)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Notifikasi & Mutasi Terakhir',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SavingsDetailScreen(coopService: widget.coopService),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Lihat semua',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 6. Dynamic Notification Card (#14, #41)
                  if (!_hideNotificationBanner && latestTx != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 4,
                            height: 52,
                            decoration: BoxDecoration(
                              color: latestTx.isCredit ? AppTheme.successGreen : AppTheme.primaryBlue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${latestTx.typeLabel} (${CoopService.formatDate(latestTx.date)})',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${latestTx.description} • Nominal: ${CoopService.formatRupiah(latestTx.amount)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _hideNotificationBanner = true),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppTheme.textLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Notice Card on Resignation Rule Guarantee
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_outlined, color: AppTheme.successGreen, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Jaminan 100% Hak Dana: Simpanan Pokok + Wajib + Sukarela + Bagi Hasil Bunga 1% wajib cair utuh saat Anda resign.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF166534),
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
              letterSpacing: -0.2,
            ),
          ),
        ],
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(20),
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
                    size: 27,
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
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  // Modal Transparansi Info SHU Bunga 1% (#11: Menggantikan tombol Kantin Mart yang kosong)
  void _showShuTransparencyModal(BuildContext context, MemberModel member) {
    final coop = widget.coopService;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pie_chart_rounded, color: AppTheme.successGreen),
                SizedBox(width: 8),
                Text(
                  'Transparansi Bagi Hasil Bunga 1%',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Sesuai aturan KOPKAR PT Budi Berlian Motor: Setiap pinjaman anggota dikenakan bunga 1% flat per bulan (maksimal 12 bulan). Seluruh bunga 1% yang terkumpul dibagi rata ke seluruh anggota aktif!',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.pastelGreenBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildModalRow('Jumlah Anggota Aktif Penerima', '${coop.activeMemberCount} Karyawan'),
                  const Divider(height: 16),
                  _buildModalRow('Total Pinjaman Aktif Beredar', CoopService.formatRupiah(coop.totalOutstandingLoans)),
                  const Divider(height: 16),
                  _buildModalRow('Bunga 1% Terkumpul / Bulan', CoopService.formatRupiah(coop.totalMonthlyLoanInterestPool)),
                  const Divider(height: 16),
                  _buildModalRow('Jatah Bagi Hasil Anda / Bulan', '+${CoopService.formatRupiah(coop.monthlyInterestSharePerMember)}'),
                  const Divider(height: 16),
                  _buildModalRow('Saldo Bagi Hasil Terkumpul Anda', CoopService.formatRupiah(member.saldoBagiHasilBunga)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textDark)),
        Text(val, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.primaryBlueDark)),
      ],
    );
  }

  void _showPayrollExplanation(BuildContext context, MemberModel member) {
    final isFirstMonth = member.simpananPokok <= 0;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aturan Potongan Payroll Bulanan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 14),
            _buildRuleTile(
              icon: Icons.looks_one_rounded,
              title: 'Gajian Pertama (Pendaftaran Anggota)',
              subtitle: 'Potongan Rp 125.000 (Rp 100.000 Simpanan Pokok 1x + Rp 25.000 Simpanan Wajib).',
              isHighlighted: isFirstMonth,
            ),
            const SizedBox(height: 10),
            _buildRuleTile(
              icon: Icons.autorenew_rounded,
              title: 'Gajian Bulan ke-2 dan Seterusnya',
              subtitle: 'Potongan rutin Rp 25.000 / bulan (Simpanan Wajib) + angsuran pinjaman jika ada.',
              isHighlighted: !isFirstMonth,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Mengerti'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isHighlighted,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighlighted ? AppTheme.primaryBlueLight : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? AppTheme.primaryBlue : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryBlue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Menu Sukarela: Bisa Setor (Menunggu Verifikasi Admin) atau Tarik (Otorisasi PIN 6-Digit) (#5, #11)
  void _showSukarelaActionSheet(BuildContext context, MemberModel member) {
    final amountController = TextEditingController(text: '100000');
    final noteController = TextEditingController();
    bool isDepositMode = true;
    String? proofBase64;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SingleChildScrollView(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Simpanan Sukarela',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                  Text(
                    'Saldo: ${CoopService.formatRupiah(member.simpananSukarela)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Toggle Setor vs Tarik
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => isDepositMode = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isDepositMode ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'Setor Sukarela',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDepositMode ? AppTheme.primaryBlue : AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => isDepositMode = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !isDepositMode ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'Tarik Dana Sukarela',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: !isDepositMode ? AppTheme.successGreen : AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Text(
                isDepositMode
                    ? 'Transfer ke Rekening Resmi Koperasi lewat m-Banking, lalu unggah foto bukti transfer agar diverifikasi Bendahara/HRD:'
                    : 'Bisa Ditarik: ${CoopService.formatRupiah(member.maxWithdrawableSukarela)} (Dari Saldo Sukarela ${CoopService.formatRupiah(member.simpananSukarela)}).\nDana akan ditransfer Bendahara ke ${member.bankName} (${member.maskedBankAccount}).',
                style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.35),
              ),
              if (!isDepositMode && member.lockedSukarelaCollateral > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.pastelYellowBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '🔒 Sebesar ${CoopService.formatRupiah(member.lockedSukarelaCollateral)} dikunci sementara sebagai jaminan Sisa Pinjaman Aktif (${CoopService.formatRupiah(member.activeLoanBalance)}).',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textDark, height: 1.35),
                  ),
                ),
              ],
              if (isDepositMode) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlueLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_rounded, color: AppTheme.primaryBlue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.coopService.coopBankName}: ${widget.coopService.coopBankAccountNumber}\na.n. ${widget.coopService.coopBankAccountHolder}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppTheme.primaryBlueDark),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.coopService.coopBankAccountNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('📋 No. Rekening Koperasi (${widget.coopService.coopBankAccountNumber}) disalin!')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('Salin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Nominal Rupiah',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: 'Catatan (Opsional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              if (isDepositMode) ...[
                const SizedBox(height: 12),
                TransferProofPicker(
                  onChanged: (b64) => proofBase64 = b64,
                ),
              ],
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final amt = double.tryParse(
                          amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
                        ) ??
                        0;
                    if (isDepositMode) {
                      if (proofBase64 == null || proofBase64!.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('⚠️ Wajib unggah/masukkan foto bukti transfer terlebih dahulu!'),
                            backgroundColor: AppTheme.dangerRed,
                          ),
                        );
                        return;
                      }
                      if (widget.coopService.hasPendingDeposit(member.id)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('⚠️ Anda masih memiliki pengajuan Setor Sukarela yang menunggu verifikasi Admin/Bendahara!'),
                            backgroundColor: AppTheme.warningOrange,
                          ),
                        );
                        return;
                      }
                      if (amt < 10000 || amt > 50000000) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('❌ Nominal setoran wajib Rp 10.000 s/d Rp 50.000.000!'),
                            backgroundColor: AppTheme.dangerRed,
                          ),
                        );
                        return;
                      }
                      final ok = widget.coopService.depositSukarela(
                        amt,
                        noteController.text,
                        proofImageBase64: proofBase64,
                      );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? '✅ Pengajuan setor ${CoopService.formatRupiah(amt)} beserta foto bukti TF berhasil dikirim!'
                                : '⚠️ Pengajuan gagal atau terlalu cepat.',
                          ),
                          backgroundColor: ok ? AppTheme.successGreen : AppTheme.warningOrange,
                        ),
                      );
                    } else {
                      if (widget.coopService.hasPendingWithdrawal(member.id)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('⚠️ Anda masih memiliki permohonan penarikan sukarela yang menunggu ditransfer Bendahara!'),
                            backgroundColor: AppTheme.warningOrange,
                          ),
                        );
                        return;
                      }
                      if (amt <= 0 || amt > member.maxWithdrawableSukarela) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              member.lockedSukarelaCollateral > 0
                                  ? '❌ Melebihi batas yang bisa ditarik (${CoopService.formatRupiah(member.maxWithdrawableSukarela)}) karena sebagian dikunci sebagai jaminan pinjaman aktif!'
                                  : '❌ Nominal melebihi Saldo Simpanan Sukarela Anda!',
                            ),
                            backgroundColor: AppTheme.dangerRed,
                          ),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      SecurityPinDialog.show(
                        context,
                        coopService: widget.coopService,
                        title: 'Otorisasi PIN Tarik Sukarela',
                        amount: CoopService.formatRupiah(amt),
                        destination: '${member.bankName} (${member.bankAccountNumber})',
                        onVerified: () {
                          final ok = widget.coopService.withdrawSukarela(amt, noteController.text);
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '✅ Permohonan tarik ${CoopService.formatRupiah(amt)} terkirim! Menunggu Bendahara mentransfer ke rekening ${member.bankName} Anda.',
                                ),
                                backgroundColor: AppTheme.successGreen,
                              ),
                            );
                          }
                        },
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDepositMode ? AppTheme.primaryBlue : AppTheme.successGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    isDepositMode ? 'Kirim Setoran Sukarela' : 'Ajukan Penarikan (Verifikasi PIN)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

