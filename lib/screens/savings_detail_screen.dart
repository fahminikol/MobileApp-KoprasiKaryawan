import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/coop_service.dart';
import '../services/input_sanitizer.dart';
import '../services/pdf_generator.dart';
import '../services/platform_io_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_box.dart';
import '../widgets/security_pin_dialog.dart';
import '../widgets/transfer_proof_picker.dart';
import '../models/member_model.dart';
import '../models/transaction_model.dart';

class SavingsDetailScreen extends StatefulWidget {
  final CoopService coopService;

  const SavingsDetailScreen({
    super.key,
    required this.coopService,
  });

  @override
  State<SavingsDetailScreen> createState() => _SavingsDetailScreenState();
}

class _SavingsDetailScreenState extends State<SavingsDetailScreen> {
  String _selectedFilter = 'ALL'; // ALL, SHU, SUKARELA, WAJIB_POKOK

  List<TransactionModel> _filterTransactions(List<TransactionModel> all) {
    switch (_selectedFilter) {
      case 'SHU':
        return all.where((t) => t.type == TransactionType.bagiHasilBunga).toList();
      case 'SUKARELA':
        return all
            .where((t) =>
                t.type == TransactionType.simpananSukarela ||
                t.type == TransactionType.penarikanSukarela)
            .toList();
      case 'WAJIB_POKOK':
        return all
            .where((t) =>
                t.type == TransactionType.simpananPokok ||
                t.type == TransactionType.simpananWajib)
            .toList();
      default:
        return all;
    }
  }

  String get _filterLabel {
    switch (_selectedFilter) {
      case 'SHU':
        return 'Filter: Khusus Bagi Hasil Bunga 1%';
      case 'SUKARELA':
        return 'Filter: Setor & Tarik Sukarela';
      case 'WAJIB_POKOK':
        return 'Filter: Simpanan Pokok & Wajib';
      default:
        return 'Tahun Buku 2026 • Semua Mutasi';
    }
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

        final allTx = widget.coopService.currentMemberTransactions;
        final transactions = _filterTransactions(allTx);
        final canPop = Navigator.canPop(context);

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBackground,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Top Navigation Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (canPop)
                        GestureDetector(
                          onTap: () => Navigator.maybePop(context),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: AppTheme.textDark,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 42),
                      const Text(
                        'Detail Simpanan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _downloadStatementPDF(context, member),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf_rounded,
                            size: 19,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 2. Interactive Filter Selector (#29)
                  GestureDetector(
                    onTap: () => _showFilterSheet(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      decoration: BoxDecoration(
                        gradient: AppTheme.cardGradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.filter_list_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _filterLabel,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. 2x2 Summary Stat Grid (Menampilkan ke-4 komponen secara lengkap #26)
                  Row(
                    children: [
                      Expanded(
                        child: StatBox(
                          icon: Icons.verified_user_rounded,
                          title: 'Simpanan Pokok',
                          value: CoopService.formatRupiah(member.simpananPokok),
                          subtitle: '1x Potong Awal (Wajib Kembali)',
                          iconColor: AppTheme.primaryBlue,
                          iconBgColor: AppTheme.primaryBlueLight,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: StatBox(
                          icon: Icons.autorenew_rounded,
                          title: 'Simpanan Wajib',
                          value: CoopService.formatRupiah(member.simpananWajib),
                          subtitle: '${member.paidWajibMonths}x Iuran @ Rp 25rb',
                          iconColor: AppTheme.pastelGreenIcon,
                          iconBgColor: AppTheme.pastelGreenBg,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: StatBox(
                          icon: Icons.account_balance_wallet_rounded,
                          title: 'Simpanan Sukarela',
                          value: CoopService.formatRupiah(member.simpananSukarela),
                          subtitle: 'Bebas Setor & Tarik',
                          iconColor: AppTheme.pastelYellowIcon,
                          iconBgColor: AppTheme.pastelYellowBg,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: StatBox(
                          icon: Icons.pie_chart_rounded,
                          title: 'Bagi Hasil Bunga 1%',
                          value: CoopService.formatRupiah(member.saldoBagiHasilBunga),
                          subtitle: 'Jatah Bunga Pinjaman 1%',
                          iconColor: AppTheme.pastelPinkIcon,
                          iconBgColor: AppTheme.pastelPinkBg,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Banner Total Akumulasi + Tombol Cepat Setor & Tarik Sukarela (#11, #26)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Akumulasi Hak Simpanan',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Pokok + Wajib + Sukarela + Bagi Hasil 1%',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 10.5, color: AppTheme.textLight),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              CoopService.formatRupiah(member.totalSavings),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showDepositModal(context, member),
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 17),
                                label: const Text('Setor Sukarela', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryBlue,
                                  side: const BorderSide(color: AppTheme.primaryBlue),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showWithdrawModal(context, member),
                                icon: const Icon(Icons.request_quote_rounded, size: 17),
                                label: const Text('Tarik Sukarela', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.successGreen,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // 4. Ledger / Transaction History Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Riwayat Mutasi Simpanan',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${transactions.length} Transaksi',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (transactions.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Center(
                        child: Text(
                          'Belum ada riwayat transaksi pada kategori ini.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: transactions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        return _buildTransactionCard(tx);
                      },
                    ),

                  const SizedBox(height: 22),

                  // 5. Bottom CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _downloadStatementPDF(context, member),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                      label: const Text(
                        'Lihat & Cetak E-Statement PDF',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
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

  void _showFilterSheet(BuildContext context) {
    final options = [
      {'code': 'ALL', 'label': 'Semua Jenis Transaksi (Lengkap)'},
      {'code': 'SHU', 'label': 'Khusus Bagi Hasil Bunga Pinjaman 1%'},
      {'code': 'SUKARELA', 'label': 'Khusus Setor & Tarik Simpanan Sukarela'},
      {'code': 'WAJIB_POKOK', 'label': 'Khusus Simpanan Pokok & Wajib (Payroll)'},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Kategori Mutasi Simpanan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...options.map((opt) {
              final selected = _selectedFilter == opt['code'];
              return ListTile(
                leading: Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: AppTheme.primaryBlue,
                ),
                title: Text(
                  opt['label']!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  setState(() => _selectedFilter = opt['code']!);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _formatCurrencyField(TextEditingController ctrl, String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      if (ctrl.text.isNotEmpty) {
        ctrl.value = const TextEditingValue(text: '');
      }
      return;
    }
    final formatted = digits.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    if (ctrl.text != formatted) {
      ctrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  void _showDepositModal(BuildContext context, MemberModel member) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? proofBase64;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Setor Simpanan Sukarela', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Silakan transfer dana ke Rekening Resmi Koperasi di bawah ini lewat m-Banking, lalu unggah foto bukti transfer agar diverifikasi Bendahara/HRD.',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlueLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_rounded, color: AppTheme.primaryBlue, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.coopService.coopBankName} • ${widget.coopService.coopBankAccountNumber}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.primaryBlueDark),
                        ),
                        Text(
                          'a.n. ${widget.coopService.coopBankAccountHolder}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textDark),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.coopService.coopBankAccountNumber));
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          SnackBar(content: Text('📋 No. Rekening Koperasi (${widget.coopService.coopBankAccountNumber}) disalin!')),
                        );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: const Text('Salin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              onChanged: (v) => _formatCurrencyField(amountCtrl, v),
              decoration: InputDecoration(
                labelText: 'Nominal Setoran (Min Rp 10.000 - Maks Rp 50 Juta)',
                hintText: 'Contoh: 1.000.000',
                prefixText: 'Rp ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(
                labelText: 'Berita Transfer / Catatan (Opsional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TransferProofPicker(
              onChanged: (b64) => proofBase64 = b64,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (proofBase64 == null || proofBase64!.isEmpty) {
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ Wajib unggah/masukkan foto bukti transfer terlebih dahulu!'),
                          backgroundColor: AppTheme.dangerRed,
                        ),
                      );
                    return;
                  }
                  if (widget.coopService.hasPendingDeposit(member.id)) {
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ Anda masih memiliki pengajuan Setor Sukarela yang menunggu verifikasi Admin/Bendahara!'),
                          backgroundColor: AppTheme.warningOrange,
                        ),
                      );
                    return;
                  }
                  final amt = double.tryParse(amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                  final amtVal = InputSanitizer.validateRupiahAmount(amt, min: 10000, max: 50000000, label: 'Setoran');
                  if (!amtVal.isValid) {
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(
                          content: Text('❌ ${amtVal.errorMessage}'),
                          backgroundColor: AppTheme.dangerRed,
                        ),
                      );
                    return;
                  }
                  final cleanNote = InputSanitizer.sanitizeText(noteCtrl.text, maxLength: 100);
                  final ok = widget.coopService.depositSukarela(
                    amt,
                    cleanNote,
                    proofImageBase64: proofBase64,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? '✅ Pengajuan setor ${CoopService.formatRupiah(amt)} beserta foto bukti TF berhasil dikirim!'
                              : '⚠️ Pengajuan gagal atau terlalu cepat.',
                        ),
                        backgroundColor: ok ? AppTheme.successGreen : AppTheme.warningOrange,
                      ),
                    );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Kirim Bukti Setoran Sukarela', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWithdrawModal(BuildContext context, MemberModel member) {
    final maxWithdraw = member.maxWithdrawableSukarela;
    final lockedCollateral = member.lockedSukarelaCollateral;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tarik Dana Simpanan Sukarela', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Saldo Sukarela: ${CoopService.formatRupiah(member.simpananSukarela)} • Bisa Ditarik: ${CoopService.formatRupiah(maxWithdraw)}\n'
              'Rekening Tujuan Transfer: ${member.bankName} (${member.maskedBankAccount})',
              style: const TextStyle(fontSize: 11.5, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600, height: 1.35),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              onChanged: (v) => _formatCurrencyField(amountCtrl, v),
              decoration: InputDecoration(
                labelText: 'Nominal Penarikan (Maks ${CoopService.formatRupiah(maxWithdraw)})',
                hintText: 'Contoh: 8.000.000',
                prefixText: 'Rp ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(
                labelText: 'Keterangan Penarikan (Opsional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (widget.coopService.hasPendingWithdrawal(member.id)) {
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ Anda masih memiliki permohonan penarikan sukarela yang menunggu ditransfer Bendahara!'),
                          backgroundColor: AppTheme.warningOrange,
                        ),
                      );
                    return;
                  }
                  final amt = double.tryParse(amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                  final amtVal = InputSanitizer.validateRupiahAmount(amt, min: 10000, max: maxWithdraw, label: 'Penarikan');
                  if (!amtVal.isValid) {
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            lockedCollateral > 0 && amt > maxWithdraw
                                ? '❌ Nominal ${CoopService.formatRupiah(amt)} melebihi batas yang bisa ditarik (${CoopService.formatRupiah(maxWithdraw)})!'
                                : '❌ ${amtVal.errorMessage}',
                          ),
                          backgroundColor: AppTheme.dangerRed,
                        ),
                      );
                    return;
                  }
                  ScaffoldMessenger.of(context).clearSnackBars();
                  final cleanNote = InputSanitizer.sanitizeText(noteCtrl.text, maxLength: 100);
                  Navigator.pop(ctx);
                  SecurityPinDialog.show(
                    context,
                    coopService: widget.coopService,
                    title: 'Otorisasi PIN Tarik Sukarela',
                    amount: CoopService.formatRupiah(amt),
                    destination: '${member.bankName} (${member.bankAccountNumber})',
                    onVerified: () {
                      final ok = widget.coopService.withdrawSukarela(amt, cleanNote);
                      if (ok) {
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(
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
                },
                icon: const Icon(Icons.lock_outline_rounded, size: 18),
                label: const Text('Ajukan Penarikan (Verifikasi PIN)', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(TransactionModel tx) {
    final isPending = tx.status == TransactionStatus.pending;
    final isIncoming = tx.isCredit;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPending ? AppTheme.warningOrange.withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isPending
                  ? AppTheme.pastelYellowBg
                  : (isIncoming ? AppTheme.pastelGreenBg : AppTheme.pastelPinkBg),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isPending
                  ? Icons.hourglass_top_rounded
                  : (isIncoming ? Icons.south_west_rounded : Icons.north_east_rounded),
              size: 20,
              color: isPending
                  ? AppTheme.warningOrange
                  : (isIncoming ? AppTheme.successGreen : AppTheme.dangerRed),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.typeLabel,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tx.description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (tx.proofImageBase64 != null && tx.proofImageBase64!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => showTransferProofDialog(
                      context,
                      tx.proofImageBase64!,
                      title: 'Bukti Transfer: ${tx.typeLabel}',
                      subtitle: '${CoopService.formatRupiah(tx.amount)} • ${tx.description}',
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlueLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image_search_rounded, size: 13, color: AppTheme.primaryBlue),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Lihat Foto Bukti Transfer',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
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
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncoming ? '+' : '-'}${CoopService.formatRupiah(tx.amount)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isPending
                      ? AppTheme.warningOrange
                      : (isIncoming ? AppTheme.successGreen : AppTheme.dangerRed),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                CoopService.formatDate(tx.date),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _savePdfFileToDevice(BuildContext context, MemberModel member) async {
    final transactions = widget.coopService.currentMemberTransactions;
    final cleanName = member.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName = 'E-Statement_KOPKAR_${cleanName}_${member.nik}.pdf';

    final pdfBytes = PdfGenerator.generateMemberStatementPdf(
      member: member,
      transactions: transactions,
      coopBankName: widget.coopService.coopBankName,
      coopBankAccountNumber: widget.coopService.coopBankAccountNumber,
    );

    final savedPath = await PlatformStorageHelper.savePdfToDownloads(
      fileName: fileName,
      pdfBytes: pdfBytes,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            savedPath != null
                ? '✅ File PDF berhasil diunduh ke HP: $savedPath'
                : '⚠️ Gagal menyimpan file PDF ke perangkat.',
          ),
          backgroundColor: savedPath != null ? AppTheme.successGreen : AppTheme.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );

    if (savedPath != null) {
      showDialog(
        context: context,
        builder: (dCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'E-Statement PDF Berhasil Diunduh',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dokumen resmi Laporan Simpanan & Pinjaman Anda telah disimpan ke memori perangkat:',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.pastelGreenBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.dangerRed, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Lokasi: $savedPath',
                            style: const TextStyle(fontSize: 11, color: AppTheme.successGreen, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dCtx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  void _downloadStatementPDF(BuildContext context, MemberModel member) {
    final transactions = widget.coopService.currentMemberTransactions;
    final now = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.95,
        minChildSize: 0.6,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Top Action Bar
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf_rounded, color: AppTheme.dangerRed, size: 22),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'E-Statement_KOPKAR_BBM.pdf',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _savePdfFileToDevice(context, member),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Unduh PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryBlue,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Document Paper Area (#68: Menyertakan Sisa Pinjaman & Saldo Bersih)
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'KOPERASI KARYAWAN (KOPKAR)',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.primaryBlue),
                                  ),
                                  Text(
                                    'PT BUDI BERLIAN MOTOR',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textDark),
                                  ),
                                  Text(
                                    'Laporan Resmi Saldo Simpanan, Pinjaman & Bagi Hasil 1%',
                                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.pastelGreenBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'TERVERIFIKASI',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.successGreen),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24, thickness: 1.5),

                        _buildPdfRow('Nama Karyawan', member.name),
                        _buildPdfRow('NIK / Departemen', '${member.nik}  •  ${member.department}'),
                        _buildPdfRow('Rekening Terdaftar', '${member.bankName} - ${member.bankAccountNumber}'),
                        _buildPdfRow('Tanggal Cetak', CoopService.formatDate(now)),
                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              _buildPdfRow('1. Simpanan Pokok (Wajib Kembali)', CoopService.formatRupiah(member.simpananPokok)),
                              _buildPdfRow('2. Simpanan Wajib (${member.paidWajibMonths}x Iuran)', CoopService.formatRupiah(member.simpananWajib)),
                              _buildPdfRow('3. Simpanan Sukarela', CoopService.formatRupiah(member.simpananSukarela)),
                              _buildPdfRow('4. Bagi Hasil Bunga Pinjaman 1%', CoopService.formatRupiah(member.saldoBagiHasilBunga)),
                              const Divider(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text('TOTAL SALDO SIMPANAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.primaryBlue)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(CoopService.formatRupiah(member.totalSavings), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.primaryBlue)),
                                ],
                              ),
                              if (member.activeLoanBalance > 0) ...[
                                const SizedBox(height: 6),
                                _buildPdfRow('Kewajiban Sisa Pinjaman Aktif', '- ${CoopService.formatRupiah(member.activeLoanBalance)}'),
                                const Divider(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Expanded(
                                      child: Text('ESTIMASI HAK BERSIH (NET REFUND)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.successGreen)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      CoopService.formatRupiah((member.totalSavings - member.activeLoanBalance).clamp(0.0, double.infinity)),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.successGreen),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        const Text(
                          'RINCIAN MUTASI TRANSAKSI TERAKHIR:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                        ),
                        const SizedBox(height: 8),
                        ...transactions.take(12).map((tx) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${CoopService.formatDate(tx.date)} • ${tx.description}',
                                      style: const TextStyle(fontSize: 10.5, color: AppTheme.textDark),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${tx.isCredit ? '+' : '-'}${CoopService.formatRupiah(tx.amount)}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: tx.isCredit ? AppTheme.successGreen : AppTheme.dangerRed,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        const Divider(height: 28),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Dokumen Sah Koperasi Karyawan', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                              SizedBox(height: 4),
                              Text('Pengurus KOPKAR PT Budi Berlian Motor', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _savePdfFileToDevice(context, member);
                    },
                    icon: const Icon(Icons.download_for_offline_rounded, size: 20),
                    label: const Text(
                      'Unduh / Simpan File PDF ke HP',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPdfRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              val,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textDark),
            ),
          ),
        ],
      ),
    );
  }
}
