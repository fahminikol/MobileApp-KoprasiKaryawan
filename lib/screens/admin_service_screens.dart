import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/loan_model.dart';
import '../models/member_model.dart';
import '../models/resignation_model.dart';
import '../models/transaction_model.dart';
import '../services/coop_service.dart';
import '../services/pdf_generator.dart';
import '../services/platform_io_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/transfer_proof_picker.dart';

bool _checkAdminRole(
  BuildContext context,
  bool allowed,
  String requiredLabel,
) {
  if (allowed) return true;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(
          '🔒 Akses Dibatasi: Fitur ini membutuhkan hak akses $requiredLabel.',
        ),
        backgroundColor: AppTheme.dangerRed,
      ),
    );
  return false;
}

Widget _buildHeaderBanner({
  required IconData icon,
  required String title,
  required String subtitle,
  required List<Color> gradientColors,
  required List<MapEntry<String, String>> stats,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors,
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: AppTheme.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (stats.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: stats.map((entry) {
                return Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _buildEmptyState(String message, {IconData icon = Icons.inbox_rounded}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 38, color: AppTheme.textLight),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.4),
        ),
      ],
    ),
  );
}

// ============================================================================
// 1. HALAMAN EKSEKUSI PAYROLL BULANAN (ADMIN PAYROLL SCREEN)
// ============================================================================
class AdminPayrollScreen extends StatefulWidget {
  final CoopService coopService;
  const AdminPayrollScreen({super.key, required this.coopService});

  @override
  State<AdminPayrollScreen> createState() => _AdminPayrollScreenState();
}

class _AdminPayrollScreenState extends State<AdminPayrollScreen> {
  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
  }

  @override
  Widget build(BuildContext context) {
    final coop = widget.coopService;
    return ListenableBuilder(
      listenable: coop,
      builder: (context, _) {
        final alreadyExecuted =
            coop.isPayrollExecutedFor(_selectedMonth, _selectedYear);
        final previewRows = coop.getMonthlyPayrollPreview(
          month: _selectedMonth,
          year: _selectedYear,
        );
        final totalPotongan = previewRows.fold<double>(
          0.0,
          (sum, r) => sum + (r['totalDeduction'] as num).toDouble(),
        );
        final totalBunga = previewRows.fold<double>(
          0.0,
          (sum, r) => sum + (r['loanInterest'] as num).toDouble(),
        );

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBackground,
          appBar: AppBar(
            title: const Text('Manajemen Payroll Bulanan'),
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderBanner(
                  icon: Icons.calendar_month_rounded,
                  title:
                      'Payroll Periode ${CoopService.formatMonthYear(_selectedMonth, _selectedYear)}',
                  subtitle:
                      'Otomatisasi potongan Simpanan Pokok, Wajib, Angsuran Pinjaman & Distribusi Bunga 1%',
                  gradientColors: const [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                  stats: [
                    MapEntry('Anggota Aktif', '${previewRows.length} Karyawan'),
                    MapEntry('Total Potongan', CoopService.formatRupiah(totalPotongan)),
                    MapEntry('Bunga 1% Dibagi', CoopService.formatRupiah(totalBunga)),
                  ],
                ),
                const SizedBox(height: 18),

                // Pemilih Periode Bulan & Tahun Interaktif
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pilih Periode Eksekusi Gajian',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<int>(
                              initialValue: _selectedMonth,
                              decoration: InputDecoration(
                                labelText: 'Bulan',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              items: List.generate(12, (index) {
                                final m = index + 1;
                                return DropdownMenuItem(
                                  value: m,
                                  child: Text(
                                    CoopService.formatMonthYear(m, _selectedYear)
                                        .split(' ')
                                        .first,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                );
                              }),
                              onChanged: (v) {
                                if (v != null) setState(() => _selectedMonth = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<int>(
                              initialValue: _selectedYear,
                              decoration: InputDecoration(
                                labelText: 'Tahun',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              items: [2025, 2026, 2027].map((y) {
                                return DropdownMenuItem(
                                  value: y,
                                  child: Text('$y', style: const TextStyle(fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _selectedYear = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: alreadyExecuted
                              ? null
                              : () {
                                  if (!_checkAdminRole(
                                    context,
                                    coop.currentAdmin?.canExecutePayroll ?? true,
                                    'Super Admin / Bendahara [admin:payroll:execute]',
                                  )) {
                                    return;
                                  }
                                  final res = coop.executeMonthlyPayrollBatch(
                                    month: _selectedMonth,
                                    year: _selectedYear,
                                  );
                                  if (res['alreadyExecuted'] == true) return;
                                  ScaffoldMessenger.of(context)
                                    ..clearSnackBars()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '✅ Payroll ${CoopService.formatMonthYear(_selectedMonth, _selectedYear)} berhasil dieksekusi! Total potongan: ${CoopService.formatRupiah((res['totalDeducted'] as num).toDouble())}',
                                        ),
                                        backgroundColor: AppTheme.successGreen,
                                      ),
                                    );
                                },
                          icon: Icon(
                            alreadyExecuted
                                ? Icons.check_circle_rounded
                                : Icons.flash_on_rounded,
                            size: 18,
                          ),
                          label: Text(
                            alreadyExecuted
                                ? 'Periode ${CoopService.formatMonthYear(_selectedMonth, _selectedYear)} Sudah Dieksekusi ✓'
                                : 'Eksekusi Potongan Payroll Sekarang',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Rincian Simulasi Potongan per Anggota Aktif',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                if (previewRows.isEmpty)
                  _buildEmptyState('Belum ada anggota aktif untuk diproses payroll.')
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: previewRows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, idx) {
                      final r = previewRows[idx];
                      final isFirst = r['isFirstMonth'] == true;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
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
                                    '${r['name']} (${r['nik']})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isFirst
                                        ? AppTheme.pastelYellowBg
                                        : AppTheme.primaryBlueLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isFirst ? 'Gajian Perdana' : 'Rutin Bulanan',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isFirst
                                          ? AppTheme.warningOrange
                                          : AppTheme.primaryBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Pokok: ${CoopService.formatRupiah((r['pokok'] as num).toDouble())}  •  '
                              'Wajib: ${CoopService.formatRupiah((r['wajib'] as num).toDouble())}  •  '
                              'Cicilan Pinjaman: ${CoopService.formatRupiah((r['loanInstallment'] as num).toDouble())}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            const Divider(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Potong Gaji:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  CoopService.formatRupiah(
                                    (r['totalDeduction'] as num).toDouble(),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.primaryBlue,
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
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// 2. HALAMAN PERSETUJUAN & MANAJEMEN PINJAMAN (ADMIN LOAN APPROVAL SCREEN)
// ============================================================================
class AdminLoanApprovalScreen extends StatefulWidget {
  final CoopService coopService;
  const AdminLoanApprovalScreen({super.key, required this.coopService});

  @override
  State<AdminLoanApprovalScreen> createState() =>
      _AdminLoanApprovalScreenState();
}

class _AdminLoanApprovalScreenState extends State<AdminLoanApprovalScreen> {
  String _filter = 'PENDING'; // PENDING, ACTIVE, SETTLED, ALL
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final coop = widget.coopService;
    return ListenableBuilder(
      listenable: coop,
      builder: (context, _) {
        final allLoans = coop.loans.reversed.toList();
        final pendingCount =
            allLoans.where((l) => l.status == LoanStatus.pending).length;
        final activeCount =
            allLoans.where((l) => l.status == LoanStatus.active).length;

        final filtered = allLoans.where((l) {
          if (_filter == 'PENDING' && l.status != LoanStatus.pending) {
            return false;
          }
          if (_filter == 'ACTIVE' && l.status != LoanStatus.active) {
            return false;
          }
          if (_filter == 'SETTLED' && l.status != LoanStatus.settled) {
            return false;
          }
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            return l.memberName.toLowerCase().contains(q) ||
                l.purpose.toLowerCase().contains(q);
          }
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBackground,
          appBar: AppBar(
            title: const Text('Persetujuan & Data Pinjaman'),
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderBanner(
                  icon: Icons.monetization_on_rounded,
                  title: 'Manajemen Pinjaman Anggota',
                  subtitle:
                      'Verifikasi pengajuan, transfer pencairan & pantau cicilan bunga 1%',
                  gradientColors: const [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  stats: [
                    MapEntry('Menunggu', '$pendingCount Pengajuan'),
                    MapEntry('Pinjaman Aktif', '$activeCount Berjalan'),
                    MapEntry(
                      'Total Beredar',
                      CoopService.formatRupiah(coop.totalOutstandingLoans),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search & Filter Bar
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Cari nama karyawan atau keperluan pinjaman...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabChip('PENDING', 'Menunggu ($pendingCount)'),
                      const SizedBox(width: 8),
                      _buildTabChip('ACTIVE', 'Aktif ($activeCount)'),
                      const SizedBox(width: 8),
                      _buildTabChip('SETTLED', 'Sudah Lunas'),
                      const SizedBox(width: 8),
                      _buildTabChip('ALL', 'Semua (${allLoans.length})'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (filtered.isEmpty)
                  _buildEmptyState('Tidak ada data pinjaman pada kategori ini.')
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) {
                      final l = filtered[idx];
                      final borrower = coop.members
                          .where(
                            (m) =>
                                m.id == l.memberId ||
                                m.name.toLowerCase() ==
                                    l.memberName.toLowerCase(),
                          )
                          .firstOrNull;
                      return _buildLoanItemCard(context, l, borrower);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabChip(String key, String label) {
    final selected = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryBlue : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : AppTheme.textDark,
          ),
        ),
      ),
    );
  }

  Widget _buildLoanItemCard(
    BuildContext context,
    LoanModel l,
    MemberModel? borrower,
  ) {
    final coop = widget.coopService;
    final isPending = l.status == LoanStatus.pending;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPending
              ? AppTheme.warningOrange.withValues(alpha: 0.45)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l.memberName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              Text(
                CoopService.formatRupiah(l.amount),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Keperluan: ${l.purpose} • Tenor: ${l.tenorMonths} Bln • Angsuran: ${CoopService.formatRupiah(l.totalMonthlyInstallment)}/bln',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          if (borrower != null) ...[
            const SizedBox(height: 6),
            Text(
              'Rekening Tujuan: ${borrower.bankName} - ${borrower.bankAccountNumber} a.n. ${borrower.name}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryBlueDark,
              ),
            ),
          ],
          if (l.disbursementProofBase64 != null &&
              l.disbursementProofBase64!.isNotEmpty) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => showTransferProofDialog(
                context,
                l.disbursementProofBase64!,
                title: 'Bukti Transfer Pencairan Pinjaman (${l.memberName})',
                subtitle: 'Nominal: ${CoopService.formatRupiah(l.amount)}',
              ),
              icon: const Icon(Icons.image_search_rounded, size: 15),
              label: const Text(
                'Lihat Foto Bukti Transfer Pencairan',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRejectDialog(context, coop, l),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.dangerRed,
                      side: const BorderSide(color: AppTheme.dangerRed),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showDisburseDialog(context, coop, l, borrower),
                    icon: const Icon(Icons.send_to_mobile_rounded, size: 16),
                    label: const Text('Proses Transfer & Cairkan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showRejectDialog(
    BuildContext context,
    CoopService coop,
    LoanModel loan,
  ) {
    if (!_checkAdminRole(
      context,
      coop.currentAdmin?.canApproveFinance ?? true,
      'Super Admin / Ketua / Bendahara [admin:finance:approve]',
    )) {
      return;
    }
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Tolak Pinjaman ${loan.memberName}'),
        content: TextField(
          controller: reasonCtrl,
          decoration: InputDecoration(
            labelText: 'Alasan Penolakan',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              coop.rejectLoan(
                loan.id,
                reasonCtrl.text.trim().isEmpty
                    ? 'Belum memenuhi syarat kelayakan pinjaman'
                    : reasonCtrl.text.trim(),
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Pengajuan pinjaman ${loan.memberName} ditolak.'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Konfirmasi Tolak'),
          ),
        ],
      ),
    );
  }

  void _showDisburseDialog(
    BuildContext context,
    CoopService coop,
    LoanModel loan,
    MemberModel? borrower,
  ) {
    if (!_checkAdminRole(
      context,
      coop.currentAdmin?.canApproveFinance ?? true,
      'Super Admin / Ketua / Bendahara [admin:finance:approve]',
    )) {
      return;
    }
    String? proofBase64;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Pencairan Transfer Pinjaman',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transfer sebesar ${CoopService.formatRupiah(loan.amount)} ke rekening ${borrower?.bankName ?? "Bank"} (${borrower?.bankAccountNumber ?? "-"}) a.n. ${loan.memberName}, lalu unggah bukti transfer:',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              TransferProofPicker(onChanged: (b64) => proofBase64 = b64),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (proofBase64 == null || proofBase64!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ Wajib unggah foto bukti transfer pencairan!'),
                    backgroundColor: AppTheme.dangerRed,
                  ),
                );
                return;
              }
              coop.approveLoan(loan.id, proofImageBase64: proofBase64);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✅ Pinjaman ${CoopService.formatRupiah(loan.amount)} (${loan.memberName}) berhasil dicairkan!',
                  ),
                  backgroundColor: AppTheme.successGreen,
                ),
              );
            },
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
            label: const Text('Konfirmasi Cairkan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. HALAMAN SETOR & TARIK SIMPANAN SUKARELA (ADMIN SAVINGS APPROVAL SCREEN)
// ============================================================================
class AdminSavingsApprovalScreen extends StatefulWidget {
  final CoopService coopService;
  const AdminSavingsApprovalScreen({super.key, required this.coopService});

  @override
  State<AdminSavingsApprovalScreen> createState() =>
      _AdminSavingsApprovalScreenState();
}

class _AdminSavingsApprovalScreenState
    extends State<AdminSavingsApprovalScreen> {
  String _tab = 'WITHDRAW'; // WITHDRAW, DEPOSIT, HISTORY

  @override
  Widget build(BuildContext context) {
    final coop = widget.coopService;
    return ListenableBuilder(
      listenable: coop,
      builder: (context, _) {
        final pendingDep = coop.pendingDeposits;
        final pendingWd = coop.pendingWithdrawals;
        final history = coop.transactions
            .where(
              (t) =>
                  (t.type == TransactionType.simpananSukarela ||
                      t.type == TransactionType.penarikanSukarela) &&
                  t.status == TransactionStatus.success,
            )
            .toList()
            .reversed
            .toList();

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBackground,
          appBar: AppBar(
            title: const Text('Verifikasi Setor & Tarik Sukarela'),
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderBanner(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Mutasi Simpanan Sukarela Anggota',
                  subtitle:
                      'Verifikasi bukti setoran masuk & proses transfer penarikan dana sukarela',
                  gradientColors: const [Color(0xFF065F46), Color(0xFF059669)],
                  stats: [
                    MapEntry('Tarik Pending', '${pendingWd.length} Antrean'),
                    MapEntry('Setor Pending', '${pendingDep.length} Antrean'),
                    MapEntry('Riwayat Selesai', '${history.length} Transaksi'),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildModeButton(
                        'WITHDRAW',
                        'Tarik (${pendingWd.length})',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildModeButton(
                        'DEPOSIT',
                        'Setor (${pendingDep.length})',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildModeButton(
                        'HISTORY',
                        'Riwayat (${history.length})',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_tab == 'WITHDRAW') ...[
                  if (pendingWd.isEmpty)
                    _buildEmptyState(
                      'Tidak ada permohonan tarik simpanan sukarela yang menunggu ditransfer.',
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pendingWd.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final wd = pendingWd[idx];
                        final member = coop.members
                            .where(
                              (m) =>
                                  m.id == wd.memberId ||
                                  m.name.toLowerCase() ==
                                      wd.memberName.toLowerCase(),
                            )
                            .firstOrNull;
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppTheme.primaryBlueLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      wd.memberName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    CoopService.formatRupiah(wd.amount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Keterangan: ${wd.description} • ${CoopService.formatDate(wd.date)}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              if (member != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Transfer ke: ${member.bankName} - ${member.bankAccountNumber} a.n. ${member.name}\n'
                                  'Saldo Sukarela Saat Ini: ${CoopService.formatRupiah(member.simpananSukarela)}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryBlueDark,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        if (!_checkAdminRole(
                                          context,
                                          coop.currentAdmin?.canApproveFinance ??
                                              true,
                                          'Bendahara / Super Admin',
                                        )) {
                                          return;
                                        }
                                        coop.rejectPendingWithdrawal(wd.id);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Penarikan ${wd.memberName} ditolak.',
                                            ),
                                          ),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.dangerRed,
                                        side: const BorderSide(
                                          color: AppTheme.dangerRed,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text('Tolak'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _showDisburseWithdrawalDialog(
                                        context,
                                        coop,
                                        wd,
                                        member,
                                      ),
                                      icon: const Icon(
                                        Icons.send_to_mobile_rounded,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Proses Transfer & Cairkan',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryBlue,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
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
                ] else if (_tab == 'DEPOSIT') ...[
                  if (pendingDep.isEmpty)
                    _buildEmptyState(
                      'Tidak ada setoran simpanan sukarela yang menunggu verifikasi.',
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pendingDep.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final dep = pendingDep[idx];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppTheme.primaryBlueLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      dep.memberName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '+${CoopService.formatRupiah(dep.amount)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: AppTheme.successGreen,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Catatan: ${dep.description} • ${CoopService.formatDate(dep.date)}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              if (dep.proofImageBase64 != null &&
                                  dep.proofImageBase64!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => showTransferProofDialog(
                                    context,
                                    dep.proofImageBase64!,
                                    title:
                                        'Bukti Transfer Setor Sukarela (${dep.memberName})',
                                    subtitle:
                                        'Nominal: ${CoopService.formatRupiah(dep.amount)}',
                                  ),
                                  icon: const Icon(
                                    Icons.image_search_rounded,
                                    size: 15,
                                  ),
                                  label: const Text(
                                    'Lihat Foto Bukti Transfer',
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        if (!_checkAdminRole(
                                          context,
                                          coop.currentAdmin
                                                  ?.canVerifyBankMutation ??
                                              true,
                                          'Bendahara / Super Admin',
                                        )) {
                                          return;
                                        }
                                        coop.rejectPendingDeposit(dep.id);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Setoran ${dep.memberName} ditolak.',
                                            ),
                                          ),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.dangerRed,
                                        side: const BorderSide(
                                          color: AppTheme.dangerRed,
                                        ),
                                      ),
                                      child: const Text('Tolak'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        if (!_checkAdminRole(
                                          context,
                                          coop.currentAdmin
                                                  ?.canVerifyBankMutation ??
                                              true,
                                          'Bendahara / Super Admin',
                                        )) {
                                          return;
                                        }
                                        coop.approvePendingDeposit(dep.id);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '✅ Setoran ${CoopService.formatRupiah(dep.amount)} (${dep.memberName}) diverifikasi!',
                                            ),
                                            backgroundColor:
                                                AppTheme.successGreen,
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.successGreen,
                                        foregroundColor: Colors.white,
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
                ] else ...[
                  if (history.isEmpty)
                    _buildEmptyState('Belum ada riwayat transaksi selesai.')
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final tx = history[idx];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${tx.memberName} • ${tx.typeLabel}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${tx.isCredit ? '+' : '-'}${CoopService.formatRupiah(tx.amount)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: tx.isCredit
                                          ? AppTheme.successGreen
                                          : AppTheme.dangerRed,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${tx.description} • ${CoopService.formatDate(tx.date)}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              if (tx.proofImageBase64 != null &&
                                  tx.proofImageBase64!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => showTransferProofDialog(
                                    context,
                                    tx.proofImageBase64!,
                                    title:
                                        'Bukti Transfer: ${tx.typeLabel} (${tx.memberName})',
                                    subtitle:
                                        'Nominal: ${CoopService.formatRupiah(tx.amount)}',
                                  ),
                                  icon: const Icon(
                                    Icons.image_search_rounded,
                                    size: 15,
                                  ),
                                  label: const Text(
                                    'Lihat Foto Bukti Transfer',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeButton(String key, String label) {
    final selected = _tab == key;
    return GestureDetector(
      onTap: () => setState(() => _tab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primaryBlue : const Color(0xFFE2E8F0),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : AppTheme.textDark,
            ),
          ),
        ),
      ),
    );
  }

  void _showDisburseWithdrawalDialog(
    BuildContext context,
    CoopService coop,
    TransactionModel wd,
    MemberModel? member,
  ) {
    if (!_checkAdminRole(
      context,
      coop.currentAdmin?.canApproveFinance ?? true,
      'Bendahara / Super Admin [admin:finance:approve]',
    )) {
      return;
    }
    String? proofBase64;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Pencairan Tarik Simpanan Sukarela',
          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transfer sebesar ${CoopService.formatRupiah(wd.amount)} ke rekening ${member?.bankName ?? "Bank"} (${member?.bankAccountNumber ?? "-"}) a.n. ${wd.memberName}, lalu unggah bukti transfer:',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              TransferProofPicker(onChanged: (b64) => proofBase64 = b64),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (proofBase64 == null || proofBase64!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ Wajib unggah foto bukti transfer!'),
                    backgroundColor: AppTheme.dangerRed,
                  ),
                );
                return;
              }
              final ok = coop.approvePendingWithdrawal(
                wd.id,
                proofImageBase64: proofBase64,
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? '✅ Penarikan ${CoopService.formatRupiah(wd.amount)} (${wd.memberName}) berhasil dicairkan!'
                        : '❌ Saldo simpanan sukarela anggota tidak mencukupi!',
                  ),
                  backgroundColor:
                      ok ? AppTheme.successGreen : AppTheme.dangerRed,
                ),
              );
            },
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
            label: const Text('Konfirmasi Cairkan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. HALAMAN KLAIM RESIGN & PENCAIRAN 100% HAK DANA (ADMIN RESIGNATION SCREEN)
// ============================================================================
class AdminResignationScreen extends StatelessWidget {
  final CoopService coopService;
  const AdminResignationScreen({super.key, required this.coopService});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: coopService,
      builder: (context, _) {
        final list = coopService.resignations.reversed.toList();
        final pendingCount = list
            .where(
              (r) =>
                  r.status != ResignationStatus.disbursed &&
                  r.status != ResignationStatus.rejected,
            )
            .length;

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBackground,
          appBar: AppBar(
            title: const Text('Klaim Resign & Pencairan Hak Dana'),
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderBanner(
                  icon: Icons.exit_to_app_rounded,
                  title: 'Pengajuan Resign & Refund 100% Hak Simpanan',
                  subtitle:
                      'Pencairan Simpanan Pokok + Wajib + Sukarela + Bagi Hasil 1% dikurangi sisa pinjaman',
                  gradientColors: const [Color(0xFF9A3412), Color(0xFFEA580C)],
                  stats: [
                    MapEntry('Menunggu Cair', '$pendingCount Klaim'),
                    MapEntry('Total Pengajuan', '${list.length} Riwayat'),
                  ],
                ),
                const SizedBox(height: 18),
                if (list.isEmpty)
                  _buildEmptyState('Belum ada pengajuan klaim resign.')
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) {
                      final r = list[idx];
                      final isPending =
                          r.status != ResignationStatus.disbursed &&
                          r.status != ResignationStatus.rejected;
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
                                    '${r.memberName} (${r.memberNik})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Text(
                                  CoopService.formatRupiah(r.netRefund),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: AppTheme.successGreen,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Alasan: ${r.reason}\n'
                              'Rekening Tujuan: ${r.destinationBank} - ${r.destinationAccountNumber} a.n. ${r.destinationAccountHolder}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textMuted,
                                height: 1.4,
                              ),
                            ),
                            if (r.disbursementProofBase64 != null &&
                                r.disbursementProofBase64!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => showTransferProofDialog(
                                  context,
                                  r.disbursementProofBase64!,
                                  title:
                                      'Bukti Transfer Refund Resign (${r.memberName})',
                                  subtitle:
                                      'Net Refund: ${CoopService.formatRupiah(r.netRefund)}',
                                ),
                                icon: const Icon(
                                  Icons.image_search_rounded,
                                  size: 15,
                                ),
                                label: const Text(
                                  'Lihat Foto Bukti Transfer Refund',
                                ),
                              ),
                            ],
                            if (isPending) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        if (!_checkAdminRole(
                                          context,
                                          coopService.currentAdmin
                                                  ?.canApproveFinance ??
                                              true,
                                          'Super Admin / Ketua / Bendahara',
                                        )) {
                                          return;
                                        }
                                        coopService.rejectResignation(
                                          r.id,
                                          'Ditolak oleh Pengurus',
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.dangerRed,
                                        side: const BorderSide(
                                          color: AppTheme.dangerRed,
                                        ),
                                      ),
                                      child: const Text('Tolak'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _showDisburseResignDialog(context, r),
                                      icon: const Icon(
                                        Icons.send_to_mobile_rounded,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Transfer & Cairkan 100%',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.successGreen,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDisburseResignDialog(BuildContext context, ResignationModel r) {
    if (!_checkAdminRole(
      context,
      coopService.currentAdmin?.canApproveFinance ?? true,
      'Super Admin / Ketua / Bendahara [admin:finance:approve]',
    )) {
      return;
    }
    String? proofBase64;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Pencairan Refund Resign',
          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transfer Net Refund sebesar ${CoopService.formatRupiah(r.netRefund)} ke ${r.destinationBank} (${r.destinationAccountNumber}) a.n. ${r.destinationAccountHolder}, lalu unggah bukti transfer:',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              TransferProofPicker(onChanged: (b64) => proofBase64 = b64),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (proofBase64 == null || proofBase64!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ Wajib unggah foto bukti transfer!'),
                    backgroundColor: AppTheme.dangerRed,
                  ),
                );
                return;
              }
              coopService.approveAndDisburseResignation(
                r.id,
                proofImageBase64: proofBase64,
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✅ Refund resign ${r.memberName} berhasil dicairkan!',
                  ),
                  backgroundColor: AppTheme.successGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Konfirmasi Cairkan'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 5. HALAMAN REKAP GAJI FINANCE & UNDUH PDF (ADMIN PAYROLL RECAP SCREEN)
// ============================================================================
class AdminPayrollRecapScreen extends StatefulWidget {
  final CoopService coopService;
  const AdminPayrollRecapScreen({super.key, required this.coopService});

  @override
  State<AdminPayrollRecapScreen> createState() =>
      _AdminPayrollRecapScreenState();
}

class _AdminPayrollRecapScreenState extends State<AdminPayrollRecapScreen> {
  late int _month;
  late int _year;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
  }

  Future<void> _downloadRecapPdf(
    BuildContext context,
    List<Map<String, dynamic>> rows,
  ) async {
    final fileName = 'Rekap_Potongan_Gaji_KOPKAR_${_month}_$_year.pdf';
    final pdfBytes = PdfGenerator.generatePayrollRecapPdf(
      month: _month,
      year: _year,
      rows: rows,
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
                ? '✅ PDF Rekap Gaji Finance berhasil diunduh: $savedPath'
                : '⚠️ Gagal mengunduh PDF Rekap Gaji.',
          ),
          backgroundColor:
              savedPath != null ? AppTheme.successGreen : AppTheme.dangerRed,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final coop = widget.coopService;
    return ListenableBuilder(
      listenable: coop,
      builder: (context, _) {
        final rows = coop.getMonthlyPayrollPreview(month: _month, year: _year);
        final grandTotal = rows.fold<double>(
          0.0,
          (sum, r) => sum + (r['totalDeduction'] as num).toDouble(),
        );

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBackground,
          appBar: AppBar(
            title: const Text('Rekap Potongan Gaji (Finance)'),
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderBanner(
                  icon: Icons.table_chart_rounded,
                  title:
                      'Laporan Rekap Gaji Divisi Finance (${CoopService.formatMonthYear(_month, _year)})',
                  subtitle:
                      'Tabel resmi potongan gaji anggota aktif untuk diserahkan HRD ke Finance',
                  gradientColors: const [Color(0xFF0E7490), Color(0xFF0284C7)],
                  stats: [
                    MapEntry('Jumlah Karyawan', '${rows.length} Aktif'),
                    MapEntry('Total Potongan', CoopService.formatRupiah(grandTotal)),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final sb = StringBuffer();
                          sb.writeln(
                            'REKAP POTONGAN GAJI KOPKAR PT BBM - ${CoopService.formatMonthYear(_month, _year)}',
                          );
                          for (final r in rows) {
                            sb.writeln(
                              '${r['nik']} | ${r['name']} | Pokok: ${CoopService.formatRupiah((r['pokok'] as num).toDouble())} | Wajib: ${CoopService.formatRupiah((r['wajib'] as num).toDouble())} | Cicilan: ${CoopService.formatRupiah((r['loanInstallment'] as num).toDouble())} | Total: ${CoopService.formatRupiah((r['totalDeduction'] as num).toDouble())}',
                            );
                          }
                          Clipboard.setData(ClipboardData(text: sb.toString()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '📋 Tabel Rekap Gaji berhasil disalin ke Clipboard!',
                              ),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text(
                          'Salin Teks Finance',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _downloadRecapPdf(context, rows),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: const Text(
                          'Unduh PDF Finance',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (rows.isEmpty)
                  _buildEmptyState('Belum ada data anggota aktif.')
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, idx) {
                      final r = rows[idx];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
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
                                    '${r['name']} (${r['nik']})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Text(
                                  CoopService.formatRupiah(
                                    (r['totalDeduction'] as num).toDouble(),
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Departemen: ${r['department']}\n'
                              'Simpanan Pokok: ${CoopService.formatRupiah((r['pokok'] as num).toDouble())} • '
                              'Simpanan Wajib: ${CoopService.formatRupiah((r['wajib'] as num).toDouble())} • '
                              'Cicilan + Bunga 1%: ${CoopService.formatRupiah((r['loanInstallment'] as num).toDouble())}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// 6. HALAMAN VERIFIKASI PELUNASAN DIPERCEPAT (ADMIN EARLY SETTLEMENT SCREEN)
// ============================================================================
class AdminEarlySettlementScreen extends StatelessWidget {
  final CoopService coopService;
  const AdminEarlySettlementScreen({super.key, required this.coopService});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: coopService,
      builder: (context, _) {
        final pendingList = coopService.pendingEarlySettlementLoans;
        final settledList = coopService.loans
            .where((l) => l.status == LoanStatus.settled)
            .toList()
            .reversed
            .toList();

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBackground,
          appBar: AppBar(
            title: const Text('Verifikasi Pelunasan Dipercepat'),
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderBanner(
                  icon: Icons.receipt_long_rounded,
                  title: 'Pelunasan Pinjaman Dipercepat',
                  subtitle:
                      'Verifikasi bukti transfer pelunasan & bagikan bunga 1% ke anggota aktif',
                  gradientColors: const [Color(0xFF4C1D95), Color(0xFF7C3AED)],
                  stats: [
                    MapEntry('Menunggu Verifikasi', '${pendingList.length} Pinjaman'),
                    MapEntry('Riwayat Lunas', '${settledList.length} Pinjaman'),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Menunggu Verifikasi Mutasi Bank',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                if (pendingList.isEmpty)
                  _buildEmptyState(
                    'Tidak ada pengajuan pelunasan dipercepat yang menunggu verifikasi.',
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pendingList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final l = pendingList[idx];
                      final totalPayoff = l.remainingBalance + l.monthlyInterest;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppTheme.successGreen.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    l.memberName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Text(
                                  CoopService.formatRupiah(totalPayoff),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: AppTheme.successGreen,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sisa Pokok: ${CoopService.formatRupiah(l.remainingBalance)} + Bunga 1%: ${CoopService.formatRupiah(l.monthlyInterest)}\n'
                              'Catatan: ${l.earlySettlementNote ?? "-"}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textMuted,
                                height: 1.4,
                              ),
                            ),
                            if (l.earlySettlementProofBase64 != null &&
                                l.earlySettlementProofBase64!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => showTransferProofDialog(
                                  context,
                                  l.earlySettlementProofBase64!,
                                  title:
                                      'Bukti Transfer Pelunasan (${l.memberName})',
                                  subtitle:
                                      'Total Pelunasan: ${CoopService.formatRupiah(totalPayoff)}',
                                ),
                                icon: const Icon(
                                  Icons.image_search_rounded,
                                  size: 15,
                                ),
                                label: const Text(
                                  'Lihat Foto Bukti Transfer Pelunasan',
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      if (!_checkAdminRole(
                                        context,
                                        coopService.currentAdmin
                                                ?.canVerifyBankMutation ??
                                            true,
                                        'Bendahara / Super Admin',
                                      )) {
                                        return;
                                      }
                                      coopService.rejectEarlyLoanSettlement(
                                        l.id,
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.dangerRed,
                                      side: const BorderSide(
                                        color: AppTheme.dangerRed,
                                      ),
                                    ),
                                    child: const Text('Tolak Mutasi'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (!_checkAdminRole(
                                        context,
                                        coopService.currentAdmin
                                                ?.canVerifyBankMutation ??
                                            true,
                                        'Bendahara / Super Admin',
                                      )) {
                                        return;
                                      }
                                      coopService.settleLoanEarly(l.id);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '✅ Pelunasan pinjaman ${l.memberName} disetujui & LUNAS!',
                                          ),
                                          backgroundColor:
                                              AppTheme.successGreen,
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.successGreen,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text(
                                      'Verifikasi Lunas & Bagi Bunga 1%',
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
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// 7. HALAMAN VERIFIKASI AKUN BARU & OTORISASI RESET PIN (ADMIN PIN SCREEN)
// ============================================================================
class AdminPinVerificationScreen extends StatelessWidget {
  final CoopService coopService;
  const AdminPinVerificationScreen({super.key, required this.coopService});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: coopService,
      builder: (context, _) {
        final pendingPinResets = coopService.pendingPinResetMembers;
        final pendingMembers = coopService.pendingMemberRegistrations;

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBackground,
          appBar: AppBar(
            title: const Text('Otorisasi Reset PIN & Akun Baru'),
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderBanner(
                  icon: Icons.lock_reset_rounded,
                  title: 'Pusat Verifikasi Keamanan & Akun Anggota',
                  subtitle:
                      'Otorisasi permohonan Reset PIN 3-Faktor & aktivasi pendaftaran anggota baru',
                  gradientColors: const [Color(0xFF0F172A), Color(0xFF1D4ED8)],
                  stats: [
                    MapEntry('Reset PIN', '${pendingPinResets.length} Menunggu'),
                    MapEntry('Akun Baru', '${pendingMembers.length} Menunggu'),
                  ],
                ),
                const SizedBox(height: 18),

                const Text(
                  'Permohonan Reset PIN (Lolos Verifikasi 3-Faktor)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                if (pendingPinResets.isEmpty)
                  _buildEmptyState(
                    'Tidak ada permohonan reset PIN yang menunggu otorisasi.',
                    icon: Icons.verified_user_rounded,
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pendingPinResets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final m = pendingPinResets[idx];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppTheme.warningOrange.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🔐 ${m.name} (NIK: ${m.nik})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Email Terverifikasi: ${m.email}\n'
                              'Rekening Terverifikasi: ${m.bankName} - ${m.bankAccountNumber}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textMuted,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      if (!_checkAdminRole(
                                        context,
                                        coopService.currentAdmin
                                                ?.canVerifyMembers ??
                                            true,
                                        'Super Admin / Ketua / Sekretaris',
                                      )) {
                                        return;
                                      }
                                      coopService.rejectPendingPinReset(m.id);
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.dangerRed,
                                      side: const BorderSide(
                                        color: AppTheme.dangerRed,
                                      ),
                                    ),
                                    child: const Text('Tolak Reset'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (!_checkAdminRole(
                                        context,
                                        coopService.currentAdmin
                                                ?.canVerifyMembers ??
                                            true,
                                        'Super Admin / Ketua / Sekretaris',
                                      )) {
                                        return;
                                      }
                                      coopService.approvePendingPinReset(m.id);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '✅ Reset PIN ${m.name} berhasil diotorisasi!',
                                          ),
                                          backgroundColor:
                                              AppTheme.successGreen,
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryBlue,
                                      foregroundColor: Colors.white,
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
                const SizedBox(height: 22),

                const Text(
                  'Verifikasi Pendaftaran Anggota Baru',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                if (pendingMembers.isEmpty)
                  _buildEmptyState(
                    'Tidak ada pendaftaran anggota baru yang menunggu verifikasi HRD.',
                    icon: Icons.person_add_disabled_rounded,
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pendingMembers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final m = pendingMembers[idx];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.primaryBlueLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🆕 ${m.name} (NIK: ${m.nik})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Divisi: ${m.department} • Email: ${m.email}\n'
                              'Rekening: ${m.bankName} - ${m.bankAccountNumber}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textMuted,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      if (!_checkAdminRole(
                                        context,
                                        coopService.currentAdmin
                                                ?.canVerifyMembers ??
                                            true,
                                        'Super Admin / Ketua / Sekretaris',
                                      )) {
                                        return;
                                      }
                                      coopService.rejectPendingMember(m.id);
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.dangerRed,
                                      side: const BorderSide(
                                        color: AppTheme.dangerRed,
                                      ),
                                    ),
                                    child: const Text('Tolak Akun'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (!_checkAdminRole(
                                        context,
                                        coopService.currentAdmin
                                                ?.canVerifyMembers ??
                                            true,
                                        'Super Admin / Ketua / Sekretaris',
                                      )) {
                                        return;
                                      }
                                      coopService.approvePendingMember(m.id);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '✅ Akun ${m.name} berhasil diverifikasi & diaktifkan!',
                                          ),
                                          backgroundColor:
                                              AppTheme.successGreen,
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.successGreen,
                                      foregroundColor: Colors.white,
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
              ],
            ),
          ),
        );
      },
    );
  }
}
