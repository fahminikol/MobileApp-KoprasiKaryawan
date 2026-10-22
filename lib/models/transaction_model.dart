enum TransactionType {
  simpananPokok,
  simpananWajib,
  simpananSukarela,
  penarikanSukarela,
  pencairanPinjaman,
  angsuranPinjaman,
  pelunasanPinjaman,
  bagiHasilBunga,
  refundResign,
}

enum TransactionStatus { pending, success, failed }

class TransactionModel {
  final String id;
  final String memberId;
  final String memberName;
  final TransactionType type;
  final double amount;
  final DateTime date;
  final String description;
  final TransactionStatus status;
  final int? periodMonth;
  final int? periodYear;
  final String? proofImageBase64;

  TransactionModel({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
    this.status = TransactionStatus.success,
    this.periodMonth,
    this.periodYear,
    this.proofImageBase64,
  });

  String get typeLabel {
    switch (type) {
      case TransactionType.simpananPokok:
        return 'Simpanan Pokok';
      case TransactionType.simpananWajib:
        return 'Simpanan Wajib';
      case TransactionType.simpananSukarela:
        return status == TransactionStatus.pending
            ? 'Setor Sukarela (Menunggu Verifikasi)'
            : 'Simpanan Sukarela';
      case TransactionType.penarikanSukarela:
        return 'Tarik Simpanan Sukarela';
      case TransactionType.pencairanPinjaman:
        return 'Pencairan Pinjaman Koperasi';
      case TransactionType.angsuranPinjaman:
        return 'Potongan Angsuran Pinjaman';
      case TransactionType.pelunasanPinjaman:
        return 'Pelunasan Pinjaman Dipercepat';
      case TransactionType.bagiHasilBunga:
        return 'Bagi Hasil Bunga Pinjaman 1%';
      case TransactionType.refundResign:
        return 'Pencairan Hak Simpanan Resign';
    }
  }

  /// True jika transaksi menambah saldo tabungan anggota atau dana cair ke anggota
  bool get isCredit {
    return type == TransactionType.simpananPokok ||
        type == TransactionType.simpananWajib ||
        type == TransactionType.simpananSukarela ||
        type == TransactionType.bagiHasilBunga ||
        type == TransactionType.pencairanPinjaman;
  }

  TransactionModel copyWith({
    String? memberName,
    String? description,
    TransactionStatus? status,
    String? proofImageBase64,
  }) {
    return TransactionModel(
      id: id,
      memberId: memberId,
      memberName: memberName ?? this.memberName,
      type: type,
      amount: amount,
      date: date,
      description: description ?? this.description,
      status: status ?? this.status,
      periodMonth: periodMonth,
      periodYear: periodYear,
      proofImageBase64: proofImageBase64 ?? this.proofImageBase64,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        'memberName': memberName,
        'type': type.name,
        'amount': amount,
        'date': date.toIso8601String(),
        'description': description,
        'status': status.name,
        'periodMonth': periodMonth,
        'periodYear': periodYear,
        'proofImageBase64': proofImageBase64,
      };

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'simpananWajib';
    final statusStr = json['status'] as String? ?? 'success';
    return TransactionModel(
      id: json['id'] as String,
      memberId: json['memberId'] as String,
      memberName: json['memberName'] as String? ?? '',
      type: TransactionType.values.firstWhere(
        (t) => t.name == typeStr,
        orElse: () => TransactionType.simpananWajib,
      ),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      description: json['description'] as String? ?? '',
      status: TransactionStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => TransactionStatus.success,
      ),
      periodMonth: json['periodMonth'] as int?,
      periodYear: json['periodYear'] as int?,
      proofImageBase64: json['proofImageBase64'] as String?,
    );
  }
}
