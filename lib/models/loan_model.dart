enum LoanStatus { pending, approved, rejected, active, settled }

class LoanModel {
  final String id;
  final String memberId;
  final String memberName;
  final double amount;
  final int tenorMonths; // Maksimal 12 bulan
  final int paidInstallments; // Sudah dicicil berapa bulan
  final double interestRateAnnual; // 12% per tahun = 1% flat per bulan
  final String purpose;
  final LoanStatus status;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? approvedByAdmin;
  final String? rejectionReason;
  final double remainingBalance;
  final bool isPendingEarlySettlement;
  final String? earlySettlementNote;
  final String? disbursementProofBase64;
  final String? earlySettlementProofBase64;

  LoanModel({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.amount,
    required int tenorMonths,
    this.paidInstallments = 0,
    this.interestRateAnnual = 12.0, // Default 1% per bulan (12% per tahun)
    required this.purpose,
    this.status = LoanStatus.pending,
    required this.createdAt,
    this.approvedAt,
    this.approvedByAdmin,
    this.rejectionReason,
    required this.remainingBalance,
    this.isPendingEarlySettlement = false,
    this.earlySettlementNote,
    this.disbursementProofBase64,
    this.earlySettlementProofBase64,
  }) : tenorMonths = tenorMonths.clamp(1, 12);

  // Aturan Koperasi PT Budi Berlian Motor:
  // - Masa angsuran maksimal 12 bulan
  // - Bunga flat 1% per bulan dari pokok pinjaman (dibulatkan ke Rupiah terdekat agar bebas selisih koma)
  // - Bunga 1% tersebut dibagi rata ke seluruh jumlah anggota aktif
  double get monthlyInterestRatePercent => interestRateAnnual / 12; // 1.0%
  double get monthlyPrincipal => (amount / tenorMonths).roundToDouble();
  double get monthlyInterest =>
      (amount * (monthlyInterestRatePercent / 100)).roundToDouble(); // 1% per bulan
  double get totalMonthlyInstallment => monthlyPrincipal + monthlyInterest;
  double get totalInterest => monthlyInterest * tenorMonths;
  double get totalRepayment => totalMonthlyInstallment * tenorMonths;
  int get remainingTenorMonths => (tenorMonths - paidInstallments).clamp(0, tenorMonths);

  String get statusLabel {
    if (status == LoanStatus.active && isPendingEarlySettlement) {
      return 'Menunggu Verifikasi Pelunasan HRD';
    }
    switch (status) {
      case LoanStatus.pending:
        return 'Menunggu Persetujuan';
      case LoanStatus.approved:
      case LoanStatus.active:
        return 'Sedang Berjalan ($paidInstallments/$tenorMonths Bln)';
      case LoanStatus.settled:
        return 'Lunas';
      case LoanStatus.rejected:
        return 'Ditolak';
    }
  }

  // Pembagian bunga 1% per bulan ke seluruh anggota aktif
  double monthlySharePerMember(int totalActiveMembers) {
    if (totalActiveMembers <= 0) return 0.0;
    return (monthlyInterest / totalActiveMembers).roundToDouble();
  }

  // Total pembagian bunga selama masa pinjaman per anggota aktif
  double totalSharePerMember(int totalActiveMembers) {
    if (totalActiveMembers <= 0) return 0.0;
    return (totalInterest / totalActiveMembers).roundToDouble();
  }

  LoanModel copyWith({
    String? memberName,
    int? paidInstallments,
    LoanStatus? status,
    DateTime? approvedAt,
    String? approvedByAdmin,
    String? rejectionReason,
    double? remainingBalance,
    bool? isPendingEarlySettlement,
    String? earlySettlementNote,
    String? disbursementProofBase64,
    String? earlySettlementProofBase64,
  }) {
    return LoanModel(
      id: id,
      memberId: memberId,
      memberName: memberName ?? this.memberName,
      amount: amount,
      tenorMonths: tenorMonths,
      paidInstallments: paidInstallments ?? this.paidInstallments,
      interestRateAnnual: interestRateAnnual,
      purpose: purpose,
      status: status ?? this.status,
      createdAt: createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedByAdmin: approvedByAdmin ?? this.approvedByAdmin,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      isPendingEarlySettlement: isPendingEarlySettlement ?? this.isPendingEarlySettlement,
      earlySettlementNote: earlySettlementNote ?? this.earlySettlementNote,
      disbursementProofBase64: disbursementProofBase64 ?? this.disbursementProofBase64,
      earlySettlementProofBase64: earlySettlementProofBase64 ?? this.earlySettlementProofBase64,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        'memberName': memberName,
        'amount': amount,
        'tenorMonths': tenorMonths,
        'paidInstallments': paidInstallments,
        'interestRateAnnual': interestRateAnnual,
        'purpose': purpose,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'approvedAt': approvedAt?.toIso8601String(),
        'approvedByAdmin': approvedByAdmin,
        'rejectionReason': rejectionReason,
        'remainingBalance': remainingBalance,
        'isPendingEarlySettlement': isPendingEarlySettlement,
        'earlySettlementNote': earlySettlementNote,
        'disbursementProofBase64': disbursementProofBase64,
        'earlySettlementProofBase64': earlySettlementProofBase64,
      };

  factory LoanModel.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'pending';
    return LoanModel(
      id: json['id'] as String,
      memberId: json['memberId'] as String,
      memberName: json['memberName'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      tenorMonths: (json['tenorMonths'] as int?) ?? 12,
      paidInstallments: (json['paidInstallments'] as int?) ?? 0,
      interestRateAnnual: (json['interestRateAnnual'] as num?)?.toDouble() ?? 12.0,
      purpose: json['purpose'] as String? ?? '',
      status: LoanStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => LoanStatus.pending,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      approvedAt: json['approvedAt'] != null
          ? DateTime.tryParse(json['approvedAt'] as String)
          : null,
      approvedByAdmin: json['approvedByAdmin'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      remainingBalance: (json['remainingBalance'] as num?)?.toDouble() ?? 0.0,
      isPendingEarlySettlement: json['isPendingEarlySettlement'] as bool? ?? false,
      earlySettlementNote: json['earlySettlementNote'] as String?,
      disbursementProofBase64: json['disbursementProofBase64'] as String?,
      earlySettlementProofBase64: json['earlySettlementProofBase64'] as String?,
    );
  }
}
