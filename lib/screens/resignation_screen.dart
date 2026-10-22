import 'package:flutter/material.dart';
import '../services/coop_service.dart';
import '../theme/app_theme.dart';
import '../models/member_model.dart';
import '../models/resignation_model.dart';
import '../widgets/security_pin_dialog.dart';

class ResignationScreen extends StatefulWidget {
  final CoopService coopService;

  const ResignationScreen({
    super.key,
    required this.coopService,
  });

  @override
  State<ResignationScreen> createState() => _ResignationScreenState();
}

class _ResignationScreenState extends State<ResignationScreen> {
  final _reasonController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accNumberController = TextEditingController();
  final _accHolderController = TextEditingController();
  String? _loadedMemberId;

  void _syncControllersWithMember(MemberModel member) {
    if (_loadedMemberId != member.id) {
      _loadedMemberId = member.id;
      _bankNameController.text = member.bankName;
      _accNumberController.text = member.bankAccountNumber;
      _accHolderController.text = member.name;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _bankNameController.dispose();
    _accNumberController.dispose();
    _accHolderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.coopService,
      builder: (context, _) {
        final member = widget.coopService.currentMember;
        if (member == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Pastikan rekening selalu sesuai dengan karyawan yang sedang login (#12)
        _syncControllersWithMember(member);

        final existingResignation = widget.coopService.currentMemberResignation;
        final hasLoanShortfall = member.activeLoanBalance > member.totalSavings;
        final shortfallAmount =
            (member.activeLoanBalance - member.totalSavings).clamp(0.0, double.infinity);
        final canPop = Navigator.canPop(context);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Klaim Resign & Pengembalian Dana'),
            automaticallyImplyLeading: false,
            leading: canPop
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => Navigator.maybePop(context),
                  )
                : null,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Highlight Box of the Resignation Rule
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: AppTheme.primaryBlue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aturan Pengembalian Simpanan 100%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Sesuai AD/ART Koperasi PT Budi Berlian Motor: Karyawan yang resign berhak menerima 100% Simpanan Pokok + Simpanan Wajib + Simpanan Sukarela + Saldo Bagi Hasil Bunga 1% (dikurangi sisa pinjaman jika ada).',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // If already submitted, show tracking status card
                if (existingResignation != null) ...[
                  _buildTrackingCard(existingResignation),
                  const SizedBox(height: 24),
                ],

                // Live Calculation Card (Termasuk Saldo Bagi Hasil Bunga 1% #5 & Akurasi Bulan Wajib #38)
                const Text(
                  'Kalkulator Rincian Hak Pengembalian',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: Column(
                    children: [
                      _buildCalcRow(
                        '1. Simpanan Pokok (100% Hak Anda)',
                        CoopService.formatRupiah(member.simpananPokok),
                        badge: '1x Bayar',
                      ),
                      const Divider(height: 20),
                      _buildCalcRow(
                        '2. Simpanan Wajib (${member.paidWajibMonths}x Iuran)',
                        CoopService.formatRupiah(member.simpananWajib),
                        badge: 'Rp 25.000 / bln',
                      ),
                      const Divider(height: 20),
                      _buildCalcRow(
                        '3. Simpanan Sukarela',
                        CoopService.formatRupiah(member.simpananSukarela),
                      ),
                      const Divider(height: 20),
                      _buildCalcRow(
                        '4. Saldo Bagi Hasil Bunga 1%',
                        CoopService.formatRupiah(member.saldoBagiHasilBunga),
                        badge: 'SHU 1%',
                      ),
                      if (member.activeLoanBalance > 0) ...[
                        const Divider(height: 20),
                        _buildCalcRow(
                          '5. Potongan Sisa Pinjaman Aktif',
                          '- ${CoopService.formatRupiah(member.activeLoanBalance)}',
                          isDeduction: true,
                        ),
                      ],
                      const Divider(height: 24, thickness: 1.5),
                      _buildCalcRow(
                        'Total Dana Cair Bersih (Net Refund)',
                        CoopService.formatRupiah(
                          (member.totalSavings - member.activeLoanBalance)
                              .clamp(0.0, double.infinity),
                        ),
                        isHighlight: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Peringatan jika hutang pinjaman lebih besar dari total tabungan (#9)
                if (hasLoanShortfall)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.pastelPinkBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: AppTheme.dangerRed, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Sisa Pinjaman Melebihi Total Tabungan!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.dangerRed,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Total tabungan Anda (${CoopService.formatRupiah(member.totalSavings)}) belum mencukupi untuk menutup sisa pinjaman (${CoopService.formatRupiah(member.activeLoanBalance)}). '
                          'Terdapat kurang bayar sebesar ${CoopService.formatRupiah(shortfallAmount)}. Silakan lunasi pinjaman di menu Pinjaman sebelum mengajukan klaim resign.',
                          style: const TextStyle(fontSize: 11.5, color: AppTheme.textDark, height: 1.4),
                        ),
                      ],
                    ),
                  ),

                // Form Pengajuan (Show only if not yet submitted and active)
                if (existingResignation == null && member.status == MemberStatus.active) ...[
                  const Text(
                    'Formulir Rekening Pencairan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nama Bank Penerima',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _bankNameController,
                          decoration: InputDecoration(
                            hintText: 'Misal: BCA / Mandiri / BRI / BNI',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Nomor Rekening (Min. 8 Digit Angka)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _accNumberController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Masukkan nomor rekening penerima',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Nama Pemilik Rekening (Sesuai KTP/NIK)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _accHolderController,
                          readOnly: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Alasan Resign',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _reasonController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Contoh: Habis kontrak / Pindah domisili / Wiraswasta',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: hasLoanShortfall
                                ? null
                                : () => _submitResignClaim(context, member),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.dangerRed,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              hasLoanShortfall
                                  ? 'Wajib Lunasi Selisih Pinjaman Dahulu'
                                  : 'Ajukan Klaim Pengembalian Simpanan',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalcRow(
    String label,
    String value, {
    bool isHighlight = false,
    bool isDeduction = false,
    String? badge,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isHighlight ? 14 : 13,
                    fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w500,
                    color: isHighlight ? AppTheme.textDark : AppTheme.textMuted,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlueLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 16 : 13,
            fontWeight: FontWeight.w800,
            color: isHighlight
                ? AppTheme.primaryBlue
                : (isDeduction ? AppTheme.dangerRed : AppTheme.textDark),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingCard(ResignationModel rsg) {
    return Container(
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
              const Text(
                'Status Pengajuan Resign',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: rsg.status == ResignationStatus.disbursed
                      ? AppTheme.pastelGreenBg
                      : AppTheme.pastelYellowBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  rsg.statusBadgeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: rsg.status == ResignationStatus.disbursed
                        ? AppTheme.successGreen
                        : AppTheme.warningOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Klaim pengembalian dana bersih sebesar ${CoopService.formatRupiah(rsg.netRefund)} (termasuk Bagi Hasil Bunga 1% ${CoopService.formatRupiah(rsg.saldoBagiHasilRefund)}) ditujukan ke rekening ${rsg.destinationBank} (${rsg.destinationAccountNumber}) a.n ${rsg.destinationAccountHolder}.',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }

  void _submitResignClaim(BuildContext context, MemberModel member) {
    FocusScope.of(context).unfocus();
    final cleanAcc = _accNumberController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanAcc.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Nomor rekening penerima wajib minimal 8 digit angka!'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    final netRefund =
        (member.totalSavings - member.activeLoanBalance).clamp(0.0, double.infinity);

    SecurityPinDialog.show(
      context,
      coopService: widget.coopService,
      title: 'Konfirmasi PIN Klaim Resign',
      amount: CoopService.formatRupiah(netRefund),
      destination: '${_bankNameController.text.trim()} ($cleanAcc)',
      onVerified: () {
        final ok = widget.coopService.submitResignation(
          member: member,
          effectiveDate: DateTime.now().add(const Duration(days: 14)),
          reason: _reasonController.text.trim().isEmpty
              ? 'Pengunduran diri karyawan'
              : _reasonController.text.trim(),
          bankName: _bankNameController.text.trim(),
          accountNumber: cleanAcc,
          accountHolder: member.name,
        );

        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Pengajuan klaim pengembalian simpanan berhasil dikirim! Menunggu verifikasi HRD.'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      },
    );
  }
}
