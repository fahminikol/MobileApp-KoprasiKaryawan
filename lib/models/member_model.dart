enum MemberStatus { active, resigned, pendingResign, pendingVerification }

class MemberModel {
  final String id;
  final String nik;
  final String name;
  final String department;
  final String email;
  final String phone;
  final DateTime joinDate;
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountHolder;
  final bool isBankVerified;
  final String securityPin;
  final String? pendingPinReset; // Pengajuan reset PIN yang menunggu persetujuan Admin HRD (disensor dari Admin)
  final bool isBiometricEnabled;
  final MemberStatus status;
  final double simpananPokok;
  final double simpananWajib;
  final double simpananSukarela;
  final double saldoBagiHasilBunga; // Akumulasi pembagian bunga pinjaman 1% ke seluruh anggota aktif
  final double activeLoanBalance;

  MemberModel({
    required this.id,
    required this.nik,
    required this.name,
    required this.department,
    required this.email,
    required this.phone,
    required this.joinDate,
    required this.bankName,
    required this.bankAccountNumber,
    this.bankAccountHolder = 'Anggota Koperasi',
    this.isBankVerified = true,
    this.securityPin = '123456',
    this.pendingPinReset,
    this.isBiometricEnabled = true,
    this.status = MemberStatus.active,
    this.simpananPokok = 100000.0,
    this.simpananWajib = 0.0,
    this.simpananSukarela = 0.0,
    this.saldoBagiHasilBunga = 0.0,
    this.activeLoanBalance = 0.0,
  });

  double get totalSavings =>
      simpananPokok + simpananWajib + simpananSukarela + saldoBagiHasilBunga;

  int get membershipMonths {
    final now = DateTime.now();
    int months = (now.year - joinDate.year) * 12 + now.month - joinDate.month;
    return months <= 0 ? 1 : months;
  }

  /// Jumlah bulan Simpanan Wajib yang benar-benar sudah terbayar (@ Rp 25.000)
  int get paidWajibMonths => (simpananWajib / 25000).round();

  /// Plafon maksimal pinjaman berdasarkan masa kerja karyawan (Proteksi Risiko Koperasi)
  double get maxLoanLimit {
    final m = membershipMonths;
    if (m < 3) return 2000000.0; // < 3 bulan: Maks Rp 2 Juta
    if (m < 6) return 5000000.0; // 3-5 bulan: Maks Rp 5 Juta
    if (m < 12) return 10000000.0; // 6-11 bulan: Maks Rp 10 Juta
    return 20000000.0; // >= 1 tahun: Maks Rp 20 Juta
  }

  /// Proteksi Jaminan Utang (Collateral Lock):
  /// Jika karyawan sedang memiliki sisa utang pinjaman aktif (activeLoanBalance > 0),
  /// maka Simpanan Sukarela hanya bisa ditarik jika Total Simpanan setelah penarikan masih >= Sisa Utang Pinjaman.
  double get maxWithdrawableSukarela {
    if (activeLoanBalance <= 0) return simpananSukarela;
    return (totalSavings - activeLoanBalance).clamp(0.0, simpananSukarela);
  }

  /// Nominal Simpanan Sukarela yang sedang dikunci sebagai jaminan pinjaman aktif
  double get lockedSukarelaCollateral =>
      (simpananSukarela - maxWithdrawableSukarela).clamp(0.0, simpananSukarela);

  String get statusLabel {
    switch (status) {
      case MemberStatus.active:
        return 'Aktif';
      case MemberStatus.pendingResign:
        return 'Proses Resign';
      case MemberStatus.resigned:
        return 'Sudah Resign';
      case MemberStatus.pendingVerification:
        return 'Menunggu Verifikasi HRD';
    }
  }

  // Masked bank account number for high security (e.g. 8720••••31)
  String get maskedBankAccount {
    if (bankAccountNumber.length <= 4) return bankAccountNumber;
    final start = bankAccountNumber.substring(0, 4);
    final end = bankAccountNumber.substring(bankAccountNumber.length - 2);
    return '$start••••$end';
  }

  MemberModel copyWith({
    String? id,
    String? nik,
    String? name,
    String? department,
    String? email,
    String? phone,
    DateTime? joinDate,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountHolder,
    bool? isBankVerified,
    String? securityPin,
    String? pendingPinReset,
    bool clearPendingPinReset = false,
    bool? isBiometricEnabled,
    MemberStatus? status,
    double? simpananPokok,
    double? simpananWajib,
    double? simpananSukarela,
    double? saldoBagiHasilBunga,
    double? activeLoanBalance,
  }) {
    return MemberModel(
      id: id ?? this.id,
      nik: nik ?? this.nik,
      name: name ?? this.name,
      department: department ?? this.department,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      joinDate: joinDate ?? this.joinDate,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
      isBankVerified: isBankVerified ?? this.isBankVerified,
      securityPin: securityPin ?? this.securityPin,
      pendingPinReset: clearPendingPinReset
          ? null
          : (pendingPinReset ?? this.pendingPinReset),
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      status: status ?? this.status,
      simpananPokok: simpananPokok ?? this.simpananPokok,
      simpananWajib: simpananWajib ?? this.simpananWajib,
      simpananSukarela: simpananSukarela ?? this.simpananSukarela,
      saldoBagiHasilBunga: saldoBagiHasilBunga ?? this.saldoBagiHasilBunga,
      activeLoanBalance: activeLoanBalance ?? this.activeLoanBalance,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nik': nik,
        'name': name,
        'department': department,
        'email': email,
        'phone': phone,
        'joinDate': joinDate.toIso8601String(),
        'bankName': bankName,
        'bankAccountNumber': bankAccountNumber,
        'bankAccountHolder': bankAccountHolder,
        'isBankVerified': isBankVerified,
        'securityPin': securityPin,
        'pendingPinReset': pendingPinReset,
        'isBiometricEnabled': isBiometricEnabled,
        'status': status.name,
        'simpananPokok': simpananPokok,
        'simpananWajib': simpananWajib,
        'simpananSukarela': simpananSukarela,
        'saldoBagiHasilBunga': saldoBagiHasilBunga,
        'activeLoanBalance': activeLoanBalance,
      };

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'active';
    final status = MemberStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => MemberStatus.active,
    );
    return MemberModel(
      id: json['id'] as String,
      nik: json['nik'] as String,
      name: json['name'] as String,
      department: json['department'] as String? ?? 'Umum',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      joinDate:
          DateTime.tryParse(json['joinDate'] as String? ?? '') ?? DateTime.now(),
      bankName: json['bankName'] as String? ?? 'BCA',
      bankAccountNumber: json['bankAccountNumber'] as String? ?? '',
      bankAccountHolder:
          json['bankAccountHolder'] as String? ?? (json['name'] as String? ?? ''),
      isBankVerified: json['isBankVerified'] as bool? ?? true,
      securityPin: json['securityPin'] as String? ?? '123456',
      pendingPinReset: json['pendingPinReset'] as String?,
      isBiometricEnabled: json['isBiometricEnabled'] as bool? ?? true,
      status: status,
      simpananPokok: (json['simpananPokok'] as num?)?.toDouble() ?? 100000.0,
      simpananWajib: (json['simpananWajib'] as num?)?.toDouble() ?? 0.0,
      simpananSukarela: (json['simpananSukarela'] as num?)?.toDouble() ?? 0.0,
      saldoBagiHasilBunga:
          (json['saldoBagiHasilBunga'] as num?)?.toDouble() ?? 0.0,
      activeLoanBalance: (json['activeLoanBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
