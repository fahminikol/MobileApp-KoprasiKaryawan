/// ============================================================================
/// INPUT SANITIZER & VALIDATOR ENGINE (STANDAR KEAMANAN PERBANKAN DIGITAL)
/// KOPKAR PT BUDI BERLIAN MOTOR
/// 
/// Perlindungan Komprehensif:
/// 1. Anti-XSS (Cross-Site Scripting) & HTML Tag Stripping
/// 2. Anti-SQL Injection & Command Injection Neutralization
/// 3. Anti-Null Byte (\0) & Zero-Width / Invisible Unicode Sanitization
/// 4. Validasi Format Spesifik (NIK, Nama, Email RFC, No. HP, No. Rekening, PIN)
/// 5. Pendeteksi PIN Lemah (Anti-123456, Anti-000000, Anti-Urutan Angka)
/// 6. Validasi Finansial (Batas Plafon, Anti-Negative, Anti-Overflow)
/// ============================================================================

class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String sanitizedValue;

  const ValidationResult._({
    required this.isValid,
    this.errorMessage,
    required this.sanitizedValue,
  });

  factory ValidationResult.success([String sanitized = '']) =>
      ValidationResult._(isValid: true, sanitizedValue: sanitized);

  factory ValidationResult.failure(String message, [String sanitized = '']) =>
      ValidationResult._(isValid: false, errorMessage: message, sanitizedValue: sanitized);

  @override
  String toString() => isValid
      ? 'ValidationResult.success("$sanitizedValue")'
      : 'ValidationResult.failure("$errorMessage")';
}

class InputSanitizer {
  // Regex untuk membersihkan tag HTML, script block, style block, iframe, objek berbahaya
  static final RegExp _scriptBlockRegex = RegExp(r'<script\b[^>]*>[\s\S]*?<\/script>', caseSensitive: false);
  static final RegExp _styleBlockRegex = RegExp(r'<style\b[^>]*>[\s\S]*?<\/style>', caseSensitive: false);
  static final RegExp _iframeBlockRegex = RegExp(r'<iframe\b[^>]*>[\s\S]*?<\/iframe>', caseSensitive: false);
  static final RegExp _htmlTagRegex = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false);
  static final RegExp _scriptProtocols = RegExp(r'(javascript|vbscript|data|livescript|mocha):', caseSensitive: false);
  static final RegExp _eventHandlers = RegExp(r'\bon\w+\s*=', caseSensitive: false);
  static final RegExp _sqlPatterns = RegExp(r'(--|/\*|\*/|;\s*$|xp_|union\s+select|drop\s+table|exec\s*\(|insert\s+into|delete\s+from)', caseSensitive: false);
  static final RegExp _zeroWidthChars = RegExp(r'[\u200B\u200C\u200D\uFEFF\u0000-\u0008\u000B\u000C\u000E-\u001F]');

  /// 1. Pembersihan Teks Umum (Anti-XSS, Anti-SQLi, Anti-Control Chars)
  static String sanitizeText(
    String? raw, {
    int maxLength = 250,
    bool allowNewlines = false,
  }) {
    if (raw == null) return '';
    String cleaned = raw;

    // Bersihkan karakter null-byte & zero-width / invisible unicode
    cleaned = cleaned.replaceAll(_zeroWidthChars, '');

    // Bersihkan blok script, style, dan iframe beserta seluruh isinya
    cleaned = cleaned.replaceAll(_scriptBlockRegex, '');
    cleaned = cleaned.replaceAll(_styleBlockRegex, '');
    cleaned = cleaned.replaceAll(_iframeBlockRegex, '');

    // Bersihkan sisa tag HTML & XML
    cleaned = cleaned.replaceAll(_htmlTagRegex, '');

    // Bersihkan protokol skrip berbahaya
    cleaned = cleaned.replaceAll(_scriptProtocols, '');

    // Bersihkan event handlers (e.g. onload=, onerror=)
    cleaned = cleaned.replaceAll(_eventHandlers, '');

    // Bersihkan pola SQL injection berbahaya
    cleaned = cleaned.replaceAll(_sqlPatterns, '');

    // Hapus karakter backtick, tanda kurung siku ganda, simbol eksekusi shell
    cleaned = cleaned.replaceAll(RegExp(r'[`\$\{\}\|]'), '');

    if (!allowNewlines) {
      cleaned = cleaned.replaceAll(RegExp(r'[\r\n\t]+'), ' ');
    }

    cleaned = cleaned.trim();

    if (cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength).trim();
    }
    return cleaned;
  }

  /// 2. Sanitasi NIK: Hanya Huruf dan Angka Murni (Anti-Simbol)
  static String sanitizeNik(String? raw) {
    if (raw == null) return '';
    return raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').trim();
  }

  /// 3. Sanitasi Nama Lengkap: Hanya Huruf Alfabet, Spasi, Titik, Koma, Apostrof
  static String sanitizeName(String? raw, {int maxLength = 80}) {
    if (raw == null) return '';
    String cleaned = raw.replaceAll(RegExp(r'''[^a-zA-Z\s\.\,']'''), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength).trim();
    }
    return cleaned;
  }

  /// 4. Sanitasi Email: Lowercase, Trimming, Menghapus Baris Baru (Anti-Header Injection)
  static String sanitizeEmail(String? raw, {int maxLength = 100}) {
    if (raw == null) return '';
    String cleaned = raw.replaceAll(RegExp(r'[\r\n\t\s]'), '').trim().toLowerCase();
    cleaned = cleaned.replaceAll(_htmlTagRegex, '');
    if (cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength);
    }
    return cleaned;
  }

  /// 5. Sanitasi Nomor Telepon / WhatsApp: Hanya Digit Angka (Mendukung +62 / 08)
  static String sanitizePhone(String? raw) {
    if (raw == null) return '';
    String cleaned = raw.trim().replaceAll(RegExp(r'[^0-9\+]'), '');
    if (cleaned.startsWith('+62')) {
      cleaned = '0${cleaned.substring(3)}';
    } else if (cleaned.startsWith('62') && cleaned.length > 9) {
      cleaned = '0${cleaned.substring(2)}';
    }
    return cleaned.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// 6. Sanitasi Nomor Rekening Bank: Hanya Digit Angka
  static String sanitizeBankAccountNumber(String? raw) {
    if (raw == null) return '';
    return raw.replaceAll(RegExp(r'[^0-9]'), '').trim();
  }

  /// 7. Sanitasi Nama Bank (e.g. BCA, Mandiri, BRI, BNI)
  static String sanitizeBankName(String? raw, {int maxLength = 40}) {
    if (raw == null) return 'BCA';
    String cleaned = raw.replaceAll(RegExp(r'[^a-zA-Z0-9\s\-]'), '').trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) cleaned = 'BCA';
    if (cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength).trim();
    }
    return cleaned;
  }

  /// 8. Sanitasi Departemen / Divisi
  static String sanitizeDepartment(String? raw, {int maxLength = 60}) {
    if (raw == null) return 'Umum';
    String cleaned = raw.replaceAll(RegExp(r'[^a-zA-Z0-9\s\/\-\.]'), '').trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) cleaned = 'Umum';
    if (cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength).trim();
    }
    return cleaned;
  }

  /// 9. Parse & Sanitasi Input Rupiah ke Double Aman
  static double sanitizeRupiahAmount(String? raw) {
    if (raw == null) return 0.0;
    final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return 0.0;
    final parsed = double.tryParse(digitsOnly) ?? 0.0;
    return parsed.isFinite && !parsed.isNaN && parsed >= 0 ? parsed : 0.0;
  }

  // ============================================================================
  // VALIDASI FORM & SPESIFIKASI DATA (DENGAN PESAN ERROR LENGKAP & JELAS)
  // ============================================================================

  /// Validasi NIK (Nomor Induk Karyawan)
  static ValidationResult validateNik(String? raw) {
    final clean = sanitizeNik(raw);
    if (clean.isEmpty) {
      return ValidationResult.failure('NIK wajib diisi!');
    }
    if (clean.length < 4) {
      return ValidationResult.failure('NIK terlalu pendek! Minimal 4 karakter alfanumerik.', clean);
    }
    if (clean.length > 25) {
      return ValidationResult.failure('NIK terlalu panjang! Maksimal 25 karakter alfanumerik.', clean);
    }
    return ValidationResult.success(clean);
  }

  /// Validasi Nama Lengkap Sesuai KTP
  static ValidationResult validateName(String? raw) {
    final clean = sanitizeName(raw);
    if (clean.isEmpty) {
      return ValidationResult.failure('Nama Lengkap wajib diisi!');
    }
    if (clean.length < 2) {
      return ValidationResult.failure('Nama Lengkap minimal 2 huruf!', clean);
    }
    if (clean.length > 80) {
      return ValidationResult.failure('Nama Lengkap maksimal 80 karakter!', clean);
    }
    // Pastikan setidaknya ada karakter huruf (bukan hanya titik atau koma)
    if (!RegExp(r'[a-zA-Z]').hasMatch(clean)) {
      return ValidationResult.failure('Nama Lengkap harus mengandung huruf alfabet!', clean);
    }
    return ValidationResult.success(clean);
  }

  /// Validasi Email Standar RFC 5322
  static ValidationResult validateEmail(String? raw) {
    final clean = sanitizeEmail(raw);
    if (clean.isEmpty) {
      return ValidationResult.failure('Alamat email wajib diisi!');
    }
    final emailRegex = RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$");
    if (!emailRegex.hasMatch(clean)) {
      return ValidationResult.failure('Format alamat email tidak valid! Contoh: budi@budiberlian.co.id', clean);
    }
    return ValidationResult.success(clean);
  }

  /// Validasi Nomor HP / WhatsApp
  static ValidationResult validatePhone(String? raw) {
    final clean = sanitizePhone(raw);
    if (clean.isEmpty) {
      return ValidationResult.failure('Nomor telepon / WhatsApp wajib diisi!');
    }
    if (clean.length < 10) {
      return ValidationResult.failure('Nomor telepon terlalu pendek! Minimal 10 digit angka.', clean);
    }
    if (clean.length > 15) {
      return ValidationResult.failure('Nomor telepon maksimal 15 digit angka.', clean);
    }
    if (!clean.startsWith('08') && !clean.startsWith('02')) {
      return ValidationResult.failure('Nomor telepon harus diawali dengan 08 atau 02 (atau +62)!', clean);
    }
    return ValidationResult.success(clean);
  }

  /// Validasi Nomor Rekening Bank
  static ValidationResult validateBankAccount(String? raw) {
    final clean = sanitizeBankAccountNumber(raw);
    if (clean.isEmpty) {
      return ValidationResult.failure('Nomor rekening bank wajib diisi!');
    }
    if (clean.length < 8) {
      return ValidationResult.failure('Nomor rekening bank terlalu pendek! Minimal 8 digit angka.', clean);
    }
    if (clean.length > 22) {
      return ValidationResult.failure('Nomor rekening bank maksimal 22 digit angka.', clean);
    }
    return ValidationResult.success(clean);
  }

  /// Deteksi PIN Lemah (Anti-123456, Anti-000000, Anti-Urutan)
  static bool isWeakPin(String pin) {
    final clean = pin.trim();
    if (clean.length != 6) return true;

    // 1. Semua digit identik (000000, 111111, dst)
    final allSame = clean.split('').every((ch) => ch == clean[0]);
    if (allSame) return true;

    // 2. Urutan naik atau turun (012345, 123456, 234567, 987654, 654321, dst)
    const forwardSeq = ['012345', '123456', '234567', '345678', '456789', '567890'];
    const reverseSeq = ['987654', '876543', '765432', '654321', '543210', '432109'];
    if (forwardSeq.contains(clean) || reverseSeq.contains(clean)) return true;

    // 3. Pola berulang 3 digit (123123, 456456) atau 2 digit berulang (121212)
    if (clean.substring(0, 3) == clean.substring(3, 6)) return true;
    if (clean[0] == clean[2] && clean[2] == clean[4] &&
        clean[1] == clean[3] && clean[3] == clean[5]) {
      return true;
    }

    return false;
  }

  /// Validasi PIN Transaksi (Tepat 6 Digit Angka 0-9)
  static ValidationResult validatePin(
    String? raw, {
    bool disallowWeak = false,
  }) {
    if (raw == null || raw.trim().isEmpty) {
      return ValidationResult.failure('PIN rahasia 6-digit wajib diisi!');
    }
    final clean = raw.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(clean)) {
      return ValidationResult.failure('PIN harus tepat 6 digit angka numerik (0-9)!');
    }
    if (disallowWeak && isWeakPin(clean)) {
      return ValidationResult.failure(
        'PIN terlalu mudah ditebak (contoh: 123456 atau 111111)! Gunakan kombinasi 6 angka unik demi keamanan dana Anda.',
        clean,
      );
    }
    return ValidationResult.success(clean);
  }

  /// Validasi Nominal Rupiah Transaksi
  static ValidationResult validateRupiahAmount(
    double? amount, {
    double min = 10000,
    double max = 500000000,
    String label = 'Nominal transaksi',
  }) {
    if (amount == null || amount.isNaN || !amount.isFinite) {
      return ValidationResult.failure('$label tidak valid!');
    }
    if (amount <= 0) {
      return ValidationResult.failure('$label harus lebih besar dari Rp 0!');
    }
    if (amount < min) {
      return ValidationResult.failure(
        '$label minimal Rp ${_formatNumber(min)}!',
      );
    }
    if (amount > max) {
      return ValidationResult.failure(
        '$label melebihi batas maksimum (Rp ${_formatNumber(max)})!',
      );
    }
    return ValidationResult.success(amount.toStringAsFixed(0));
  }

  /// Validasi Pengajuan Pinjaman
  static ValidationResult validateLoanApplication({
    required double amount,
    required int tenorMonths,
    required double maxLimit,
    required String purpose,
  }) {
    if (amount < 500000) {
      return ValidationResult.failure('Nominal pinjaman minimal Rp 500.000!');
    }
    if (amount > maxLimit) {
      return ValidationResult.failure(
        'Nominal pinjaman melebihi batas limit Anda (Maksimal Rp ${_formatNumber(maxLimit)})!',
      );
    }
    if (tenorMonths < 1 || tenorMonths > 36) {
      return ValidationResult.failure('Tenor pinjaman harus antara 1 sampai 36 bulan!');
    }
    final cleanPurpose = sanitizeText(purpose, maxLength: 120);
    if (cleanPurpose.isEmpty) {
      return ValidationResult.failure('Alasan / tujuan pinjaman wajib diisi!');
    }
    if (cleanPurpose.length < 5) {
      return ValidationResult.failure('Tujuan pinjaman terlalu singkat! Minimal 5 karakter.');
    }
    return ValidationResult.success(cleanPurpose);
  }

  /// Validasi Keterangan / Catatan Transaksi
  static ValidationResult validateNote(
    String? raw, {
    int maxLength = 150,
    bool required = false,
  }) {
    final clean = sanitizeText(raw, maxLength: maxLength);
    if (required && clean.isEmpty) {
      return ValidationResult.failure('Keterangan / catatan wajib diisi!');
    }
    return ValidationResult.success(clean);
  }

  /// Validasi Password Pengurus
  static ValidationResult validatePassword(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return ValidationResult.failure('Password wajib diisi!');
    }
    final clean = raw.trim();
    if (clean.length < 6) {
      return ValidationResult.failure('Password minimal 6 karakter!');
    }
    if (clean.length > 50) {
      return ValidationResult.failure('Password maksimal 50 karakter!');
    }
    return ValidationResult.success(clean);
  }

  static String _formatNumber(double val) {
    return val.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }
}
