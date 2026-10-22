enum ResignationStatus {
  submitted,
  verifiedByHR,
  approvedByKoperasi,
  disbursed,
  rejected
}

class ResignationModel {
  final String id;
  final String memberId;
  final String memberNik;
  final String memberName;
  final DateTime resignationDate;
  final double simpananPokokRefund;
  final double simpananWajibRefund;
  final double simpananSukarelaRefund;
  final double saldoBagiHasilRefund; // Hak pencairan Bagi Hasil Bunga 1%
  final double loanDeduction;
  final String destinationBank;
  final String destinationAccountNumber;
  final String destinationAccountHolder;
  final String reason;
  final ResignationStatus status;
  final DateTime requestedAt;
  final DateTime? disbursedAt;
  final String? approvedByAdmin;
  final String? rejectionReason;
  final String? disbursementProofBase64;

  ResignationModel({
    required this.id,
    required this.memberId,
    required this.memberNik,
    required this.memberName,
    required this.resignationDate,
    required this.simpananPokokRefund,
    required this.simpananWajibRefund,
    required this.simpananSukarelaRefund,
    this.saldoBagiHasilRefund = 0.0,
    this.loanDeduction = 0.0,
    required this.destinationBank,
    required this.destinationAccountNumber,
    required this.destinationAccountHolder,
    required this.reason,
    this.status = ResignationStatus.submitted,
    required this.requestedAt,
    this.disbursedAt,
    this.approvedByAdmin,
    this.rejectionReason,
    this.disbursementProofBase64,
  });

  double get grossRefund =>
      simpananPokokRefund +
      simpananWajibRefund +
      simpananSukarelaRefund +
      saldoBagiHasilRefund;

  bool get hasShortfall => loanDeduction > grossRefund;

  double get shortfallAmount =>
      (loanDeduction - grossRefund).clamp(0.0, double.infinity);

  double get netRefund =>
      (grossRefund - loanDeduction).clamp(0.0, double.infinity);

  String get statusBadgeLabel {
    switch (status) {
      case ResignationStatus.submitted:
        return 'Menunggu Verifikasi HRD';
      case ResignationStatus.verifiedByHR:
        return 'Disetujui HRD (Proses Koperasi)';
      case ResignationStatus.approvedByKoperasi:
        return 'Siap Ditransfer';
      case ResignationStatus.disbursed:
        return 'Dana Berhasil Dicairkan';
      case ResignationStatus.rejected:
        return 'Ditolak Admin';
    }
  }

  ResignationModel copyWith({
    String? memberName,
    ResignationStatus? status,
    DateTime? disbursedAt,
    String? approvedByAdmin,
    String? rejectionReason,
    String? disbursementProofBase64,
  }) {
    return ResignationModel(
      id: id,
      memberId: memberId,
      memberNik: memberNik,
      memberName: memberName ?? this.memberName,
      resignationDate: resignationDate,
      simpananPokokRefund: simpananPokokRefund,
      simpananWajibRefund: simpananWajibRefund,
      simpananSukarelaRefund: simpananSukarelaRefund,
      saldoBagiHasilRefund: saldoBagiHasilRefund,
      loanDeduction: loanDeduction,
      destinationBank: destinationBank,
      destinationAccountNumber: destinationAccountNumber,
      destinationAccountHolder: destinationAccountHolder,
      reason: reason,
      status: status ?? this.status,
      requestedAt: requestedAt,
      disbursedAt: disbursedAt ?? this.disbursedAt,
      approvedByAdmin: approvedByAdmin ?? this.approvedByAdmin,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      disbursementProofBase64: disbursementProofBase64 ?? this.disbursementProofBase64,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        'memberNik': memberNik,
        'memberName': memberName,
        'resignationDate': resignationDate.toIso8601String(),
        'simpananPokokRefund': simpananPokokRefund,
        'simpananWajibRefund': simpananWajibRefund,
        'simpananSukarelaRefund': simpananSukarelaRefund,
        'saldoBagiHasilRefund': saldoBagiHasilRefund,
        'loanDeduction': loanDeduction,
        'destinationBank': destinationBank,
        'destinationAccountNumber': destinationAccountNumber,
        'destinationAccountHolder': destinationAccountHolder,
        'reason': reason,
        'status': status.name,
        'requestedAt': requestedAt.toIso8601String(),
        'disbursedAt': disbursedAt?.toIso8601String(),
        'approvedByAdmin': approvedByAdmin,
        'rejectionReason': rejectionReason,
        'disbursementProofBase64': disbursementProofBase64,
      };

  factory ResignationModel.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'submitted';
    return ResignationModel(
      id: json['id'] as String,
      memberId: json['memberId'] as String,
      memberNik: json['memberNik'] as String? ?? '',
      memberName: json['memberName'] as String? ?? '',
      resignationDate:
          DateTime.tryParse(json['resignationDate'] as String? ?? '') ??
              DateTime.now(),
      simpananPokokRefund:
          (json['simpananPokokRefund'] as num?)?.toDouble() ?? 0.0,
      simpananWajibRefund:
          (json['simpananWajibRefund'] as num?)?.toDouble() ?? 0.0,
      simpananSukarelaRefund:
          (json['simpananSukarelaRefund'] as num?)?.toDouble() ?? 0.0,
      saldoBagiHasilRefund:
          (json['saldoBagiHasilRefund'] as num?)?.toDouble() ?? 0.0,
      loanDeduction: (json['loanDeduction'] as num?)?.toDouble() ?? 0.0,
      destinationBank: json['destinationBank'] as String? ?? 'BCA',
      destinationAccountNumber:
          json['destinationAccountNumber'] as String? ?? '',
      destinationAccountHolder:
          json['destinationAccountHolder'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      status: ResignationStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => ResignationStatus.submitted,
      ),
      requestedAt: DateTime.tryParse(json['requestedAt'] as String? ?? '') ??
          DateTime.now(),
      disbursedAt: json['disbursedAt'] != null
          ? DateTime.tryParse(json['disbursedAt'] as String)
          : null,
      approvedByAdmin: json['approvedByAdmin'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      disbursementProofBase64: json['disbursementProofBase64'] as String?,
    );
  }
}
