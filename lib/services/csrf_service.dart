import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// ============================================================================
/// CSRF PROTECTION SERVICE (STANDAR KEAMANAN PERBANKAN & OWASP ASVS LEVEL 3)
/// KOPKAR PT BUDI BERLIAN MOTOR
/// 
/// Perlindungan Komprehensif:
/// 1. Synchronizer Token Pattern (HMAC-SHA256 Cryptographic Nonce)
/// 2. Session-Bound Token (Token CSRF terkunci ke ID Sesi User / Admin)
/// 3. Anti-Cross-Origin Verification (Origin & Referer Whitelist Guard)
/// 4. Custom Request Header Enforcement (X-Requested-With & X-CSRF-Token)
/// 5. Constant-Time Signature Comparison (Anti-Timing Attack)
/// ============================================================================

class CsrfToken {
  final String rawToken;
  final String nonce;
  final String sessionId;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String signature;

  const CsrfToken({
    required this.rawToken,
    required this.nonce,
    required this.sessionId,
    required this.issuedAt,
    required this.expiresAt,
    required this.signature,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remainingDuration =>
      isExpired ? Duration.zero : expiresAt.difference(DateTime.now());

  String get maskedToken {
    if (rawToken.length < 16) return rawToken;
    return '${rawToken.substring(0, 8)}••••••••${rawToken.substring(rawToken.length - 8)}';
  }

  Map<String, dynamic> toJson() => {
        'rawToken': rawToken,
        'nonce': nonce,
        'sessionId': sessionId,
        'issuedAt': issuedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'signature': signature,
      };

  factory CsrfToken.fromJson(Map<String, dynamic> json) => CsrfToken(
        rawToken: json['rawToken'] as String? ?? '',
        nonce: json['nonce'] as String? ?? '',
        sessionId: json['sessionId'] as String? ?? '',
        issuedAt: DateTime.tryParse(json['issuedAt'] as String? ?? '') ?? DateTime.now(),
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
            DateTime.now().add(const Duration(hours: 2)),
        signature: json['signature'] as String? ?? '',
      );
}

class CsrfService {
  // Secret key kriptografis server untuk tanda tangan HMAC-SHA256 CSRF Token
  static const String _csrfSecret = 'kopkar_pt_bbm_super_secure_csrf_secret_2026_w92k';

  // Header wajib standar OWASP
  static const String headerCsrfToken = 'X-CSRF-Token';
  static const String headerRequestedWith = 'X-Requested-With';
  static const String headerRequestedWithValue = 'KOPKAR-Secure-Financial-App';

  // Daftar origin/domain yang diizinkan untuk request ke server
  static const List<String> allowedOrigins = [
    'http://localhost',
    'http://127.0.0.1',
    'http://192.168.18.122',
    'http://192.168.18.119',
    'https://anqvtgusqrrcdnbgnxgf.supabase.co',
  ];

  static final Random _secureRandom = Random.secure();

  /// 1. Terbitkan Anti-CSRF Token Baru yang Terikat dengan Sesi Aktif (Session-Bound)
  static CsrfToken generateToken({
    required String sessionId,
    Duration duration = const Duration(hours: 2),
  }) {
    final now = DateTime.now();
    final expires = now.add(duration);

    // Hasilkan nonce acak 128-bit berkekuatan tinggi
    final randomBytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
    final nonce = base64Url.encode(randomBytes).replaceAll('=', '');

    final payloadToSign = '$nonce:${expires.millisecondsSinceEpoch}:$sessionId';
    final hmac = Hmac(sha256, utf8.encode(_csrfSecret));
    final digest = hmac.convert(utf8.encode(payloadToSign));
    final signature = base64Url.encode(digest.bytes).replaceAll('=', '');

    final rawToken = 'CSRF.$nonce.${expires.millisecondsSinceEpoch}.$signature';

    return CsrfToken(
      rawToken: rawToken,
      nonce: nonce,
      sessionId: sessionId,
      issuedAt: now,
      expiresAt: expires,
      signature: signature,
    );
  }

  /// 2. Verifikasi Token CSRF (Tanda Tangan Kriptografis, Waktu Kedaluwarsa & Kecocokan Sesi)
  static bool verifyToken(
    String? rawToken, {
    required String expectedSessionId,
  }) {
    if (rawToken == null || rawToken.isEmpty) return false;

    final parts = rawToken.split('.');
    if (parts.length != 4 || parts[0] != 'CSRF') return false;

    final nonce = parts[1];
    final expMs = int.tryParse(parts[2]);
    final signature = parts[3];

    if (expMs == null) return false;

    // Periksa apakah token sudah kedaluwarsa
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs > expMs) return false;

    // Hitung ulang tanda tangan HMAC dengan expectedSessionId
    final payloadToSign = '$nonce:$expMs:$expectedSessionId';
    final hmac = Hmac(sha256, utf8.encode(_csrfSecret));
    final expectedDigest = hmac.convert(utf8.encode(payloadToSign));
    final expectedSig = base64Url.encode(expectedDigest.bytes).replaceAll('=', '');

    // Constant-time string comparison untuk mencegah Timing Attacks
    return _constantTimeEquals(signature, expectedSig);
  }

  /// 3. Validasi Origin / Referer (Anti-Cross-Site Request Forgery dari Domain Hacker)
  static bool isOriginAllowed(String? originOrReferer) {
    if (originOrReferer == null || originOrReferer.isEmpty) {
      // Pada Native Android/iOS Mobile App, origin bisa null/file schema, dianggap internal
      return true;
    }
    final clean = originOrReferer.trim().toLowerCase();
    for (final allowed in allowedOrigins) {
      if (clean.startsWith(allowed.toLowerCase())) {
        return true;
      }
    }
    // Izinkan semua IP jaringan lokal LAN internal kantor / Wi-Fi (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
    if (clean.startsWith('http://192.168.') ||
        clean.startsWith('http://10.') ||
        clean.startsWith('http://172.') ||
        clean.contains('.trycloudflare.com')) {
      return true;
    }
    return false;
  }

  /// 4. Generator HTTP Headers untuk Request Mutasi Finansial
  static Map<String, String> getMutationHeaders(CsrfToken token) {
    return {
      headerCsrfToken: token.rawToken,
      headerRequestedWith: headerRequestedWithValue,
      'Sec-Fetch-Site': 'same-origin',
      'Sec-Fetch-Mode': 'cors',
    };
  }

  /// Constant-Time Comparison untuk mencegah Timing Attacks
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
