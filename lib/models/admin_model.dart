enum AdminRole { superAdmin, ketuaKoperasi, bendahara, sekretaris }

extension AdminRoleLabel on AdminRole {
  String get label {
    switch (this) {
      case AdminRole.superAdmin:
        return 'Super Admin (HRD Master)';
      case AdminRole.ketuaKoperasi:
        return 'Ketua Koperasi';
      case AdminRole.bendahara:
        return 'Bendahara Keuangan';
      case AdminRole.sekretaris:
        return 'Sekretaris Administrasi';
    }
  }

  String get badgeEmoji {
    switch (this) {
      case AdminRole.superAdmin:
        return '👑';
      case AdminRole.ketuaKoperasi:
        return '🏛️';
      case AdminRole.bendahara:
        return '💰';
      case AdminRole.sekretaris:
        return '📋';
    }
  }

  /// Daftar Scope Otorisasi OAuth2 / JWT RBAC yang dimiliki oleh jabatan ini
  List<String> get grantedScopes {
    switch (this) {
      case AdminRole.superAdmin:
        return const [
          'admin:users:manage',
          'admin:members:verify',
          'admin:bank:verify',
          'admin:finance:approve',
          'admin:payroll:execute',
          'admin:audit:read',
        ];
      case AdminRole.ketuaKoperasi:
        return const [
          'admin:members:verify',
          'admin:finance:approve',
          'admin:payroll:execute',
          'admin:audit:read',
        ];
      case AdminRole.bendahara:
        return const [
          'admin:bank:verify',
          'admin:finance:approve',
          'admin:payroll:execute',
          'admin:audit:read',
        ];
      case AdminRole.sekretaris:
        return const [
          'admin:members:verify',
          'admin:audit:read',
        ];
    }
  }

  /// Ringkasan hak akses jabatan untuk ditampilkan pada Matriks Otorisasi RBAC
  String get permissionSummary {
    switch (this) {
      case AdminRole.superAdmin:
        return 'Akses Penuh (Kelola Pengurus, Verifikasi Anggota/PIN, Mutasi Bank, Pencairan Pinjaman/Resign & Payroll)';
      case AdminRole.ketuaKoperasi:
        return 'Otorisasi Anggota/PIN, Persetujuan Pinjaman/Resign & Eksekusi Payroll (Tanpa Kelola Admin / Mutasi Bank)';
      case AdminRole.bendahara:
        return 'Otorisasi Mutasi Bank, Pencairan Pinjaman/Tarik/Resign & Eksekusi Payroll (Tanpa Kelola Admin / Verifikasi Akun)';
      case AdminRole.sekretaris:
        return 'Otorisasi Verifikasi Pendaftaran Anggota Baru & Reset PIN (Tanpa Akses Pencairan Kas / Mutasi Bank)';
    }
  }

  bool hasScope(String scope) => grantedScopes.contains(scope);
}

class AdminModel {
  final String id;
  final String name;
  final String email;
  String password;
  final AdminRole role;
  final String phone;
  final bool isActive;
  final DateTime createdAt;

  AdminModel({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    required this.phone,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool verifyPassword(String input) => password == input.trim();

  /// Daftar scope JWT RBAC untuk akun pengurus ini
  List<String> get grantedScopes => role.grantedScopes;

  /// Cek apakah pengurus memiliki scope otorisasi tertentu
  bool hasScope(String scope) => role.hasScope(scope);

  /// Hak Akses Role-Based Access Control (RBAC):
  /// 1. Hanya Super Admin (HRD Master) yang berhak menambah, mereset password, atau menonaktifkan Pengurus lain
  bool get canManageAdmins => role.hasScope('admin:users:manage');

  /// 2. Verifikasi Pendaftaran Anggota Baru & Otorisasi Reset PIN (Super Admin, Ketua Koperasi, Sekretaris)
  bool get canVerifyMembers => role.hasScope('admin:members:verify');

  /// 3. Verifikasi Mutasi Rekening Bank Koperasi: Setor/Tarik Sukarela, Pelunasan Dipercepat (Super Admin & Bendahara)
  bool get canVerifyBankMutation => role.hasScope('admin:bank:verify');

  /// 4. Persetujuan & Pencairan Pinjaman / Klaim Resign / Payroll (Super Admin, Ketua Koperasi, Bendahara)
  bool get canApproveFinance => role.hasScope('admin:finance:approve');

  /// 5. Eksekusi Batch Potongan Gaji Payroll Bulanan (Super Admin, Ketua Koperasi, Bendahara)
  bool get canExecutePayroll => role.hasScope('admin:payroll:execute');

  AdminModel copyWith({
    String? name,
    String? email,
    String? password,
    AdminRole? role,
    String? phone,
    bool? isActive,
  }) {
    return AdminModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'password': password,
        'role': role.name,
        'phone': phone,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AdminModel.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String? ?? 'sekretaris';
    final role = AdminRole.values.firstWhere(
      (r) => r.name == roleStr,
      orElse: () => AdminRole.sekretaris,
    );
    return AdminModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      password: json['password'] as String,
      role: role,
      phone: json['phone'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}
