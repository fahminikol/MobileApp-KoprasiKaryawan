import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/coop_service.dart';
import '../services/input_sanitizer.dart';
import '../theme/app_theme.dart';
import '../models/member_model.dart';
import '../models/loan_model.dart';
import '../widgets/security_pin_dialog.dart';
import '../widgets/transfer_proof_picker.dart';

class LoanScreen extends StatefulWidget {
  final CoopService coopService;

  const LoanScreen({
    super.key,
    required this.coopService,
  });

  @override
  State<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanScreen> {
  double _loanAmount = 2000000;
  int _tenorMonths = 12; // Maksimal 12 bulan
  final double _interestRateMonthly = 1.0; // 1% flat per bulan
  final _purposeController = TextEditingController();

  @override
  void dispose() {
    _purposeController.dispose();
    super.dispose();
  }

  double get monthlyPrincipal => (_loanAmount / _tenorMonths).roundToDouble();
  double get monthlyInterest =>
      (_loanAmount * (_interestRateMonthly / 100)).roundToDouble();
  double get totalMonthlyInstallment => monthlyPrincipal + monthlyInterest;
  double get totalInterestAllTenor => monthlyInterest * _tenorMonths;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.coopService,
      builder: (context, _) {
        final member = widget.coopService.currentMember;
        final myLoans = widget.coopService.currentMemberLoans;
        final totalMembers = widget.coopService.activeMemberCount;
        final maxLimit = member?.maxLoanLimit ?? 20000000.0;
        const sliderMax = 20000000.0;

        final pendingLoan = myLoans
            .where((l) => l.status == LoanStatus.pending)
            .firstOrNull;
        final activeLoan = myLoans
            .where((l) => l.status == LoanStatus.active && l.remainingBalance > 0)
            .firstOrNull;

        final sharePerMemberMonthly = totalMembers > 0
            ? (monthlyInterest / totalMembers).roundToDouble()
            : 0.0;
        final sharePerMemberTotal = totalMembers > 0
            ? (totalInterestAllTenor / totalMembers).roundToDouble()
            : 0.0;
        final canPop = Navigator.canPop(context);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Pinjaman & Bagi Hasil 1%'),
            automaticallyImplyLeading: false,
            leading: canPop
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => Navigator.maybePop(context),
                  )
                : null,
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kartu Hak Bagi Hasil Bunga 1% Anggota Saat Ini
                if (member != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: AppTheme.cardGradient,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.pie_chart_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Saldo Bagi Hasil Bunga 1% Anda',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Dibagi $totalMembers Anggota Aktif',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          CoopService.formatRupiah(member.saldoBagiHasilBunga),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Estimasi tambahan bulan ini dari pinjaman berjalan: +${CoopService.formatRupiah(widget.coopService.monthlyInterestSharePerMember)} / anggota aktif',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Top Info Banner + Plafon Masa Kerja (#8, #19)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.pastelYellowBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.pastelYellowIcon.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.monetization_on_rounded, color: AppTheme.pastelYellowIcon, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Aturan Pinjaman PT Budi Berlian Motor',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Bunga 1% flat/bln (maks 12 bln) dibagi rata ke seluruh anggota aktif. '
                              'Plafon maksimal Anda (${member?.membershipMonths ?? 1} bln kerja): ${CoopService.formatRupiah(maxLimit)}.',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (pendingLoan != null || activeLoan != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: pendingLoan != null
                          ? AppTheme.pastelYellowBg
                          : AppTheme.primaryBlueLight,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: pendingLoan != null
                            ? AppTheme.warningOrange.withValues(alpha: 0.45)
                            : AppTheme.primaryBlue.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (pendingLoan != null
                                    ? AppTheme.warningOrange
                                    : AppTheme.primaryBlue)
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            pendingLoan != null
                                ? Icons.hourglass_top_rounded
                                : Icons.lock_clock_rounded,
                            color: pendingLoan != null
                                ? AppTheme.warningOrange
                                : AppTheme.primaryBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pendingLoan != null
                                    ? '⏳ Pengajuan Pinjaman Menunggu Persetujuan'
                                    : '🔒 Anda Memiliki Pinjaman Aktif Berjalan',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: pendingLoan != null
                                      ? const Color(0xFFB45309)
                                      : AppTheme.primaryBlueDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pendingLoan != null
                                    ? 'Pinjaman ${CoopService.formatRupiah(pendingLoan.amount)} (${pendingLoan.purpose}) sedang menunggu verifikasi Pengurus. Anda baru dapat mengajukan pinjaman lagi setelah pengajuan ini selesai diproses.'
                                    : 'Pinjaman aktif ${CoopService.formatRupiah(activeLoan!.amount)} (Sisa pokok: ${CoopService.formatRupiah(activeLoan.remainingBalance)}). Lunasi pinjaman berjalan terlebih dahulu untuk mengajukan pinjaman baru.',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textDark,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Simulation Card
                Container(
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
                          const Expanded(
                            child: Text(
                              'Kalkulator & Form Pinjaman',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _loanAmount > maxLimit
                                  ? AppTheme.pastelPinkBg
                                  : AppTheme.primaryBlueLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Plafon Anda: ${CoopService.formatRupiah(maxLimit)}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _loanAmount > maxLimit
                                    ? AppTheme.dangerRed
                                    : AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Nominal Slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Jumlah Pinjaman', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          Text(
                            CoopService.formatRupiah(_loanAmount),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _loanAmount > maxLimit
                                  ? AppTheme.dangerRed
                                  : AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _loanAmount.clamp(500000.0, sliderMax),
                        min: 500000.0,
                        max: sliderMax,
                        divisions: 39,
                        activeColor: _loanAmount > maxLimit
                            ? AppTheme.warningOrange
                            : AppTheme.primaryBlue,
                        onChanged: (val) {
                          setState(() {
                            _loanAmount = val;
                          });
                        },
                      ),
                      // Pilihan Cepat Nominal Pinjaman
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [2000000.0, 5000000.0, 10000000.0, 15000000.0, 20000000.0].map((preset) {
                            final selected = (_loanAmount - preset).abs() < 100;
                            final isOverLimit = preset > maxLimit;
                            final label = 'Rp ${(preset / 1000000).toInt()} Jt';
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () => setState(() => _loanAmount = preset),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? (isOverLimit ? AppTheme.warningOrange : AppTheme.primaryBlue)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selected
                                          ? (isOverLimit ? AppTheme.warningOrange : AppTheme.primaryBlue)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: selected ? Colors.white : AppTheme.textDark,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Tenor Selector (Maksimal 12 Bulan)
                      const Text('Jangka Waktu Angsuran (Maksimal 12 Bulan)', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      const SizedBox(height: 10),
                      Row(
                        children: [1, 3, 6, 9, 12].map((tenor) {
                          final isSelected = _tenorMonths == tenor;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: tenor == 12 ? 0 : 6),
                              child: GestureDetector(
                                onTap: () => setState(() => _tenorMonths = tenor),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.primaryBlue : AppTheme.scaffoldBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? AppTheme.primaryBlue : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$tenor Bln',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : AppTheme.textDark,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const Divider(height: 30),

                      // Results Breakdown
                      _buildSimRow('Pokok Angsuran / Bulan', CoopService.formatRupiah(monthlyPrincipal)),
                      const SizedBox(height: 8),
                      _buildSimRow('Bunga Pinjaman (1% / Bulan)', CoopService.formatRupiah(monthlyInterest)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlueLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Potongan Gaji / Bln:',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryBlueDark),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              CoopService.formatRupiah(totalMonthlyInstallment),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.primaryBlueDark),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Kotak Hijau Distribusi Bunga 1% ke Seluruh Anggota Aktif
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.pastelGreenBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.groups_rounded, size: 16, color: AppTheme.successGreen),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Distribusi Bunga 1% ke $totalMembers Anggota Aktif:',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.successGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '• Bunga ${CoopService.formatRupiah(monthlyInterest)}/bln ÷ $totalMembers anggota aktif = +${CoopService.formatRupiah(sharePerMemberMonthly)} / anggota / bln\n'
                              '• Total selama $_tenorMonths bln (${CoopService.formatRupiah(totalInterestAllTenor)}) = +${CoopService.formatRupiah(sharePerMemberTotal)} / anggota',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textDark,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Purpose Field
                      TextField(
                        controller: _purposeController,
                        decoration: InputDecoration(
                          hintText: 'Keperluan pinjaman (misal: pendidikan, kesehatan, renovasi)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () => _submitLoan(member),
                          icon: const Icon(Icons.lock_outline_rounded, size: 18),
                          label: const Text('Verifikasi PIN & Ajukan Pinjaman', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Loan History + Fitur Pelunasan Dipercepat (#10, #94, #95)
                const Text(
                  'Riwayat & Status Pinjaman Saya',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const SizedBox(height: 12),
                if (myLoans.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: const Center(
                      child: Text('Belum ada riwayat pinjaman.', style: TextStyle(color: AppTheme.textMuted)),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: myLoans.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      final l = myLoans[index];
                      return _buildLoanHistoryCard(context, l, totalMembers);
                    },
                  ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoanHistoryCard(BuildContext context, LoanModel l, int totalMembers) {
    Color badgeBg;
    Color badgeFg;
    switch (l.status) {
      case LoanStatus.active:
      case LoanStatus.approved:
        badgeBg = AppTheme.primaryBlueLight;
        badgeFg = AppTheme.primaryBlue;
        break;
      case LoanStatus.settled:
        badgeBg = AppTheme.pastelGreenBg;
        badgeFg = AppTheme.successGreen;
        break;
      case LoanStatus.rejected:
        badgeBg = AppTheme.pastelPinkBg;
        badgeFg = AppTheme.dangerRed;
        break;
      case LoanStatus.pending:
        badgeBg = AppTheme.pastelYellowBg;
        badgeFg = AppTheme.warningOrange;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l.purpose,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l.statusLabel,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeFg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Pokok Pinjaman: ${CoopService.formatRupiah(l.amount)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Sisa: ${CoopService.formatRupiah(l.remainingBalance)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: l.remainingBalance > 0 ? AppTheme.dangerRed : AppTheme.successGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tenor: ${l.tenorMonths} Bln (Sisa ${l.remainingTenorMonths}x cicilan) • Angsuran: ${CoopService.formatRupiah(l.totalMonthlyInstallment)}/bln',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            'Bagi hasil bunga 1%: +${CoopService.formatRupiah(l.monthlySharePerMember(totalMembers))}/bln ke tiap anggota aktif',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.successGreen,
            ),
          ),
          if (l.status == LoanStatus.active && l.remainingBalance > 0) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlueLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '📅 Jadwal Jatuh Tempo: Dipotong otomatis dari gaji setiap Tanggal 28 sebesar ${CoopService.formatRupiah(l.totalMonthlyInstallment)}/bln. '
                'Pinjaman akan otomatis LUNAS setelah ${l.remainingTenorMonths}x gajian lagi.',
                style: const TextStyle(fontSize: 10.5, color: AppTheme.primaryBlueDark, height: 1.35),
              ),
            ),
          ],
          if (l.status == LoanStatus.rejected && l.rejectionReason != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.pastelPinkBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Alasan Penolakan HRD: "${l.rejectionReason}"',
                style: const TextStyle(fontSize: 11, color: AppTheme.dangerRed, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          if (l.disbursementProofBase64 != null && l.disbursementProofBase64!.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => showTransferProofDialog(
                context,
                l.disbursementProofBase64!,
                title: 'Bukti Transfer Pencairan Pinjaman',
                subtitle: 'Dicairkan sebesar ${CoopService.formatRupiah(l.amount)} oleh ${l.approvedByAdmin ?? "Admin HRD"}',
              ),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlueLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_search_rounded, size: 15, color: AppTheme.primaryBlue),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Lihat Foto Bukti Pencairan dari Admin',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (l.earlySettlementProofBase64 != null && l.earlySettlementProofBase64!.isNotEmpty) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => showTransferProofDialog(
                context,
                l.earlySettlementProofBase64!,
                title: 'Bukti Transfer Pelunasan Pinjaman',
                subtitle: 'Pelunasan Pinjaman (${l.purpose})',
              ),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.pastelGreenBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 15, color: AppTheme.successGreen),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Lihat Foto Bukti Transfer Pelunasan',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (l.status == LoanStatus.active && l.remainingBalance > 0) ...[
            const Divider(height: 20),
            if (l.isPendingEarlySettlement)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.pastelYellowBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '⏳ Pengajuan Pelunasan Dipercepat sedang menunggu verifikasi mutasi bank oleh Admin HRD.',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.warningOrange),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmEarlySettlement(context, l),
                  icon: const Icon(Icons.workspace_premium_rounded, size: 16),
                  label: Text(
                    'Lunasi Dipercepat (${CoopService.formatRupiah(l.remainingBalance + l.monthlyInterest)})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.successGreen,
                    side: const BorderSide(color: AppTheme.successGreen),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _confirmEarlySettlement(BuildContext context, LoanModel loan) {
    final totalPayoff = loan.remainingBalance + loan.monthlyInterest;
    final noteCtrl = TextEditingController();
    final coopBank = widget.coopService.coopBankName;
    final coopRek = widget.coopService.coopBankAccountNumber;
    final coopHolder = widget.coopService.coopBankAccountHolder;
    String? proofBase64;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pelunasan Pinjaman Dipercepat',
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
              const Text(
                '1. Silakan transfer total pelunasan ke Rekening Resmi Koperasi di bawah ini:',
                style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlueLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'REKENING RESMI KOPERASI PT BBM',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.primaryBlue),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$coopBank • $coopRek',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.primaryBlueDark),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: coopRek));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('📋 No. Rekening $coopBank ($coopRek) disalin!')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 15),
                          label: const Text('Salin Rek', style: TextStyle(fontSize: 11.5)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'a.n. $coopHolder',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                    ),
                    const Divider(height: 16),
                    _buildSimRow('Sisa Pokok Pinjaman', CoopService.formatRupiah(loan.remainingBalance)),
                    const SizedBox(height: 4),
                    _buildSimRow('Bunga Berjalan (1%)', CoopService.formatRupiah(loan.monthlyInterest)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Total Transfer: ${CoopService.formatRupiah(totalPayoff)}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: AppTheme.successGreen),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: totalPayoff.toInt().toString()));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('📋 Nominal pelunasan disalin!')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 15),
                          label: const Text('Salin Nominal', style: TextStyle(fontSize: 11.5)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '2. Unggah foto bukti transfer dan isi catatan (opsional) sebelum konfirmasi:',
                style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 8),
              TransferProofPicker(
                onChanged: (b64) => proofBase64 = b64,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Catatan Transfer Bank (Opsional)',
                  hintText: 'Contoh: Sudah TF via BCA Mobile a.n. ${loan.memberName}',
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
              final note = noteCtrl.text.trim();
              Navigator.pop(ctx);
              SecurityPinDialog.show(
                context,
                coopService: widget.coopService,
                title: 'Pelunasan Pinjaman Dipercepat',
                amount: CoopService.formatRupiah(totalPayoff),
                destination: 'Rek. Koperasi: $coopBank ($coopRek)',
                onVerified: () {
                  final ok = widget.coopService.requestEarlyLoanSettlement(
                    loan.id,
                    note: note,
                    proofImageBase64: proofBase64,
                  );
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '✅ Konfirmasi Pelunasan Dipercepat beserta foto bukti TF terkirim! Menunggu verifikasi Admin HRD.',
                        ),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    );
                  }
                },
              );
            },
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
            label: const Text('Sudah Transfer', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        ),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
      ],
    );
  }

  void _showLoanAlertModal({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String badgeText,
    required String title,
    required String description,
    required List<MapEntry<String, String>> details,
    String? primaryActionLabel,
    VoidCallback? onPrimaryAction,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: details.map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            e.key,
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            e.value,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textDark,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  ),
                ),
                if (primaryActionLabel != null && onPrimaryAction != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onPrimaryAction();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        primaryActionLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submitLoan(MemberModel? member) {
    FocusScope.of(context).unfocus();
    if (member == null) return;

    final myLoans = widget.coopService.currentMemberLoans;
    final pendingLoan = myLoans.where((l) => l.status == LoanStatus.pending).firstOrNull;
    final activeLoan = myLoans
        .where((l) => l.status == LoanStatus.active && l.remainingBalance > 0)
        .firstOrNull;

    if (member.status != MemberStatus.active) {
      _showLoanAlertModal(
        icon: Icons.block_rounded,
        color: AppTheme.dangerRed,
        bgColor: AppTheme.pastelPinkBg,
        badgeText: 'STATUS AKUN TERKUNCI',
        title: 'Tidak Dapat Mengajukan Pinjaman',
        description:
            'Akun keanggotaan Anda saat ini berstatus "${member.statusLabel}". Pengajuan pinjaman baru hanya tersedia untuk anggota berstatus Aktif.',
        details: [
          MapEntry('Nama Anggota', member.name),
          MapEntry('Status Saat Ini', member.statusLabel),
          MapEntry('Pinjaman Diajukan', CoopService.formatRupiah(_loanAmount)),
        ],
      );
      return;
    }

    if (pendingLoan != null || widget.coopService.hasPendingLoan(member.id)) {
      final pAmount = pendingLoan?.amount ?? _loanAmount;
      final pPurpose = pendingLoan?.purpose ?? 'Pinjaman Koperasi';
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '⏳ Anda masih memiliki pengajuan pinjaman ${CoopService.formatRupiah(pAmount)} yang belum disetujui Pengurus!',
            ),
            backgroundColor: AppTheme.warningOrange,
          ),
        );
      _showLoanAlertModal(
        icon: Icons.hourglass_top_rounded,
        color: AppTheme.warningOrange,
        bgColor: AppTheme.pastelYellowBg,
        badgeText: 'MENUNGGU PERSETUJUAN PENGURUS',
        title: 'Masih Ada Pinjaman Belum Disetujui',
        description:
            'Anda belum dapat mengajukan pinjaman baru sebesar ${CoopService.formatRupiah(_loanAmount)} karena pengajuan pinjaman Anda sebelumnya sebesar ${CoopService.formatRupiah(pAmount)} masih menunggu verifikasi & pencairan dari Pengurus / HRD.',
        details: [
          MapEntry('Pinjaman Menunggu', CoopService.formatRupiah(pAmount)),
          MapEntry('Keperluan Sebelumnya', pPurpose),
          MapEntry('Pinjaman Baru Diajukan', CoopService.formatRupiah(_loanAmount)),
          const MapEntry('Status Antrean', 'Menunggu Verifikasi HRD'),
        ],
      );
      return;
    }

    if (activeLoan != null || widget.coopService.hasActiveLoan(member.id)) {
      final aAmount = activeLoan?.amount ?? member.activeLoanBalance;
      final aRemaining = activeLoan?.remainingBalance ?? member.activeLoanBalance;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '🔒 Anda masih memiliki pinjaman aktif ${CoopService.formatRupiah(aAmount)} (Sisa: ${CoopService.formatRupiah(aRemaining)}) yang belum lunas!',
            ),
            backgroundColor: AppTheme.warningOrange,
          ),
        );
      _showLoanAlertModal(
        icon: Icons.lock_clock_rounded,
        color: AppTheme.primaryBlue,
        bgColor: AppTheme.primaryBlueLight,
        badgeText: 'BATAS 1 PINJAMAN AKTIF',
        title: 'Pinjaman Sebelumnya Belum Lunas',
        description:
            'Anda tidak dapat mengajukan pinjaman baru sebesar ${CoopService.formatRupiah(_loanAmount)} karena Anda masih memiliki pinjaman aktif yang sedang berjalan. Silakan lunasi pinjaman sebelumnya terlebih dahulu.',
        details: [
          MapEntry('Pinjaman Aktif Saat Ini', CoopService.formatRupiah(aAmount)),
          MapEntry('Sisa Pokok Belum Lunas', CoopService.formatRupiah(aRemaining)),
          MapEntry('Pinjaman Baru Diajukan', CoopService.formatRupiah(_loanAmount)),
        ],
        primaryActionLabel: activeLoan != null && !activeLoan.isPendingEarlySettlement
            ? 'Lunasi Sekarang'
            : null,
        onPrimaryAction: activeLoan != null && !activeLoan.isPendingEarlySettlement
            ? () => _confirmEarlySettlement(context, activeLoan)
            : null,
      );
      return;
    }

    if (_loanAmount > member.maxLoanLimit) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '❌ Nominal ${CoopService.formatRupiah(_loanAmount)} melebihi batas plafon masa kerja Anda (Maks ${CoopService.formatRupiah(member.maxLoanLimit)})!',
            ),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      _showLoanAlertModal(
        icon: Icons.trending_up_rounded,
        color: AppTheme.dangerRed,
        bgColor: AppTheme.pastelPinkBg,
        badgeText: 'MELEBIHI BATAS PLAFON',
        title: 'Melebihi Batas Maksimal Pinjaman',
        description:
            'Pengajuan sebesar ${CoopService.formatRupiah(_loanAmount)} melebihi batas plafon masa kerja Anda (${member.membershipMonths} bulan kerja = Maks ${CoopService.formatRupiah(member.maxLoanLimit)}).',
        details: [
          MapEntry('Nominal yang Diajukan', CoopService.formatRupiah(_loanAmount)),
          MapEntry('Batas Plafon Maksimal Anda', CoopService.formatRupiah(member.maxLoanLimit)),
          MapEntry('Selisih Kelebihan', '+ ${CoopService.formatRupiah(_loanAmount - member.maxLoanLimit)}'),
        ],
        primaryActionLabel: 'Gunakan Maks Plafon',
        onPrimaryAction: () {
          setState(() {
            _loanAmount = member.maxLoanLimit;
          });
        },
      );
      return;
    }

    final loanVal = InputSanitizer.validateLoanApplication(
      amount: _loanAmount,
      tenorMonths: _tenorMonths,
      maxLimit: member.maxLoanLimit,
      purpose: _purposeController.text.trim().isEmpty ? 'Kebutuhan Karyawan' : _purposeController.text,
    );
    if (!loanVal.isValid) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('❌ ${loanVal.errorMessage}'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      return;
    }
    final finalPurpose = loanVal.sanitizedValue;

    // Wajib verifikasi PIN 6-Digit sebelum mengirim pengajuan pinjaman (#23)
    SecurityPinDialog.show(
      context,
      coopService: widget.coopService,
      title: 'Otorisasi PIN Pengajuan Pinjaman',
      amount: CoopService.formatRupiah(_loanAmount),
      destination: 'Tenor $_tenorMonths Bln • Bunga 1%/Bln',
      onVerified: () {
        final success = widget.coopService.applyForLoan(
          member: member,
          amount: _loanAmount,
          tenorMonths: _tenorMonths,
          purpose: finalPurpose,
        );

        if (!success) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              const SnackBar(
                content: Text('🛡️ Pengajuan gagal atau terlalu cepat. Tunggu beberapa detik.'),
                backgroundColor: AppTheme.dangerRed,
              ),
            );
          return;
        }

        _purposeController.clear();
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('✅ Pengajuan pinjaman berhasil dikirim! Menunggu persetujuan HRD.'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
      },
    );
  }
}
