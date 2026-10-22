import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import '../models/member_model.dart';
import '../models/admin_model.dart';

/// ============================================================================
/// HARDWARE TOKEN CIPHER (DEVICE BINDING ENCRYPTION DENGAN KUNCI MAC ADDRESS)
/// ============================================================================
/// Kunci enkripsi AES-256 diderivasi langsung dari alamat fisik (MAC Address) perangkat.
/// Jika database atau file state dicuri & dipindahkan ke HP / laptop lain,
/// MAC Address perangkat tersebut berbeda sehingga token otomatis rusak dan
/// gagal didekripsi (Device Cloning & Replay Attack Protection).
class HardwareTokenCipher {
  static String currentMacAddress = '36:D5:18:A7:81:7F';
  static const String _salt = 'KOPKAR_PT_BBM_MAC_AES256_SALT_2026_HW_SEC';

  /// Format dan normalisasi MAC Address menjadi 12 karakter hex standar
  static String normalizeMac(String mac) {
    final cleaned = mac.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
    if (cleaned.length != 12) {
      final pad = cleaned.padRight(12, '0').substring(0, 12);
      final parts = <String>[];
      for (int i = 0; i < 12; i += 2) {
        parts.add(pad.substring(i, i + 2));
      }
      return parts.join(':');
    }
    final parts = <String>[];
    for (int i = 0; i < 12; i += 2) {
      parts.add(cleaned.substring(i, i + 2));
    }
    return parts.join(':');
  }

  /// Derivasi Kunci 256-bit AES (32 bytes) dari MAC Address + Salt menggunakan SHA-256
  static Uint8List deriveKeyFromMac(String mac) {
    final norm = normalizeMac(mac);
    final keyMaterial = utf8.encode('$norm::$_salt');
    final digest = sha256.convert(keyMaterial);
    return Uint8List.fromList(digest.bytes);
  }

  /// Enkripsi raw token (Access Token / Refresh Token) dengan kunci MAC Address
  static String encrypt({required String rawToken, String? macAddress}) {
    if (rawToken.isEmpty) return '';
    final mac = (macAddress != null && macAddress.trim().isNotEmpty)
        ? macAddress
        : currentMacAddress;
    final keyBytes = deriveKeyFromMac(mac);
    final key = enc.Key(keyBytes);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(rawToken, iv: iv);

    return 'ENC:MAC256:${iv.base64}:${encrypted.base64}';
  }

  /// Dekripsi token menggunakan kunci MAC Address perangkat lokal
  /// Mengembalikan NULL jika MAC Address tidak cocok (perangkat disalin / dibajak)
  static String? decrypt({required String cipherText, String? macAddress}) {
    if (cipherText.isEmpty) return '';
    if (!cipherText.startsWith('ENC:MAC256:')) {
      // Izinkan string JWT biasa (untuk migrasi data sesi lama)
      return cipherText;
    }
    try {
      final parts = cipherText.split(':');
      if (parts.length != 4) return null;
      final ivStr = parts[2];
      final cipherStr = parts[3];

      final mac = (macAddress != null && macAddress.trim().isNotEmpty)
          ? macAddress
          : currentMacAddress;
      final keyBytes = deriveKeyFromMac(mac);
      final key = enc.Key(keyBytes);
      final iv = enc.IV.fromBase64(ivStr);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter.decrypt64(cipherStr, iv: iv);
    } catch (_) {
      // Decryption gagal: MAC Address mismatch / tampered / invalid key
      return null;
    }
  }

  static bool isEncrypted(String text) => text.startsWith('ENC:MAC256:');
}

/// ============================================================================
/// MODEL AUTH TOKEN DIGITAL (JWT STANDAR CRYPTOGRAPHIC HS256)
/// ============================================================================
class AuthToken {
  final String rawToken;
  final String tokenId;
  final String subjectId;
  final String subjectName;
  final String role; // 'member' | 'admin'
  final String tokenType; // 'access' | 'refresh'
  final String familyId; // ID Family untuk Anti-Theft Token Rotation Detection
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String issuer;
  final List<String> scopes; // Granular OAuth2 / RBAC Permission Scopes
  final String authLevel; // 'MFA_PIN_MAC_BOUND' | 'ADMIN_RBAC_MAC_BOUND'

  const AuthToken({
    required this.rawToken,
    required this.tokenId,
    required this.subjectId,
    required this.subjectName,
    required this.role,
    this.tokenType = 'access',
    this.familyId = '',
    required this.issuedAt,
    required this.expiresAt,
    this.issuer = 'KOPKAR-PT-BBM-SECURITY-GATEWAY',
    this.scopes = const [],
    this.authLevel = 'MFA_PIN_MAC_BOUND',
  });

  bool hasScope(String scope) => scopes.contains(scope);

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remainingDuration {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) return Duration.zero;
    return expiresAt.difference(now);
  }

  String get remainingFormatted {
    final rem = remainingDuration;
    if (rem == Duration.zero) return 'Kedaluwarsa';
    if (rem.inDays > 0) {
      final hours = rem.inHours % 24;
      return '${rem.inDays} Hari ${hours} Jam';
    }
    if (rem.inHours > 0) {
      final mins = rem.inMinutes % 60;
      return '${rem.inHours} Jam ${mins} Menit';
    }
    if (rem.inMinutes > 0) {
      final secs = rem.inSeconds % 60;
      return '${rem.inMinutes} Mnt ${secs} Dtk';
    }
    return '${rem.inSeconds} Detik';
  }

  String get maskedToken {
    if (rawToken.length <= 24) return rawToken;
    final start = rawToken.substring(0, 14);
    final end = rawToken.substring(rawToken.length - 8);
    return '$start••••••••$end';
  }

  /// Menghasilkan representasi ciphertext token yang terkunci dengan Hardware MAC Address
  String get encryptedToken => HardwareTokenCipher.encrypt(rawToken: rawToken);

  String get maskedEncryptedToken {
    final enc = encryptedToken;
    if (enc.length <= 30) return enc;
    final start = enc.substring(0, 18);
    final end = enc.substring(enc.length - 8);
    return '$start••••••••$end';
  }

  Map<String, dynamic> toJson([String? macAddress]) => {
        // Token disimpan dalam format terenkripsi AES-256 dengan kunci MAC Address
        'rawToken': HardwareTokenCipher.encrypt(
          rawToken: rawToken,
          macAddress: macAddress,
        ),
        'tokenId': tokenId,
        'subjectId': subjectId,
        'subjectName': subjectName,
        'role': role,
        'tokenType': tokenType,
        'familyId': familyId,
        'issuedAt': issuedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'issuer': issuer,
        'scopes': scopes,
        'authLevel': authLevel,
        'keyBinding': 'MAC_ADDRESS_AES256',
      };

  factory AuthToken.fromJson(Map<String, dynamic> json, [String? macAddress]) {
    final storedRaw = json['rawToken'] as String? ?? '';
    final decrypted = HardwareTokenCipher.decrypt(
      cipherText: storedRaw,
      macAddress: macAddress,
    );
    final rawScopes = json['scopes'];
    final parsedScopes = rawScopes is List
        ? rawScopes.map((e) => e.toString()).toList()
        : <String>[];

    return AuthToken(
      rawToken: decrypted ?? '',
      tokenId: json['tokenId'] as String? ?? '',
      subjectId: json['subjectId'] as String? ?? '',
      subjectName: json['subjectName'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      tokenType: json['tokenType'] as String? ?? 'access',
      familyId: json['familyId'] as String? ?? '',
      issuedAt: DateTime.tryParse(json['issuedAt'] as String? ?? '') ??
          DateTime.now(),
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
          DateTime.now().add(const Duration(minutes: 15)),
      issuer: json['issuer'] as String? ?? 'KOPKAR-PT-BBM-SECURITY-GATEWAY',
      scopes: parsedScopes,
      authLevel: json['authLevel'] as String? ?? 'MFA_PIN_MAC_BOUND',
    );
  }
}

/// ============================================================================
/// MODEL SESI AUTH LENGKAP: ACCESS TOKEN (15 MNT) + REFRESH TOKEN (ROTASI)
/// ============================================================================
class AuthSession {
  final AuthToken accessToken;
  final AuthToken refreshToken;
  final String familyId;
  final int rotationCount;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.familyId,
    this.rotationCount = 0,
  });

  bool get isSessionAlive =>
      !refreshToken.isExpired &&
      accessToken.rawToken.isNotEmpty &&
      refreshToken.rawToken.isNotEmpty;

  bool get needsAccessTokenRefresh => accessToken.remainingDuration.inMinutes < 3;

  List<String> get scopes => accessToken.scopes;

  bool hasScope(String scope) => isSessionAlive && accessToken.hasScope(scope);

  AuthSession copyWith({
    AuthToken? accessToken,
    AuthToken? refreshToken,
    String? familyId,
    int? rotationCount,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      familyId: familyId ?? this.familyId,
      rotationCount: rotationCount ?? this.rotationCount,
    );
  }

  Map<String, dynamic> toJson([String? macAddress]) => {
        'accessToken': accessToken.toJson(macAddress),
        'refreshToken': refreshToken.toJson(macAddress),
        'familyId': familyId,
        'rotationCount': rotationCount,
        'keyBinding': 'MAC_ADDRESS_AES256',
      };

  factory AuthSession.fromJson(Map<String, dynamic> json, [String? macAddress]) => AuthSession(
        accessToken: AuthToken.fromJson(
          json['accessToken'] as Map<String, dynamic>? ?? {},
          macAddress,
        ),
        refreshToken: AuthToken.fromJson(
          json['refreshToken'] as Map<String, dynamic>? ?? {},
          macAddress,
        ),
        familyId: json['familyId'] as String? ?? '',
        rotationCount: (json['rotationCount'] as num?)?.toInt() ?? 0,
      );
}

/// ============================================================================
/// TOKEN SERVICE: ARCHITECTURE DUAL-TOKEN (ACCESS + REFRESH TOKEN ROTATION)
/// Dilengkapi Anti-Theft Replay Detection & Granular OAuth2 Scopes (Standar Perbankan)
/// ============================================================================
class TokenService {
  static const String _serverSecret =
      'kopkar_pt_bbm_super_secure_jwt_secret_key_2026_x89a';
  static const String _credentialSalt = 'KOPKAR_BBM_CRED_SALT_2026_V2';

  // Masa berlaku Access Token: Sengaja sangat pendek (15 menit) agar jika disadap
  // di jaringan umum/Wi-Fi, token sudah basi & tidak berguna bagi hacker.
  static const Duration memberAccessDuration = Duration(minutes: 15);
  static const Duration adminAccessDuration = Duration(minutes: 15);

  // Masa berlaku Refresh Token (disimpan aman di perangkat)
  static const Duration memberRefreshDuration = Duration(days: 30);
  static const Duration adminRefreshDuration = Duration(hours: 24);

  /// Enkripsi Satu Arah (Salted SHA-256) untuk Password Admin & PIN Transaksi
  static String hashCredential(String plainInput) {
    final clean = plainInput.trim();
    if (clean.startsWith('SHA256:')) return clean;
    final digest = sha256.convert(utf8.encode('$_credentialSalt::$clean'));
    return 'SHA256:${digest.toString()}';
  }

  /// Verifikasi Kredensial (Mendukung Salted SHA-256 maupun Backward-Compatible Plaintext)
  static bool verifyCredential(String input, String stored) {
    final cleanInput = input.trim();
    final cleanStored = stored.trim();
    if (cleanStored.startsWith('SHA256:')) {
      return hashCredential(cleanInput) == cleanStored;
    }
    return cleanInput == cleanStored ||
        hashCredential(cleanInput) == hashCredential(cleanStored);
  }

  /// Daftar Scope Otorisasi JWT berdasarkan status keanggotaan karyawan
  static List<String> scopesForMember(MemberModel member) {
    if (member.status == MemberStatus.active) {
      return const [
        'member:read:own',
        'member:savings:deposit',
        'member:savings:withdraw',
        'member:loan:apply',
        'member:resign:request',
        'member:security:manage',
      ];
    }
    return const [
      'member:read:own',
      'member:security:manage',
    ];
  }

  /// 1. Terbitkan Sesi Baru untuk Karyawan (Access Token + Refresh Token + OAuth2 Scopes)
  static AuthSession createMemberSession(MemberModel member) {
    final now = DateTime.now();
    final familyId = 'FAM-MBR-${now.millisecondsSinceEpoch}-${member.id.replaceAll("-", "")}';
    final memberScopes = scopesForMember(member);
    const authLevel = 'MFA_PIN_MAC_BOUND';

    final access = _issueToken(
      subjectId: member.id,
      subjectName: member.name,
      role: 'member',
      tokenType: 'access',
      familyId: familyId,
      duration: memberAccessDuration,
      scopes: memberScopes,
      authLevel: authLevel,
      customClaims: {'nik': member.nik},
    );

    final refresh = _issueToken(
      subjectId: member.id,
      subjectName: member.name,
      role: 'member',
      tokenType: 'refresh',
      familyId: familyId,
      duration: memberRefreshDuration,
      scopes: memberScopes,
      authLevel: authLevel,
    );

    return AuthSession(
      accessToken: access,
      refreshToken: refresh,
      familyId: familyId,
      rotationCount: 0,
    );
  }

  /// 2. Terbitkan Sesi Baru untuk Admin HRD (Access Token + Refresh Token + RBAC Scopes)
  static AuthSession createAdminSession(AdminModel admin) {
    final now = DateTime.now();
    final familyId = 'FAM-ADM-${now.millisecondsSinceEpoch}-${admin.id.replaceAll("-", "")}';
    final adminScopes = admin.grantedScopes;
    final authLevel = 'ADMIN_RBAC_${admin.role.name.toUpperCase()}_MAC_BOUND';

    final access = _issueToken(
      subjectId: admin.id,
      subjectName: admin.name,
      role: 'admin',
      tokenType: 'access',
      familyId: familyId,
      duration: adminAccessDuration,
      scopes: adminScopes,
      authLevel: authLevel,
      customClaims: {'email': admin.email, 'adminRole': admin.role.name},
    );

    final refresh = _issueToken(
      subjectId: admin.id,
      subjectName: admin.name,
      role: 'admin',
      tokenType: 'refresh',
      familyId: familyId,
      duration: adminRefreshDuration,
      scopes: adminScopes,
      authLevel: authLevel,
    );

    return AuthSession(
      accessToken: access,
      refreshToken: refresh,
      familyId: familyId,
      rotationCount: 0,
    );
  }

  /// 3. Refresh Token Rotation (Anti-Theft Engine)
  /// Mengembalikan:
  /// - `newSession`: Sesi baru yang sah jika rotasi sukses.
  /// - `theftDetected`: TRUE jika token terdeteksi sudah pernah dipakai (ada upaya pencurian token replay!).
  /// - `errorMessage`: Pesan kegagalan jika ada.
  static ({AuthSession? session, bool theftDetected, String? error}) rotateSession({
    required AuthSession currentSession,
    required List<String> usedRefreshTokenIds,
    required List<String> blacklistedFamilyIds,
  }) {
    final rf = currentSession.refreshToken;

    // Cek apakah family token ini sudah di-blacklist (pernah dicuri sebelumnya)
    if (blacklistedFamilyIds.contains(rf.familyId)) {
      return (
        session: null,
        theftDetected: true,
        error: 'Sesi diblokir total karena terdeteksi percobaan pembajakan sebelumnya.',
      );
    }

    // 1. Verifikasi tanda tangan digital & expiry refresh token
    final verifiedRf = verifyAndParseToken(rf.rawToken);
    if (verifiedRf == null || verifiedRf.isExpired) {
      return (
        session: null,
        theftDetected: false,
        error: 'Refresh Token tidak valid atau sudah kedaluwarsa. Silakan login kembali.',
      );
    }

    // 2. DETEKSI PENCURIAN TOKEN (TOKEN REUSE DETECTION):
    // Jika ID Refresh Token ini SUDAH PERNAH digunakan sebelumnya, artinya:
    // Seseorang telah menduplikat/mencuri token lama dan mencoba menggunakannya kembali!
    if (usedRefreshTokenIds.contains(rf.tokenId)) {
      return (
        session: null,
        theftDetected: true,
        error:
            '🚨 PERINGATAN KEAMANAN KRITIS: Upaya Pencurian Token Terdeteksi (Refresh Token Replay)! Sesi seluruh perangkat dibatalkan demi keamanan Anda.',
      );
    }

    // 3. Jika sah, putar token (Token Rotation):
    // Terbitkan Access Token baru & Refresh Token baru dalam family yang sama
    final isMember = rf.role == 'member';
    final accessDuration = isMember ? memberAccessDuration : adminAccessDuration;
    final refreshDuration = isMember ? memberRefreshDuration : adminRefreshDuration;
    final inheritedScopes = currentSession.accessToken.scopes.isNotEmpty
        ? currentSession.accessToken.scopes
        : verifiedRf.scopes;
    final inheritedAuthLevel = currentSession.accessToken.authLevel;

    final newAccess = _issueToken(
      subjectId: rf.subjectId,
      subjectName: rf.subjectName,
      role: rf.role,
      tokenType: 'access',
      familyId: rf.familyId,
      duration: accessDuration,
      scopes: inheritedScopes,
      authLevel: inheritedAuthLevel,
    );

    final newRefresh = _issueToken(
      subjectId: rf.subjectId,
      subjectName: rf.subjectName,
      role: rf.role,
      tokenType: 'refresh',
      familyId: rf.familyId,
      duration: refreshDuration,
      scopes: inheritedScopes,
      authLevel: inheritedAuthLevel,
    );

    final rotatedSession = AuthSession(
      accessToken: newAccess,
      refreshToken: newRefresh,
      familyId: rf.familyId,
      rotationCount: currentSession.rotationCount + 1,
    );

    return (session: rotatedSession, theftDetected: false, error: null);
  }

  /// 4. Verifikasi Keaslian Kriptografi Tanda Tangan JWT (HMAC-SHA256)
  static AuthToken? verifyAndParseToken(
    String rawToken, {
    List<String> revokedTokenIds = const [],
  }) {
    try {
      final parts = rawToken.split('.');
      if (parts.length != 3) return null;

      final headerB64 = parts[0];
      final payloadB64 = parts[1];
      final signatureB64 = parts[2];

      final signingInput = '$headerB64.$payloadB64';
      final hmac = Hmac(sha256, utf8.encode(_serverSecret));
      final expectedDigest = hmac.convert(utf8.encode(signingInput));
      final expectedSigB64 = _base64UrlEncode(expectedDigest.bytes);

      if (signatureB64 != expectedSigB64) {
        return null; // Tanda tangan palsu!
      }

      final payloadJsonStr = utf8.decode(_base64UrlDecode(payloadB64));
      final payload = jsonDecode(payloadJsonStr) as Map<String, dynamic>;

      final tokenId = payload['jti'] as String? ?? '';
      final sub = payload['sub'] as String? ?? '';
      final name = payload['name'] as String? ?? '';
      final role = payload['role'] as String? ?? 'member';
      final type = payload['typ_kind'] as String? ?? 'access';
      final fam = payload['fam'] as String? ?? '';
      final iatSec = (payload['iat'] as num?)?.toInt() ?? 0;
      final expSec = (payload['exp'] as num?)?.toInt() ?? 0;
      final rawScopes = payload['scp'];
      final scopes = rawScopes is List
          ? rawScopes.map((e) => e.toString()).toList()
          : <String>[];
      final authLevel = payload['amr'] as String? ?? 'MFA_PIN_MAC_BOUND';

      final issuedAt = DateTime.fromMillisecondsSinceEpoch(iatSec * 1000);
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(expSec * 1000);

      if (DateTime.now().isAfter(expiresAt)) {
        return null; // Expired
      }

      if (revokedTokenIds.contains(tokenId)) {
        return null; // Blacklisted
      }

      return AuthToken(
        rawToken: rawToken,
        tokenId: tokenId,
        subjectId: sub,
        subjectName: name,
        role: role,
        tokenType: type,
        familyId: fam,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        scopes: scopes,
        authLevel: authLevel,
      );
    } catch (_) {
      return null;
    }
  }

  static int _tokenSequence = 0;

  // --- Internal Helper: Terbitkan Token Baru Bertanda Tangan ---
  static AuthToken _issueToken({
    required String subjectId,
    required String subjectName,
    required String role,
    required String tokenType,
    required String familyId,
    required Duration duration,
    List<String> scopes = const [],
    String authLevel = 'MFA_PIN_MAC_BOUND',
    Map<String, dynamic> customClaims = const {},
  }) {
    final now = DateTime.now();
    final expires = now.add(duration);
    final prefix = tokenType == 'refresh' ? 'RTK' : 'ATK';
    final seq = ++_tokenSequence;
    final tokenId =
        '$prefix-${role.toUpperCase()}-${now.microsecondsSinceEpoch}-$seq-${subjectId.replaceAll("-", "")}';

    final header = {
      'alg': 'HS256',
      'typ': 'JWT',
    };

    final payload = {
      'jti': tokenId,
      'sub': subjectId,
      'name': subjectName,
      'role': role,
      'typ_kind': tokenType,
      'fam': familyId,
      'scp': scopes,
      'amr': authLevel,
      'iss': 'KOPKAR-PT-BBM-SECURITY-GATEWAY',
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': expires.millisecondsSinceEpoch ~/ 1000,
      ...customClaims,
    };

    final rawToken = _createSignedJwt(header, payload);

    return AuthToken(
      rawToken: rawToken,
      tokenId: tokenId,
      subjectId: subjectId,
      subjectName: subjectName,
      role: role,
      tokenType: tokenType,
      familyId: familyId,
      issuedAt: now,
      expiresAt: expires,
      scopes: scopes,
      authLevel: authLevel,
    );
  }

  static String _createSignedJwt(
    Map<String, dynamic> header,
    Map<String, dynamic> payload,
  ) {
    final hStr = _base64UrlEncode(utf8.encode(jsonEncode(header)));
    final pStr = _base64UrlEncode(utf8.encode(jsonEncode(payload)));
    final signingInput = '$hStr.$pStr';

    final hmac = Hmac(sha256, utf8.encode(_serverSecret));
    final digest = hmac.convert(utf8.encode(signingInput));
    final sStr = _base64UrlEncode(digest.bytes);

    return '$hStr.$pStr.$sStr';
  }

  static String _base64UrlEncode(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static List<int> _base64UrlDecode(String str) {
    String norm = str.replaceAll('-', '+').replaceAll('_', '/');
    while (norm.length % 4 != 0) {
      norm += '=';
    }
    return base64.decode(norm);
  }
}
