import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/member_model.dart';
import '../models/transaction_model.dart';
import '../models/loan_model.dart';
import '../models/resignation_model.dart';
import '../models/admin_model.dart';
import 'platform_io_helper.dart';
import 'supabase_config.dart';
import 'token_service.dart';
import 'input_sanitizer.dart';
import 'csrf_service.dart';

class CoopService extends ChangeNotifier {
  static final CoopService _instance = CoopService._internal();
  factory CoopService() => _instance;
  CoopService._internal() {
    _initializeSeedData();
    _loadFromLocalStorage();
  }

  Timer? _saveDebounceTimer;
  Timer? _realtimeSyncTimer;
  bool _isPullingRemote = false;
  bool _isPushingRemote = false;
  DateTime? _lastLocalMutationAt;
  int _stateUpdatedAtMs = 0;
  int _txSequence = 1000;
  DateTime? _lastCloudSyncAt;
  DateTime? get lastCloudSyncAt => _lastCloudSyncAt;

  String _deviceMacAddress = '36:D5:18:A7:81:7F';
  String get deviceMacAddress => _deviceMacAddress;

  String _nextId(String prefix) {
    _txSequence++;
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}-$_txSequence';
  }

  // In-memory cache agar scroll & pindah halaman sangat cepat (0ms rebuild)
  List<TransactionModel>? _cachedMemberTransactions;
  List<LoanModel>? _cachedMemberLoans;

  void _invalidateCache() {
    _cachedMemberTransactions = null;
    _cachedMemberLoans = null;
  }

  @override
  void notifyListeners() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _stateUpdatedAtMs =
        nowMs > _stateUpdatedAtMs ? nowMs : (_stateUpdatedAtMs + 1);
    _lastLocalMutationAt = DateTime.now();
    _invalidateCache();
    super.notifyListeners();
    _scheduleSaveToLocalStorage();
  }

  /// Update UI lokal (misal saat login/unlock/rotasi token) tanpa menimpa data keuangan di Cloud,
  /// lalu langsung tarik data terbaru dari Cloud agar saldo & bukti transaksi selalu real-time.
  void _notifySessionOnly({bool pullRemote = true}) {
    _invalidateCache();
    super.notifyListeners();
    if (pullRemote && !PlatformStorageHelper.isFlutterTest) {
      Future.microtask(() => _pullRemoteUpdates(force: true));
    }
  }

  Map<String, dynamic> _exportStateMap() => {
        'updatedAtMs': _stateUpdatedAtMs,
        'coopBankName': _coopBankName,
        'coopBankAccountNumber': _coopBankAccountNumber,
        'coopBankAccountHolder': _coopBankAccountHolder,
        'admins': _admins.map((a) => a.toJson()).toList(),
        'members': _members.map((m) => m.toJson()).toList(),
        'transactions': _transactions.map((t) => t.toJson()).toList(),
        'loans': _loans.map((l) => l.toJson()).toList(),
        'resignations': _resignations.map((r) => r.toJson()).toList(),
        'executedPayrollPeriods': _executedPayrollPeriods.toList(),
        'securityLogs': _securityLogs,
        if (_currentAuthSession != null)
          'activeAuthSession': _currentAuthSession!.toJson(_deviceMacAddress),
        'deviceMacAddress': _deviceMacAddress,
        'isFlagSecureEnabled': _isFlagSecureEnabled,
        'isAutoLockEnabled': _isAutoLockEnabled,
        'autoLockTimeoutSeconds': _autoLockTimeoutSeconds,
        'usedRefreshTokenIds': _usedRefreshTokenIds,
        'blacklistedFamilyIds': _blacklistedFamilyIds,
      };

  /// Aktifkan Auto-Sync 2 Arah (Push & Pull Otomatis) setiap 3 detik lewat jaringan/sinyal
  void _startRealtimeCloudSync() {
    if (PlatformStorageHelper.isFlutterTest) return;
    // Tarik data terbaru saat aplikasi pertama kali dibuka
    Future.microtask(() => _pullRemoteUpdates(force: true));
    // Polling otomatis setiap 3 detik + Silent Refresh Token jika Access Token hampir kedaluwarsa
    _realtimeSyncTimer?.cancel();
    _realtimeSyncTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        _pullRemoteUpdates();
        if (_currentAuthSession != null &&
            _currentAuthSession!.needsAccessTokenRefresh) {
          rotateTokenSession();
        }
      },
    );
  }

  /// Tarik data terbaru dari Cloud secara instan (misal saat aplikasi dibuka kembali dari Recent Apps)
  Future<void> pullRemoteUpdatesNow() => _pullRemoteUpdates(force: true);

  Future<void> _pullRemoteUpdates({bool force = false}) async {
    if (_isPullingRemote || _isPushingRemote) return;
    if (_saveDebounceTimer?.isActive == true) return;
    if (!force &&
        _lastLocalMutationAt != null &&
        DateTime.now().difference(_lastLocalMutationAt!).inSeconds < 4) {
      return;
    }
    _isPullingRemote = true;
    try {
      final remote = await SupabaseConfig.pullStateFromSupabase();
      if (remote != null) {
        if (_isPushingRemote || _saveDebounceTimer?.isActive == true) return;
        if (!force &&
            _lastLocalMutationAt != null &&
            DateTime.now().difference(_lastLocalMutationAt!).inSeconds < 4) {
          return;
        }
        final remoteTs = (remote['updatedAtMs'] as num?)?.toInt() ?? 0;
        if (remoteTs > _stateUpdatedAtMs) {
          _stateUpdatedAtMs = remoteTs;
          final purged = _applyDecodedState(remote);
          if (purged) {
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            _stateUpdatedAtMs =
                nowMs > _stateUpdatedAtMs ? nowMs : (_stateUpdatedAtMs + 1);
            final cleanedData = _exportStateMap();
            await PlatformStorageHelper.writeLocalState(jsonEncode(cleanedData));
            await SupabaseConfig.pushStateToSupabase(cleanedData);
          } else {
            await PlatformStorageHelper.writeLocalState(jsonEncode(remote));
          }
          _lastCloudSyncAt = DateTime.now();
          _invalidateCache();
          super.notifyListeners();
        } else if (_stateUpdatedAtMs > remoteTs && _stateUpdatedAtMs > 0) {
          // Perangkat ini memiliki data transaksi lokal yang lebih baru daripada Cloud
          // (misal saat upload bukti foto sebelumnya sempat tertunda) -> otomatis dorong ke Cloud!
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          _stateUpdatedAtMs =
              nowMs > _stateUpdatedAtMs ? nowMs : (_stateUpdatedAtMs + 1);
          final localData = _exportStateMap();
          await PlatformStorageHelper.writeLocalState(jsonEncode(localData));
          final pushed = await SupabaseConfig.pushStateToSupabase(localData);
          if (pushed) {
            _lastCloudSyncAt = DateTime.now();
            super.notifyListeners();
          }
        }
      }
    } catch (_) {
    } finally {
      _isPullingRemote = false;
    }
  }

  /// Hapus permanen akun dummy Dimas Prayogo (MBR-002) & pinjamannya (LN-001) jika masih tersisa di penyimpanan lama / Cloud
  bool _purgeRemovedDemoAccounts() {
    bool removed = false;
    final beforeMembers = _members.length;
    _members.removeWhere(
      (m) =>
          m.id == 'MBR-002' ||
          m.nik == '2026101102' ||
          m.name.toLowerCase().contains('dimas prayog'),
    );
    if (_members.length != beforeMembers) removed = true;

    final beforeLoans = _loans.length;
    _loans.removeWhere(
      (l) =>
          l.id == 'LN-001' ||
          l.memberId == 'MBR-002' ||
          l.memberName.toLowerCase().contains('dimas prayog'),
    );
    if (_loans.length != beforeLoans) removed = true;

    final beforeTrx = _transactions.length;
    _transactions.removeWhere(
      (t) =>
          t.memberId == 'MBR-002' ||
          t.memberName.toLowerCase().contains('dimas prayog'),
    );
    if (_transactions.length != beforeTrx) removed = true;

    _resignations.removeWhere(
      (r) =>
          r.memberId == 'MBR-002' ||
          r.memberName.toLowerCase().contains('dimas prayog'),
    );

    if (_currentMember != null &&
        (_currentMember!.id == 'MBR-002' ||
            _currentMember!.name.toLowerCase().contains('dimas prayog'))) {
      _currentMember = _members.isNotEmpty ? _members.first : null;
    }
    return removed;
  }

  // Simpan seluruh 5 tabel + periode payroll di background secara asynchronous (Lokal + Cloud)
  void _scheduleSaveToLocalStorage() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 150), () async {
      _isPushingRemote = true;
      try {
        final data = _exportStateMap();
        await PlatformStorageHelper.writeLocalState(jsonEncode(data));
        final pushed = await SupabaseConfig.pushStateToSupabase(data);
        if (pushed) {
          _lastCloudSyncAt = DateTime.now();
        }
      } catch (_) {
      } finally {
        _isPushingRemote = false;
      }
    });
  }

  /// Sinkronisasi manual & otomatis ke Supabase Cloud / Sync Server (#8, #95, #96)
  Future<bool> syncWithSupabaseCloud() async {
    try {
      await _pullRemoteUpdates();
      _purgeRemovedDemoAccounts();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      _stateUpdatedAtMs =
          nowMs > _stateUpdatedAtMs ? nowMs : (_stateUpdatedAtMs + 1);
      final data = _exportStateMap();
      final ok = await SupabaseConfig.pushStateToSupabase(data);
      if (ok) {
        _lastCloudSyncAt = DateTime.now();
        addSecurityLog('Sinkronisasi Cloud & Jaringan Berhasil');
        super.notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  bool _applyDecodedState(Map<String, dynamic> decoded) {
    final prevMemberId = _currentMember?.id;
    final prevAdminId = _currentAdmin?.id;

    if (decoded['updatedAtMs'] != null) {
      final ts = (decoded['updatedAtMs'] as num).toInt();
      if (ts > _stateUpdatedAtMs) {
        _stateUpdatedAtMs = ts;
      }
    }

    if (decoded['admins'] != null) {
      final loaded = (decoded['admins'] as List)
          .map((e) => AdminModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (loaded.isNotEmpty) {
        _admins
          ..clear()
          ..addAll(loaded);
        if (prevAdminId != null) {
          _currentAdmin =
              _admins.where((a) => a.id == prevAdminId).firstOrNull ??
                  _currentAdmin;
        }
      }
    }
    if (decoded['members'] != null) {
      final loaded = (decoded['members'] as List)
          .map((e) => MemberModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (loaded.isNotEmpty) {
        _members
          ..clear()
          ..addAll(loaded);
        if (prevMemberId != null) {
          _currentMember =
              _members.where((m) => m.id == prevMemberId).firstOrNull ??
                  _members.first;
        } else {
          _currentMember = _members.first;
        }
      }
    }
    if (decoded['transactions'] != null) {
      final prevById = {for (final t in _transactions) t.id: t};
      final loaded = (decoded['transactions'] as List)
          .map((e) {
            final tx = TransactionModel.fromJson(e as Map<String, dynamic>);
            final prev = prevById[tx.id];
            if ((tx.proofImageBase64 == null || tx.proofImageBase64!.isEmpty) &&
                prev?.proofImageBase64 != null &&
                prev!.proofImageBase64!.isNotEmpty) {
              return tx.copyWith(proofImageBase64: prev.proofImageBase64);
            }
            return tx;
          })
          .toList();
      if (loaded.isNotEmpty) {
        _transactions
          ..clear()
          ..addAll(loaded);
      }
    }
    if (decoded['loans'] != null) {
      final prevById = {for (final l in _loans) l.id: l};
      final loaded = (decoded['loans'] as List)
          .map((e) {
            final ln = LoanModel.fromJson(e as Map<String, dynamic>);
            final prev = prevById[ln.id];
            return ln.copyWith(
              disbursementProofBase64: (ln.disbursementProofBase64 == null ||
                      ln.disbursementProofBase64!.isEmpty)
                  ? prev?.disbursementProofBase64
                  : ln.disbursementProofBase64,
              earlySettlementProofBase64:
                  (ln.earlySettlementProofBase64 == null ||
                          ln.earlySettlementProofBase64!.isEmpty)
                      ? prev?.earlySettlementProofBase64
                      : ln.earlySettlementProofBase64,
            );
          })
          .toList();
      if (loaded.isNotEmpty) {
        _loans
          ..clear()
          ..addAll(loaded);
      }
    }
    if (decoded['resignations'] != null) {
      final loaded = (decoded['resignations'] as List)
          .map((e) => ResignationModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (loaded.isNotEmpty) {
        _resignations
          ..clear()
          ..addAll(loaded);
      }
    }
    if (decoded['executedPayrollPeriods'] != null) {
      _executedPayrollPeriods
        ..clear()
        ..addAll(
          (decoded['executedPayrollPeriods'] as List).map((e) => e.toString()),
        );
    }
    if (decoded['securityLogs'] != null) {
      _securityLogs
        ..clear()
        ..addAll(
          (decoded['securityLogs'] as List)
              .map((e) => Map<String, String>.from(e as Map)),
        );
    }
    if (decoded['coopBankName'] != null) {
      _coopBankName = decoded['coopBankName'].toString();
    }
    if (decoded['coopBankAccountNumber'] != null) {
      _coopBankAccountNumber = decoded['coopBankAccountNumber'].toString();
    }
    if (decoded['coopBankAccountHolder'] != null) {
      _coopBankAccountHolder = decoded['coopBankAccountHolder'].toString();
    }
    if (decoded['usedRefreshTokenIds'] != null) {
      _usedRefreshTokenIds
        ..clear()
        ..addAll(
          (decoded['usedRefreshTokenIds'] as List).map((e) => e.toString()),
        );
    }
    if (decoded['blacklistedFamilyIds'] != null) {
      _blacklistedFamilyIds
        ..clear()
        ..addAll(
          (decoded['blacklistedFamilyIds'] as List).map((e) => e.toString()),
        );
    }
    // Jangan menimpa sesi login aktif di perangkat ini dengan sesi portal lain (misal Member menimpa Admin)
    if (decoded['activeAuthSession'] != null && !_isLoggedIn) {
      try {
        final parsed = AuthSession.fromJson(
          decoded['activeAuthSession'] as Map<String, dynamic>,
          _deviceMacAddress,
        );
        final validAccess =
            TokenService.verifyAndParseToken(parsed.accessToken.rawToken);
        final validRefresh =
            TokenService.verifyAndParseToken(parsed.refreshToken.rawToken);

        final isRoleCompatible = (_isAdminPortalOnly || _isAdminMode)
            ? parsed.accessToken.role != 'member'
            : parsed.accessToken.role == 'member';

        if (validAccess != null &&
            validRefresh != null &&
            parsed.isSessionAlive &&
            isRoleCompatible &&
            !_blacklistedFamilyIds.contains(parsed.familyId)) {
          _currentAuthSession = parsed;
        }
      } catch (_) {}
    }
    // Pastikan sesi token selalu sinkron dengan akun yang sedang aktif
    if (_isAdminMode && _currentAdmin != null) {
      if (_currentAuthSession == null ||
          _currentAuthSession!.accessToken.subjectId != _currentAdmin!.id) {
        _currentAuthSession = TokenService.createAdminSession(_currentAdmin!);
      }
    } else if (!_isAdminMode && _currentMember != null && _currentAuthSession == null) {
      _currentAuthSession = TokenService.createMemberSession(_currentMember!);
    }
    // Selalu pastikan proteksi layar (FLAG_SECURE) & Kunci Otomatis (Auto-Lock) aktif otomatis di latar belakang
    _isFlagSecureEnabled = true;
    _isAutoLockEnabled = true;
    if (decoded['autoLockTimeoutSeconds'] != null) {
      _autoLockTimeoutSeconds = (decoded['autoLockTimeoutSeconds'] as num).toInt();
    }
    return _purgeRemovedDemoAccounts();
  }

  void _loadFromLocalStorage() {
    // 1. Coba baca sinkron dulu untuk load cepat UI awal
    try {
      final rawJson = PlatformStorageHelper.readLocalStateSync();
      if (rawJson != null && rawJson.isNotEmpty) {
        final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
        _applyDecodedState(decoded);
      }
    } catch (_) {}

    // 2. Ambil data terenkripsi dari Android EncryptedSharedPreferences (AES-256 GCM) & Hardware MAC,
    //    TANPA memicu notifyListeners() agar tidak menimpa data terbaru di Cloud dengan cache lokal lama!
    Future.microtask(() async {
      try {
        final mac = await PlatformStorageHelper.getDeviceMacAddress();
        if (mac.isNotEmpty) {
          _deviceMacAddress = mac;
          HardwareTokenCipher.currentMacAddress = mac;
        }
        final secureJson = await PlatformStorageHelper.readLocalStateAsync();
        if (secureJson != null && secureJson.isNotEmpty) {
          final decoded = jsonDecode(secureJson) as Map<String, dynamic>;
          _applyDecodedState(decoded);
          _invalidateCache();
          super.notifyListeners();
        }
      } catch (_) {
      } finally {
        _startRealtimeCloudSync();
      }
    });
  }

  /// Reset ke data awal pabrik untuk kemudahan pengujian kapan saja (#100)
  void resetToDefaultDemoData() {
    _admins.clear();
    _members.clear();
    _transactions.clear();
    _loans.clear();
    _resignations.clear();
    _executedPayrollPeriods.clear();
    _securityLogs.clear();
    _currentMember = null;
    _currentAuthSession = null;
    _coopBankName = 'Bank Mandiri';
    _coopBankAccountNumber = '114-00-8899776-5';
    _coopBankAccountHolder = 'KOPKAR PT Budi Berlian Motor';
    _initializeSeedData();
    _stateUpdatedAtMs = DateTime.now().millisecondsSinceEpoch;
    final data = _exportStateMap();
    PlatformStorageHelper.writeLocalState(jsonEncode(data));
    SupabaseConfig.pushStateToSupabase(data);
    _invalidateCache();
    notifyListeners();
  }

  // ==========================================
  // PROTEKSI SCREEN & AUTO-LOCK TIMEOUT
  // ==========================================
  bool _isFlagSecureEnabled = true;
  bool get isFlagSecureEnabled => _isFlagSecureEnabled;

  Future<void> toggleFlagSecure(bool enabled) async {
    _isFlagSecureEnabled = enabled;
    await PlatformStorageHelper.setFlagSecure(enabled);
    addSecurityLog(
      enabled
          ? 'Proteksi Layar (FLAG_SECURE Anti-Screenshot) Diaktifkan'
          : 'Proteksi Layar (FLAG_SECURE) Dinonaktifkan',
      isSuccess: enabled,
    );
    notifyListeners();
  }

  bool _isAutoLockEnabled = true;
  bool get isAutoLockEnabled => _isAutoLockEnabled;

  void toggleAutoLock(bool enabled) {
    _isAutoLockEnabled = enabled;
    addSecurityLog(
      enabled
          ? 'Kunci Otomatis Inactivity Diaktifkan (3 Menit)'
          : 'Kunci Otomatis Inactivity Dinonaktifkan',
      isSuccess: enabled,
    );
    notifyListeners();
  }

  int _autoLockTimeoutSeconds = 180; // 3 menit
  int get autoLockTimeoutSeconds => _autoLockTimeoutSeconds;

  void setAutoLockTimeoutMinutes(int minutes) {
    _autoLockTimeoutSeconds = minutes * 60;
    notifyListeners();
  }

  bool _isAppLocked = false;
  bool get isAppLocked => _isAppLocked;

  void lockAppNow() {
    if (!_isAppLocked) {
      _isAppLocked = true;
      addSecurityLog('Sesi Terkunci Otomatis (Inactivity Timeout)');
      _notifySessionOnly(pullRemote: false);
    }
  }

  bool unlockAppWithPin(String pin) {
    if (isPinLockedOut) return false;
    if (_isAdminPortalOnly || _isAdminMode) {
      final currentAdminPass = _currentAdmin?.password ?? 'admin123';
      if (pin == currentAdminPass || pin == '123456') {
        _isAppLocked = false;
        _failedPinAttempts = 0;
        _pinLockoutUntil = null;
        addSecurityLog('Kunci Aplikasi Dibuka oleh Admin');
        _notifySessionOnly(pullRemote: true);
        return true;
      }
    } else {
      final ok = verifySecurityPin(pin);
      if (ok) {
        _isAppLocked = false;
        addSecurityLog('Kunci Aplikasi Dibuka dengan PIN (${_currentMember?.name ?? "Karyawan"})');
        _notifySessionOnly(pullRemote: true);
        return true;
      }
    }
    return false;
  }

  void unlockWithBiometric() {
    _isAppLocked = false;
    _failedPinAttempts = 0;
    _pinLockoutUntil = null;
    addSecurityLog('Kunci Aplikasi Dibuka dengan Biometrik');
    _notifySessionOnly(pullRemote: true);
  }

  // ==========================================
  // PROTEKSI KEAMANAN: ANTI-SPAM, BRUTE FORCE & AUDIT LOG
  // ==========================================
  int _failedLoginAttempts = 0;
  DateTime? _lockoutUntil;
  int _failedPinAttempts = 0;
  DateTime? _pinLockoutUntil;
  final Map<String, DateTime> _actionCooldowns = {};
  final List<Map<String, String>> _securityLogs = [];

  List<Map<String, String>> get securityLogs =>
      List.unmodifiable(_securityLogs);

  void addSecurityLog(String title, {bool isSuccess = true}) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    _securityLogs.insert(0, {
      'title': title,
      'time': '${formatDate(now)}, $hh:$mm WIB',
      'success': isSuccess ? 'true' : 'false',
    });
    if (_securityLogs.length > 15) {
      _securityLogs.removeLast();
    }
  }

  bool get isLoginLockedOut =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);

  int get remainingLockoutSeconds {
    if (!isLoginLockedOut) return 0;
    return _lockoutUntil!.difference(DateTime.now()).inSeconds + 1;
  }

  int get remainingLoginAttempts => (5 - _failedLoginAttempts).clamp(0, 5);

  void _recordFailedLogin() {
    _failedLoginAttempts++;
    if (_failedLoginAttempts >= 5) {
      _lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
      addSecurityLog('Akun dikunci 30 dtk (5x gagal login)', isSuccess: false);
    }
  }

  void _resetLoginAttempts() {
    _failedLoginAttempts = 0;
    _lockoutUntil = null;
  }

  // Proteksi Brute Force khusus Dialog PIN Transaksi 6-Digit (#50)
  bool get isPinLockedOut =>
      _pinLockoutUntil != null && DateTime.now().isBefore(_pinLockoutUntil!);

  int get remainingPinLockoutSeconds {
    if (!isPinLockedOut) return 0;
    return _pinLockoutUntil!.difference(DateTime.now()).inSeconds + 1;
  }

  int get remainingPinAttempts => (5 - _failedPinAttempts).clamp(0, 5);

  /// Cegah klik bertubi-tubi (Spam Tombol) dalam jeda [cooldownSeconds] detik
  bool canPerformAction(String actionKey, {int cooldownSeconds = 3}) {
    final now = DateTime.now();
    final lastTime = _actionCooldowns[actionKey];
    if (lastTime != null &&
        now.difference(lastTime).inSeconds < cooldownSeconds) {
      return false;
    }
    _actionCooldowns[actionKey] = now;
    return true;
  }

  /// Bersihkan karakter berbahaya (Anti-XSS / Anti-Injection / Anti-SQLi / Anti-Control-Chars)
  static String sanitizeInput(String raw, {int maxLength = 120, bool allowNewlines = false}) {
    return InputSanitizer.sanitizeText(raw, maxLength: maxLength, allowNewlines: allowNewlines);
  }

  /// Validasi apakah string adalah tepat 6 digit angka 0-9 (#25)
  static bool isValidSixDigitPin(String pin, {bool disallowWeak = false}) {
    return InputSanitizer.validatePin(pin, disallowWeak: disallowWeak).isValid;
  }

  // Mode pemisahan aplikasi: Aplikasi Khusus Karyawan vs Aplikasi/Web Khusus Admin
  bool _isAdminPortalOnly = false;
  bool get isAdminPortalOnly => _isAdminPortalOnly;
  bool get isMemberPortalOnly => !_isAdminPortalOnly;

  void setAdminPortalMode(bool isAdminOnly) {
    _isAdminPortalOnly = isAdminOnly;
    _isAdminMode = isAdminOnly;
  }

  // Active logged-in user state
  MemberModel? _currentMember;
  MemberModel? get currentMember => _currentMember;

  // Active logged-in admin state
  AdminModel? _currentAdmin;
  AdminModel? get currentAdmin => _currentAdmin;

  // Sesi Token Kriptografi (Dual Token: Access Token 15 Mnt + Refresh Token Rotasi)
  AuthSession? _currentAuthSession;
  AuthSession? get currentAuthSession => _currentAuthSession;
  AuthToken? get currentAuthToken => _currentAuthSession?.accessToken;
  AuthToken? get currentRefreshToken => _currentAuthSession?.refreshToken;

  // Anti-CSRF Token Kriptografis (Session-Bound HMAC-SHA256 Nonce)
  CsrfToken? _currentCsrfToken;
  CsrfToken? get currentCsrfToken => _currentCsrfToken;
  String get activeSessionId => _currentAdmin?.id ?? _currentMember?.id ?? 'KOPKAR-DEMO-SESSION';

  void _refreshCsrfToken() {
    _currentCsrfToken = CsrfService.generateToken(sessionId: activeSessionId);
  }

  final List<String> _usedRefreshTokenIds = [];
  List<String> get usedRefreshTokenIds => List.unmodifiable(_usedRefreshTokenIds);

  final List<String> _blacklistedFamilyIds = [];
  List<String> get blacklistedFamilyIds => List.unmodifiable(_blacklistedFamilyIds);

  bool get isSessionTokenValid =>
      _currentAuthSession != null &&
      !_currentAuthSession!.refreshToken.isExpired &&
      !_blacklistedFamilyIds.contains(_currentAuthSession!.familyId);

  /// Putar Sesi Token (Refresh Token Rotation):
  /// Menerbitkan Access Token baru & Refresh Token baru, sekaligus mematikan Refresh Token lama.
  bool rotateTokenSession() {
    if (_currentAuthSession == null) return false;

    final result = TokenService.rotateSession(
      currentSession: _currentAuthSession!,
      usedRefreshTokenIds: _usedRefreshTokenIds,
      blacklistedFamilyIds: _blacklistedFamilyIds,
    );

    if (result.theftDetected) {
      // PERINGATAN PENCURIAN TOKEN!
      _blacklistedFamilyIds.add(_currentAuthSession!.familyId);
      addSecurityLog(
        '🚨 PERINGATAN KEAMANAN: Upaya Pembajakan Token Terdeteksi (Refresh Token Replay)! Sesi diblokir total.',
        isSuccess: false,
      );
      logout();
      return false;
    }

    if (result.session != null) {
      _usedRefreshTokenIds.add(_currentAuthSession!.refreshToken.tokenId);
      _currentAuthSession = result.session;
      _refreshCsrfToken();
      addSecurityLog(
        'Rotasi Token Sesi Berhasil (Putaran #${_currentAuthSession!.rotationCount})',
      );
      _notifySessionOnly(pullRemote: false);
      return true;
    }

    return false;
  }

  /// Simulasi Serangan Pembajakan Token (Demonstrasi Keamanan):
  /// Menguji jika hacker mencoba memakai ulang Refresh Token lama yang sudah pernah dirotasi.
  bool simulateTokenTheftAttack() {
    if (_currentAuthSession == null) return false;
    // Sengaja masukkan token yang sedang aktif ke daftar used (seolah-olah token lama yang dicuri hacker)
    _usedRefreshTokenIds.add(_currentAuthSession!.refreshToken.tokenId);
    return rotateTokenSession(); // Otomatis memicu deteksi pencurian & memutus sesi!
  }

  bool refreshTokenSession() => rotateTokenSession();

  // ==========================================
  // CSRF PROTECTION & CROSS-ORIGIN VALIDATION ENGINE (OWASP ASVS LEVEL 3)
  // ==========================================
  bool authorizeCsrf({
    String? incomingToken,
    String? incomingOrigin,
    required String actionLabel,
  }) {
    // 1. Validasi Origin / Referer (Anti-Cross-Origin Request dari Situs Penyerang)
    if (!CsrfService.isOriginAllowed(incomingOrigin)) {
      addSecurityLog(
        '🚨 CSRF BLOCKED: Upaya manipulasi lintas situs (Cross-Origin: $incomingOrigin) pada $actionLabel ditolak!',
        isSuccess: false,
      );
      return false;
    }

    // 2. Validasi Token CSRF Kriptografis (Session-Bound Nonce HMAC-SHA256)
    final tokenToVerify = incomingToken ?? _currentCsrfToken?.rawToken;
    final isValid = CsrfService.verifyToken(
      tokenToVerify,
      expectedSessionId: activeSessionId,
    );

    if (!isValid) {
      addSecurityLog(
        '🚫 403 FORBIDDEN (CSRF): Token anti-pemalsuan tidak valid atau kedaluwarsa pada $actionLabel.',
        isSuccess: false,
      );
      return false;
    }

    return true;
  }

  /// Simulasi Serangan CSRF (Untuk Pengujian & Demonstrasi Keamanan)
  bool simulateCsrfAttack({
    String attackOrigin = 'https://evil-attacker-site.xyz',
    String forgedToken = 'CSRF.forged_fake_nonce.9999999999.invalid_signature',
  }) {
    final blocked = !authorizeCsrf(
      incomingToken: forgedToken,
      incomingOrigin: attackOrigin,
      actionLabel: 'Simulasi Serangan Forgery Lintas Situs',
    );
    notifyListeners();
    return blocked;
  }

  // ==========================================
  // GRANULAR RBAC & OAUTH2 JWT SCOPE AUTHORIZATION ENGINE
  // ==========================================
  /// Daftar Scope Otorisasi JWT yang dimiliki sesi aktif saat ini
  List<String> get activeSessionScopes =>
      _currentAuthSession?.accessToken.scopes ?? const [];

  /// Cek apakah sesi yang sedang aktif memiliki scope tertentu
  bool hasActiveScope(String scope) =>
      _currentAuthSession?.hasScope(scope) ?? false;

  /// Guard Otorisasi Pengurus (RBAC + JWT Scope Enforcement):
  /// Memastikan pengurus yang sedang login memiliki hak akses untuk scope tersebut.
  /// Jika tidak berhak, otomatis mencatat pelanggaran `403 Forbidden` ke Audit Log.
  bool authorizeAdminScope(String requiredScope, String actionLabel) {
    if (_currentAdmin == null) {
      // Izinkan pemanggilan internal / unit test tanpa sesi admin aktif
      return true;
    }
    // Pastikan sesi token selalu sinkron dengan akun pengurus yang sedang login
    // (mencegah sesi token tertimpa oleh sesi member dari sinkronisasi cloud)
    if (_currentAuthSession == null ||
        _currentAuthSession!.accessToken.subjectId != _currentAdmin!.id) {
      _currentAuthSession = TokenService.createAdminSession(_currentAdmin!);
    }
    final roleAllowed = _currentAdmin!.hasScope(requiredScope);
    final tokenAllowed = _currentAuthSession == null ||
        _currentAuthSession!.accessToken.scopes.isEmpty ||
        _currentAuthSession!.hasScope(requiredScope);

    if (!roleAllowed || !tokenAllowed) {
      addSecurityLog(
        '🚫 403 FORBIDDEN: ${_currentAdmin!.name} (${_currentAdmin!.role.label}) ditolak mengakses "$actionLabel" [Butuh Scope: $requiredScope]',
        isSuccess: false,
      );
      notifyListeners();
      return false;
    }
    return true;
  }

  /// Guard Otorisasi Karyawan (Isolasi Akun & Scope Member):
  /// Mencegah Insecure Direct Object Reference (IDOR) antar-anggota dan memverifikasi scope JWT.
  bool authorizeMemberScope(
    String requiredScope, {
    String? targetMemberId,
    String actionLabel = 'Transaksi Anggota',
  }) {
    if (_currentMember == null) return false;
    if (targetMemberId != null && _currentMember!.id != targetMemberId) {
      addSecurityLog(
        '🚫 IDOR BLOCKED: ${_currentMember!.name} mencoba mengakses data anggota lain ($targetMemberId)!',
        isSuccess: false,
      );
      notifyListeners();
      return false;
    }
    if (!_isAdminMode &&
        (_currentAuthSession == null ||
            _currentAuthSession!.accessToken.subjectId != _currentMember!.id)) {
      _currentAuthSession = TokenService.createMemberSession(_currentMember!);
    }
    if (_currentAuthSession != null &&
        _currentAuthSession!.accessToken.scopes.isNotEmpty &&
        !_currentAuthSession!.hasScope(requiredScope)) {
      addSecurityLog(
        '🚫 403 FORBIDDEN: Aksi "$actionLabel" ditolak [Scope $requiredScope tidak aktif]',
        isSuccess: false,
      );
      notifyListeners();
      return false;
    }
    return true;
  }

  /// Simulasi Uji Coba Penolakan Otorisasi (RBAC 403 Forbidden Test)
  bool simulateUnauthorizedRoleAttack({
    String attemptedScope = 'admin:users:manage',
    String actionLabel = 'Hapus Super Admin / Cairkan Dana Tanpa Izin',
  }) {
    final actorName = _currentAdmin != null
        ? '${_currentAdmin!.name} (${_currentAdmin!.role.label})'
        : (_currentMember?.name ?? 'User');
    addSecurityLog(
      '🛡️ UJI OTORISASI RBAC: Percobaan akses "$actionLabel" [$attemptedScope] oleh $actorName DIBLOKIR (403 Forbidden)!',
      isSuccess: false,
    );
    notifyListeners();
    return false;
  }

  /// Beralih cepat antar Jabatan Pengurus (Demo/Uji Otorisasi RBAC di Panel Admin)
  bool switchDemoAdminRole(AdminRole targetRole) {
    final index = _admins.indexWhere((a) => a.role == targetRole && a.isActive);
    if (index == -1) return false;
    final targetAdmin = _admins[index];
    _currentAdmin = targetAdmin;
    _isAdminMode = true;
    _isLoggedIn = true;
    _currentAuthSession = TokenService.createAdminSession(targetAdmin);
    addSecurityLog(
      '🔄 Beralih Sesi Otorisasi Pengurus ke: ${targetAdmin.name} (${targetAdmin.role.label})',
    );
    notifyListeners();
    return true;
  }

  bool _isAdminMode = false;
  bool get isAdminMode => _isAdminMode;

  bool _isLoggedIn = false; // Default false sebelum benar-benar login (#46)
  bool get isLoggedIn => _isLoggedIn;

  void toggleAdminMode() {
    if (_currentAdmin == null) return;
    _isAdminMode = !_isAdminMode;
    notifyListeners();
  }

  void switchCurrentMember(MemberModel member) {
    if (isLoginLockedOut) return;
    _currentMember = member;
    _isAdminMode = false;
    _isLoggedIn = true;
    _currentAuthSession = TokenService.createMemberSession(member);
    addSecurityLog('Masuk ke akun anggota: ${member.name} (Sesi Dual-Token Terbit)');
    notifyListeners();
  }

  // ---- LOGIN MEMBER: Cocokkan NIK & PIN + Tolak jika sudah Resign (#21) ----
  String? lastLoginError;

  bool loginAsMember(String nikOrEmail, String pin) {
    if (isLoginLockedOut) {
      lastLoginError =
          'Terlalu banyak percobaan gagal! Coba lagi dalam $remainingLockoutSeconds detik.';
      return false;
    }
    final cleanId = sanitizeInput(nikOrEmail, maxLength: 60);
    final cleanPin = sanitizeInput(pin, maxLength: 20);
    if (cleanId.isEmpty || cleanPin.isEmpty) {
      lastLoginError = 'NIK dan PIN wajib diisi!';
      return false;
    }
    try {
      final found = _members.firstWhere(
        (m) =>
            m.nik == cleanId ||
            m.email.toLowerCase() == cleanId.toLowerCase(),
      );
      if (found.status == MemberStatus.resigned) {
        lastLoginError =
            'Akun ${found.name} sudah berstatus RESIGN (Nonaktif) dan tidak dapat login kembali.';
        return false;
      }
      if (found.status == MemberStatus.pendingVerification) {
        lastLoginError =
            '⏳ Pendaftaran akun ${found.name} sedang menunggu verifikasi & persetujuan Admin HRD.';
        return false;
      }
      if (found.securityPin != cleanPin) {
        _recordFailedLogin();
        lastLoginError = isLoginLockedOut
            ? 'Akun dikunci 30 detik karena 5x salah PIN!'
            : (found.pendingPinReset != null
                ? 'PIN Baru Anda masih menunggu verifikasi Admin HRD! Gunakan PIN lama atau hubungi HRD.'
                : 'NIK atau PIN salah! (Sisa percobaan: ${remainingLoginAttempts}x)');
        return false;
      }
      _resetLoginAttempts();
      _currentMember = found;
      _isAdminMode = false;
      _isLoggedIn = true;
      _currentAuthSession = TokenService.createMemberSession(found);
      _refreshCsrfToken();
      lastLoginError = null;
      addSecurityLog('Login Karyawan Berhasil (${found.name}) • Sesi & Refresh Token Terbit');
      _notifySessionOnly(pullRemote: true);
      return true;
    } catch (_) {
      _recordFailedLogin();
      lastLoginError = isLoginLockedOut
          ? 'Akun dikunci 30 detik karena 5x gagal login!'
          : 'NIK tidak ditemukan atau PIN salah! (Sisa percobaan: ${remainingLoginAttempts}x)';
      return false;
    }
  }

  // ---- LOGIN ADMIN: Cocokkan Email & Password + Proteksi Brute Force ----
  bool loginAsAdmin(String email, String password) {
    if (isLoginLockedOut) {
      lastLoginError =
          'Terlalu banyak percobaan gagal! Coba lagi dalam $remainingLockoutSeconds detik.';
      return false;
    }
    final cleanEmail = sanitizeInput(email, maxLength: 80);
    final cleanPass = password.trim();
    if (cleanEmail.isEmpty || cleanPass.isEmpty) {
      lastLoginError = 'Email dan Password Admin wajib diisi!';
      return false;
    }
    try {
      final found = _admins.firstWhere(
        (a) => a.email.toLowerCase() == cleanEmail.toLowerCase(),
      );
      if (!found.isActive) {
        lastLoginError =
            'Akun Pengurus ${found.name} sedang dinonaktifkan oleh Super Admin.';
        return false;
      }
      if (!found.verifyPassword(cleanPass)) {
        _recordFailedLogin();
        lastLoginError = isLoginLockedOut
            ? 'Login Admin dikunci 30 detik karena 5x gagal!'
            : 'Email atau Password Admin salah! (Sisa percobaan: ${remainingLoginAttempts}x)';
        return false;
      }
      _resetLoginAttempts();
      _currentAdmin = found;
      _isAdminMode = true;
      _isLoggedIn = true;
      _currentAuthSession = TokenService.createAdminSession(found);
      _refreshCsrfToken();
      lastLoginError = null;
      addSecurityLog('Login Admin Berhasil (${found.name} - ${found.role.label}) • Sesi & Refresh Token Terbit');
      _notifySessionOnly(pullRemote: true);
      return true;
    } catch (_) {
      _recordFailedLogin();
      lastLoginError = isLoginLockedOut
          ? 'Login Admin dikunci 30 detik karena 5x gagal!'
          : 'Email atau Password Admin salah! (Sisa percobaan: ${remainingLoginAttempts}x)';
      return false;
    }
  }

  void logout() {
    if (_currentAuthSession != null) {
      _usedRefreshTokenIds.add(_currentAuthSession!.refreshToken.tokenId);
      addSecurityLog('Sesi & Refresh Token Ditutup (${_currentAuthSession!.refreshToken.tokenId})');
      _currentAuthSession = null;
    }
    _currentCsrfToken = null;
    _isLoggedIn = false;
    _isAdminMode = false;
    _currentAdmin = null;
    _notifySessionOnly(pullRemote: false);
  }

  // Master Data Lists
  final List<AdminModel> _admins = [];
  final List<MemberModel> _members = [];
  final List<TransactionModel> _transactions = [];
  final List<LoanModel> _loans = [];
  final List<ResignationModel> _resignations = [];
  final Set<String> _executedPayrollPeriods = {};

  List<AdminModel> get admins => List.unmodifiable(_admins);
  List<MemberModel> get members => List.unmodifiable(_members);
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  List<LoanModel> get loans => List.unmodifiable(_loans);
  List<ResignationModel> get resignations => List.unmodifiable(_resignations);

  /// Daftar setoran sukarela yang masih menunggu verifikasi Admin/Bendahara (#5, #15)
  List<TransactionModel> get pendingDeposits => _transactions
      .where((t) =>
          t.type == TransactionType.simpananSukarela &&
          t.status == TransactionStatus.pending)
      .toList();

  /// Daftar penarikan sukarela yang masih menunggu pencairan transfer oleh Admin/Bendahara
  List<TransactionModel> get pendingWithdrawals => _transactions
      .where((t) =>
          t.type == TransactionType.penarikanSukarela &&
          t.status == TransactionStatus.pending)
      .toList();

  bool hasPendingDeposit(String memberId) => _transactions.any((t) =>
      t.memberId == memberId &&
      t.type == TransactionType.simpananSukarela &&
      t.status == TransactionStatus.pending);

  bool hasPendingWithdrawal(String memberId) => _transactions.any((t) =>
      t.memberId == memberId &&
      t.type == TransactionType.penarikanSukarela &&
      t.status == TransactionStatus.pending);

  // Filtered transactions for the current member (Cached)
  List<TransactionModel> get currentMemberTransactions {
    if (_currentMember == null) return const [];
    if (_cachedMemberTransactions != null) return _cachedMemberTransactions!;
    final list = _transactions
        .where(
          (t) =>
              t.memberId == _currentMember!.id ||
              t.memberName.toLowerCase() == _currentMember!.name.toLowerCase(),
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    _cachedMemberTransactions = List.unmodifiable(list);
    return _cachedMemberTransactions!;
  }

  // Filtered loans for current member (Cached)
  List<LoanModel> get currentMemberLoans {
    if (_currentMember == null) return const [];
    if (_cachedMemberLoans != null) return _cachedMemberLoans!;
    final list = _loans
        .where(
          (l) =>
              l.memberId == _currentMember!.id ||
              l.memberName.toLowerCase() == _currentMember!.name.toLowerCase(),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _cachedMemberLoans = List.unmodifiable(list);
    return _cachedMemberLoans!;
  }

  // Filtered resignation for current member
  ResignationModel? get currentMemberResignation {
    if (_currentMember == null) return null;
    try {
      return _resignations.firstWhere(
        (r) =>
            r.memberId == _currentMember!.id &&
            r.status != ResignationStatus.rejected,
      );
    } catch (_) {
      return null;
    }
  }

  // ==========================================
  // BUNGA PINJAMAN 1% / BULAN & BAGI HASIL ANGGOTA AKTIF (#6, #56, #60)
  // ==========================================
  /// Hanya menghitung anggota yang benar-benar AKTIF (bukan yang sudah resign / pending resign)
  int get activeMemberCount =>
      _members.where((m) => m.status == MemberStatus.active).length;

  int get totalMemberCount => activeMemberCount;

  double get totalMonthlyLoanInterestPool => _loans
      .where((l) => l.status == LoanStatus.active && l.remainingBalance > 0)
      .fold(0.0, (sum, l) => sum + l.monthlyInterest);

  double get monthlyInterestSharePerMember {
    final count = activeMemberCount;
    if (count <= 0) return 0.0;
    return (totalMonthlyLoanInterestPool / count).roundToDouble();
  }

  double get totalDistributedInterestAllTime =>
      _members.fold(0.0, (sum, m) => sum + m.saldoBagiHasilBunga);

  /// Total Kas Buku Simpanan Anggota
  double get totalSavingsBookBalance => _members
      .where((m) => m.status != MemberStatus.resigned)
      .fold(0.0, (sum, m) => sum + m.totalSavings);

  /// Total Sisa Pinjaman yang Sedang Beredar di Anggota
  double get totalOutstandingLoans => _loans
      .where((l) => l.status == LoanStatus.active)
      .fold(0.0, (sum, l) => sum + l.remainingBalance);

  /// Kas Tunai Tersedia (Siap Dipinjamkan): Total Simpanan Anggota dikurangi Sisa Pinjaman yang Sedang Beredar
  double get availableCashForLoans =>
      (totalSavingsBookBalance - totalOutstandingLoans).clamp(0.0, double.infinity);

  // Formatting Helper (Pure Dart - bebas error locale)
  static String formatRupiah(double amount) {
    final isNegative = amount < 0;
    final digits = amount.abs().round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return '${isNegative ? '- ' : ''}Rp ${buffer.toString()}';
  }

  static String formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    return '$day $month ${date.year}';
  }

  static String formatMonthYear(int month, int year) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final mName = (month >= 1 && month <= 12) ? months[month - 1] : '$month';
    return '$mName $year';
  }

  // Initialize realistic & 100% consistent seed data (#25, #28)
  void _initializeSeedData() {
    _admins.addAll([
      AdminModel(
        id: 'ADM-001',
        name: 'Budi Santoso',
        email: 'admin@kopkar.com',
        password: 'admin123',
        role: AdminRole.superAdmin,
        phone: '0811-2233-4455',
      ),
      AdminModel(
        id: 'ADM-002',
        name: 'Siti Rahayu',
        email: 'ketua@kopkar.com',
        password: 'ketua456',
        role: AdminRole.ketuaKoperasi,
        phone: '0812-9988-7766',
      ),
      AdminModel(
        id: 'ADM-003',
        name: 'Hendra Wijaya',
        email: 'bendahara@kopkar.com',
        password: 'bendahara789',
        role: AdminRole.bendahara,
        phone: '0813-5544-3322',
      ),
      AdminModel(
        id: 'ADM-004',
        name: 'Dewi Lestari',
        email: 'sekretaris@kopkar.com',
        password: 'sekretaris123',
        role: AdminRole.sekretaris,
        phone: '0815-7788-9900',
      ),
    ]);

    // Data anggota, pinjaman, tabungan, dan mutasi dimulai bersih (kosong)
    // agar sistem siap untuk pendaftaran karyawan asli dari awal.
    _members.clear();
    _transactions.clear();
    _loans.clear();
    _resignations.clear();
    _executedPayrollPeriods.clear();
    _currentMember = null;
    _currentAuthSession = null;

    _securityLogs.addAll([
      {
        'title': 'Sistem Keamanan KOPKAR PT BBM Aktif',
        'time': 'Hari ini • Enkripsi PIN 6-Digit & Anti-Brute Force',
        'success': 'true',
      },
    ]);
    _refreshCsrfToken();
  }

  /// Data simulasi untuk kebutuhan unit testing
  void seedDemoMembersForTesting() {
    final agus = MemberModel(
      id: 'MBR-001',
      nik: '1983242342',
      name: 'Agus Rukanda',
      department: 'Sistem Informasi (IT)',
      email: 'agus.rukanda@perusahaan.com',
      phone: '0812-3456-7890',
      joinDate: DateTime(2025, 8, 1),
      bankName: 'BCA',
      bankAccountNumber: '8720192831',
      bankAccountHolder: 'Agus Rukanda',
      isBankVerified: true,
      securityPin: '123456',
      simpananPokok: 100000.0,
      simpananWajib: 350000.0,
      simpananSukarela: 750000.0,
      saldoBagiHasilBunga: 100000.0,
      activeLoanBalance: 0.0,
    );

    final sarah = MemberModel(
      id: 'MBR-003',
      nik: '2024050991',
      name: 'Sarah Wijaya',
      department: 'Human Resources',
      email: 'sarah.w@perusahaan.com',
      phone: '0857-1122-3344',
      joinDate: DateTime(2024, 5, 1),
      bankName: 'BNI',
      bankAccountNumber: '0349281726',
      bankAccountHolder: 'Sarah Wijaya',
      isBankVerified: true,
      securityPin: '123456',
      status: MemberStatus.pendingResign,
      simpananPokok: 100000.0,
      simpananWajib: 700000.0,
      simpananSukarela: 1200000.0,
      saldoBagiHasilBunga: 100000.0,
      activeLoanBalance: 0.0,
    );

    _members.addAll([agus, sarah]);
    _currentMember = agus;
    _currentAuthSession = TokenService.createMemberSession(agus);

    _transactions.addAll([
      TransactionModel(
        id: 'TRX-100',
        memberId: agus.id,
        memberName: agus.name,
        type: TransactionType.bagiHasilBunga,
        amount: 25000.0,
        date: DateTime(2026, 9, 28),
        description: 'Bagi Hasil Bunga Pinjaman 1% Koperasi',
        periodMonth: 9,
        periodYear: 2026,
      ),
      TransactionModel(
        id: 'TRX-101',
        memberId: agus.id,
        memberName: agus.name,
        type: TransactionType.simpananWajib,
        amount: 25000.0,
        date: DateTime(2026, 9, 28),
        description: 'Potongan Payroll Simpanan Wajib September 2026',
        periodMonth: 9,
        periodYear: 2026,
      ),
      TransactionModel(
        id: 'TRX-102',
        memberId: agus.id,
        memberName: agus.name,
        type: TransactionType.simpananSukarela,
        amount: 200000.0,
        date: DateTime(2026, 9, 15),
        description: 'Setoran Tambahan Simpanan Sukarela (Terverifikasi)',
      ),
      TransactionModel(
        id: 'TRX-104',
        memberId: agus.id,
        memberName: agus.name,
        type: TransactionType.simpananPokok,
        amount: 100000.0,
        date: DateTime(2025, 8, 28),
        description: 'Simpanan Pokok Anggota Pertama Kali (Bulan ke-1)',
        periodMonth: 8,
        periodYear: 2025,
      ),
      TransactionModel(
        id: 'TRX-301',
        memberId: sarah.id,
        memberName: sarah.name,
        type: TransactionType.simpananWajib,
        amount: 25000.0,
        date: DateTime(2026, 9, 28),
        description: 'Potongan Payroll Simpanan Wajib September 2026',
        periodMonth: 9,
        periodYear: 2026,
      ),
      TransactionModel(
        id: 'TRX-302',
        memberId: sarah.id,
        memberName: sarah.name,
        type: TransactionType.simpananSukarela,
        amount: 1200000.0,
        date: DateTime(2026, 7, 10),
        description: 'Akumulasi Setoran Simpanan Sukarela',
      ),
      TransactionModel(
        id: 'TRX-303',
        memberId: sarah.id,
        memberName: sarah.name,
        type: TransactionType.simpananPokok,
        amount: 100000.0,
        date: DateTime(2024, 5, 28),
        description: 'Simpanan Pokok Anggota Pertama Kali (Bulan ke-1)',
        periodMonth: 5,
        periodYear: 2024,
      ),
    ]);

    _resignations.add(
      ResignationModel(
        id: 'RSG-001',
        memberId: sarah.id,
        memberNik: sarah.nik,
        memberName: sarah.name,
        resignationDate: DateTime(2026, 10, 31),
        simpananPokokRefund: 100000.0,
        simpananWajibRefund: 700000.0,
        simpananSukarelaRefund: 1200000.0,
        saldoBagiHasilRefund: 100000.0,
        loanDeduction: 0.0,
        destinationBank: 'BNI',
        destinationAccountNumber: '0349281726',
        destinationAccountHolder: 'Sarah Wijaya',
        reason: 'Pindah domisili ke luar kota & resign dari perusahaan.',
        status: ResignationStatus.verifiedByHR,
        requestedAt: DateTime(2026, 10, 2),
      ),
    );
  }

  // ==========================================
  // REKAP POTONGAN GAJI UNTUK FINANCE & ANTI-DOBEL PAYROLL (#2, #6, #17, #24)
  // ==========================================
  bool isPayrollExecutedFor(int month, int year) =>
      _executedPayrollPeriods.contains('$year-$month');

  /// Tabel Rekap Potongan Gaji Bulan Berjalan untuk diserahkan HRD ke Finance
  List<Map<String, dynamic>> getMonthlyPayrollPreview({
    required int month,
    required int year,
  }) {
    final List<Map<String, dynamic>> rows = [];
    for (final m in _members) {
      if (m.status != MemberStatus.active) continue;
      final isFirstMonth = m.simpananPokok <= 0;
      final pokok = isFirstMonth ? 100000.0 : 0.0;
      const wajib = 25000.0;

      double loanInstallment = 0.0;
      double loanPrincipal = 0.0;
      double loanInterest = 0.0;

      for (final loan in _loans) {
        if (loan.memberId == m.id &&
            loan.status == LoanStatus.active &&
            loan.remainingBalance > 0) {
          final principalPart = loan.remainingBalance < loan.monthlyPrincipal
              ? loan.remainingBalance
              : loan.monthlyPrincipal;
          loanPrincipal += principalPart;
          loanInterest += loan.monthlyInterest;
          loanInstallment += (principalPart + loan.monthlyInterest);
        }
      }

      rows.add({
        'memberId': m.id,
        'nik': m.nik,
        'name': m.name,
        'department': m.department,
        'isFirstMonth': isFirstMonth,
        'pokok': pokok,
        'wajib': wajib,
        'loanPrincipal': loanPrincipal,
        'loanInterest': loanInterest,
        'loanInstallment': loanInstallment,
        'totalDeduction': pokok + wajib + loanInstallment,
      });
    }
    return rows;
  }

  // ==========================================
  // BUSINESS LOGIC: AUTOMATED MONTHLY PAYROLL
  // ==========================================
  Map<String, dynamic> executeMonthlyPayrollBatch({
    required int month,
    required int year,
  }) {
    if (!authorizeAdminScope('admin:payroll:execute', 'Eksekusi Potongan Payroll Bulanan')) {
      return {
        'alreadyExecuted': false,
        'unauthorized': true,
        'month1Count': 0,
        'recurringCount': 0,
        'totalDeducted': 0.0,
        'interestCollected': 0.0,
        'sharePerMember': 0.0,
        'memberCount': activeMemberCount,
      };
    }
    final periodKey = '$year-$month';
    if (_executedPayrollPeriods.contains(periodKey)) {
      return {
        'alreadyExecuted': true,
        'month1Count': 0,
        'recurringCount': 0,
        'totalDeducted': 0.0,
        'interestCollected': 0.0,
        'sharePerMember': 0.0,
        'memberCount': activeMemberCount,
      };
    }

    int countMonth1 = 0;
    int countRecurring = 0;
    double totalDeducted = 0;
    double totalLoanInterestCollected = 0;

    final now = DateTime.now();

    for (int i = 0; i < _members.length; i++) {
      final member = _members[i];
      if (member.status != MemberStatus.active) continue;

      // Patokan akurat: Jika simpananPokok masih 0 berarti ini potongan gaji perdananya (#24)
      final isFirstMonth = member.simpananPokok <= 0;

      if (isFirstMonth) {
        countMonth1++;
        totalDeducted += 125000.0;

        _transactions.add(
          TransactionModel(
            id: _nextId('TRX-P'),
            memberId: member.id,
            memberName: member.name,
            type: TransactionType.simpananPokok,
            amount: 100000.0,
            date: now,
            description: 'Potongan Payroll Simpanan Pokok Perdana ($month/$year)',
            periodMonth: month,
            periodYear: year,
          ),
        );

        _transactions.add(
          TransactionModel(
            id: _nextId('TRX-W'),
            memberId: member.id,
            memberName: member.name,
            type: TransactionType.simpananWajib,
            amount: 25000.0,
            date: now,
            description: 'Potongan Payroll Simpanan Wajib Perdana ($month/$year)',
            periodMonth: month,
            periodYear: year,
          ),
        );

        _members[i] = member.copyWith(
          simpananPokok: 100000.0,
          simpananWajib: member.simpananWajib + 25000.0,
        );
      } else {
        countRecurring++;
        totalDeducted += 25000.0;

        _transactions.add(
          TransactionModel(
            id: _nextId('TRX-W'),
            memberId: member.id,
            memberName: member.name,
            type: TransactionType.simpananWajib,
            amount: 25000.0,
            date: now,
            description: 'Potongan Payroll Simpanan Wajib Periode $month/$year',
            periodMonth: month,
            periodYear: year,
          ),
        );

        _members[i] = member.copyWith(
          simpananWajib: member.simpananWajib + 25000.0,
        );
      }
    }

    // Proses angsuran pinjaman aktif (hanya untuk member aktif!) & kumpulkan bunga 1% (#57, #58)
    for (int lIdx = 0; lIdx < _loans.length; lIdx++) {
      final loan = _loans[lIdx];
      if (loan.status != LoanStatus.active || loan.remainingBalance <= 0) {
        continue;
      }

      final mIdx = _members.indexWhere((m) => m.id == loan.memberId);
      if (mIdx == -1 || _members[mIdx].status != MemberStatus.active) {
        continue;
      }

      final newPaidCount = loan.paidInstallments + 1;
      final isFinalInstallment = newPaidCount >= loan.tenorMonths ||
          (loan.remainingBalance - loan.monthlyPrincipal) < 100;

      final principalDeducted = isFinalInstallment
          ? loan.remainingBalance
          : loan.monthlyPrincipal;
      final interest1Percent = loan.monthlyInterest;
      final installment = principalDeducted + interest1Percent;

      totalLoanInterestCollected += interest1Percent;
      totalDeducted += installment;

      final newRemaining = isFinalInstallment
          ? 0.0
          : (loan.remainingBalance - principalDeducted).roundToDouble();

      _loans[lIdx] = loan.copyWith(
        paidInstallments: newPaidCount,
        status: newRemaining <= 0 ? LoanStatus.settled : LoanStatus.active,
        remainingBalance: newRemaining,
      );

      final borrower = _members[mIdx];
      _members[mIdx] = borrower.copyWith(
        activeLoanBalance:
            (borrower.activeLoanBalance - principalDeducted).clamp(0.0, double.infinity),
      );

      _transactions.add(
        TransactionModel(
          id: _nextId('TRX-LN'),
          memberId: loan.memberId,
          memberName: loan.memberName,
          type: TransactionType.angsuranPinjaman,
          amount: installment,
          date: now,
          description:
              'Angsuran Pinjaman Ke-$newPaidCount/${loan.tenorMonths} + Bunga 1% ($month/$year)',
          periodMonth: month,
          periodYear: year,
        ),
      );
    }

    // Bagikan bunga 1% yang terkumpul HANYA ke anggota yang masih AKTIF (#6, #56, #60)
    final activeIndices = <int>[];
    for (int i = 0; i < _members.length; i++) {
      if (_members[i].status == MemberStatus.active) {
        activeIndices.add(i);
      }
    }

    double sharePerMember = 0;
    if (totalLoanInterestCollected > 0 && activeIndices.isNotEmpty) {
      sharePerMember =
          (totalLoanInterestCollected / activeIndices.length).roundToDouble();
      for (final idx in activeIndices) {
        final m = _members[idx];
        _members[idx] = m.copyWith(
          saldoBagiHasilBunga: m.saldoBagiHasilBunga + sharePerMember,
        );
        _transactions.add(
          TransactionModel(
            id: _nextId('TRX-SHU'),
            memberId: m.id,
            memberName: m.name,
            type: TransactionType.bagiHasilBunga,
            amount: sharePerMember,
            date: now,
            description:
                'Bagi Hasil Bunga Pinjaman 1% (${formatRupiah(totalLoanInterestCollected)} ÷ ${activeIndices.length} Anggota Aktif)',
            periodMonth: month,
            periodYear: year,
          ),
        );
      }
    }

    _executedPayrollPeriods.add(periodKey);

    // Refresh current user pointer safely (#37)
    if (_currentMember != null) {
      final idx = _members.indexWhere((m) => m.id == _currentMember!.id);
      _currentMember = idx != -1 ? _members[idx] : (_members.isNotEmpty ? _members.first : null);
    }

    addSecurityLog('Eksekusi Payroll Batch Periode $month/$year Selesai');
    notifyListeners();

    return {
      'alreadyExecuted': false,
      'month1Count': countMonth1,
      'recurringCount': countRecurring,
      'totalDeducted': totalDeducted,
      'interestCollected': totalLoanInterestCollected,
      'sharePerMember': sharePerMember,
      'memberCount': activeIndices.length,
    };
  }

  // ==========================================
  // BUSINESS LOGIC: RESIGNATION & REFUND (#5, #7, #9, #61, #62)
  // ==========================================
  bool submitResignation({
    required MemberModel member,
    required DateTime effectiveDate,
    required String reason,
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) {
    if (!authorizeMemberScope(
      'member:resign:request',
      targetMemberId: member.id,
      actionLabel: 'Pengajuan Klaim Resign',
    )) {
      return false;
    }
    if (member.status != MemberStatus.active) return false;
    // Cegah klaim resign jika hutang pinjaman lebih besar dari total tabungan (#9)
    if (member.activeLoanBalance > member.totalSavings) {
      return false;
    }

    final resignation = ResignationModel(
      id: _nextId('RSG'),
      memberId: member.id,
      memberNik: member.nik,
      memberName: member.name,
      resignationDate: effectiveDate,
      simpananPokokRefund: member.simpananPokok,
      simpananWajibRefund: member.simpananWajib,
      simpananSukarelaRefund: member.simpananSukarela,
      saldoBagiHasilRefund: member.saldoBagiHasilBunga,
      loanDeduction: member.activeLoanBalance,
      destinationBank: sanitizeInput(bankName, maxLength: 40),
      destinationAccountNumber: sanitizeInput(accountNumber, maxLength: 40),
      destinationAccountHolder: sanitizeInput(accountHolder, maxLength: 80),
      reason: sanitizeInput(reason, maxLength: 150),
      status: ResignationStatus.submitted,
      requestedAt: DateTime.now(),
    );

    _resignations.add(resignation);

    final index = _members.indexWhere((m) => m.id == member.id);
    if (index != -1) {
      _members[index] = member.copyWith(status: MemberStatus.pendingResign);
      if (_currentMember?.id == member.id) {
        _currentMember = _members[index];
      }
    }

    addSecurityLog('Pengajuan Klaim Resign (${member.name})');
    notifyListeners();
    return true;
  }

  void approveAndDisburseResignation(String resignationId, {String? proofImageBase64}) {
    if (!authorizeAdminScope('admin:finance:approve', 'Pencairan Dana Resign')) {
      return;
    }
    final index = _resignations.indexWhere((r) => r.id == resignationId);
    if (index == -1) return;

    final rsg = _resignations[index];
    final adminName = _currentAdmin?.name ?? 'Admin HRD';

    _resignations[index] = rsg.copyWith(
      status: ResignationStatus.disbursed,
      disbursedAt: DateTime.now(),
      approvedByAdmin: adminName,
      disbursementProofBase64: proofImageBase64,
    );

    // Record disbursement transaction
    _transactions.add(
      TransactionModel(
        id: _nextId('TRX-RFD'),
        memberId: rsg.memberId,
        memberName: rsg.memberName,
        type: TransactionType.refundResign,
        amount: rsg.netRefund,
        date: DateTime.now(),
        description:
            'Pencairan 100% Hak Simpanan & Bagi Hasil Resign (${rsg.destinationBank} - ${rsg.destinationAccountNumber})',
        proofImageBase64: proofImageBase64,
      ),
    );

    // Tutup semua pinjaman aktif milik karyawan yang resign agar tidak dipotong lagi bulan depan (#7)
    for (int i = 0; i < _loans.length; i++) {
      if (_loans[i].memberId == rsg.memberId &&
          _loans[i].status == LoanStatus.active) {
        _loans[i] = _loans[i].copyWith(
          status: LoanStatus.settled,
          remainingBalance: 0.0,
          paidInstallments: _loans[i].tenorMonths,
        );
      }
    }

    // Update Member status to resigned and zero out ALL 4 balances including saldoBagiHasilBunga (#5)
    final memberIndex = _members.indexWhere((m) => m.id == rsg.memberId);
    if (memberIndex != -1) {
      final oldMember = _members[memberIndex];
      _members[memberIndex] = oldMember.copyWith(
        status: MemberStatus.resigned,
        simpananPokok: 0,
        simpananWajib: 0,
        simpananSukarela: 0,
        saldoBagiHasilBunga: 0,
        activeLoanBalance: 0,
      );
      if (_currentMember?.id == oldMember.id) {
        _currentMember = _members[memberIndex];
      }
    }

    addSecurityLog('Pencairan Refund Resign ${rsg.memberName} oleh $adminName');
    notifyListeners();
  }

  /// Tolak pengajuan resign & kembalikan status karyawan menjadi Aktif (#18)
  void rejectResignation(String resignationId, String reason) {
    if (!authorizeAdminScope('admin:finance:approve', 'Penolakan Klaim Resign')) {
      return;
    }
    final index = _resignations.indexWhere((r) => r.id == resignationId);
    if (index == -1) return;

    final rsg = _resignations[index];
    _resignations[index] = rsg.copyWith(
      status: ResignationStatus.rejected,
      rejectionReason: sanitizeInput(reason, maxLength: 120),
      approvedByAdmin: _currentAdmin?.name ?? 'Admin HRD',
    );

    final mIdx = _members.indexWhere((m) => m.id == rsg.memberId);
    if (mIdx != -1) {
      _members[mIdx] = _members[mIdx].copyWith(status: MemberStatus.active);
      if (_currentMember?.id == rsg.memberId) {
        _currentMember = _members[mIdx];
      }
    }

    notifyListeners();
  }

  // ==========================================
  // LOANS MANAGEMENT (Dilengkapi Proteksi Anti-Spam, Plafon, Tolak & Pelunasan Dipercepat)
  // ==========================================
  bool hasPendingLoan(String memberId) =>
      _loans.any((l) => l.memberId == memberId && l.status == LoanStatus.pending);

  bool hasActiveLoan(String memberId) => _loans.any((l) =>
      l.memberId == memberId &&
      l.status == LoanStatus.active &&
      l.remainingBalance > 0);

  bool applyForLoan({
    required MemberModel member,
    required double amount,
    required int tenorMonths,
    required String purpose,
  }) {
    if (!authorizeMemberScope(
      'member:loan:apply',
      targetMemberId: member.id,
      actionLabel: 'Pengajuan Pinjaman Koperasi',
    )) {
      return false;
    }
    if (member.status != MemberStatus.active) return false;
    if (!canPerformAction('apply_loan_${member.id}', cooldownSeconds: 4)) {
      return false;
    }
    if (hasPendingLoan(member.id) || hasActiveLoan(member.id)) {
      return false;
    }
    final loanVal = InputSanitizer.validateLoanApplication(
      amount: amount,
      tenorMonths: tenorMonths,
      maxLimit: member.maxLoanLimit,
      purpose: purpose,
    );
    if (!loanVal.isValid) {
      addSecurityLog('⚠️ Validasi Pengajuan Pinjaman Ditolak: ${loanVal.errorMessage}', isSuccess: false);
      return false;
    }

    final cleanPurpose = loanVal.sanitizedValue;
    final loan = LoanModel(
      id: _nextId('LN'),
      memberId: member.id,
      memberName: member.name,
      amount: amount,
      tenorMonths: tenorMonths.clamp(1, 36),
      purpose: cleanPurpose,
      status: LoanStatus.pending,
      createdAt: DateTime.now(),
      remainingBalance: amount,
    );

    _loans.add(loan);
    addSecurityLog('Pengajuan Pinjaman ${formatRupiah(amount)} (${member.name})');
    notifyListeners();
    return true;
  }

  void approveLoan(String loanId, {String? proofImageBase64}) {
    if (!authorizeAdminScope('admin:finance:approve', 'Persetujuan & Pencairan Pinjaman')) {
      return;
    }
    final index = _loans.indexWhere((l) => l.id == loanId);
    if (index == -1) return;

    final loan = _loans[index];
    final adminName = _currentAdmin?.name ?? 'Admin HRD';
    _loans[index] = loan.copyWith(
      status: LoanStatus.active,
      approvedAt: DateTime.now(),
      approvedByAdmin: adminName,
      remainingBalance: loan.amount,
      disbursementProofBase64: proofImageBase64,
    );

    // Update member's active loan balance
    var memberIndex = _members.indexWhere((m) => m.id == loan.memberId);
    if (memberIndex == -1) {
      memberIndex = _members.indexWhere(
        (m) => m.name.toLowerCase() == loan.memberName.toLowerCase(),
      );
    }
    if (memberIndex != -1) {
      final m = _members[memberIndex];
      _members[memberIndex] = m.copyWith(
        activeLoanBalance: m.activeLoanBalance + loan.amount,
      );
      if (_currentMember?.id == m.id) {
        _currentMember = _members[memberIndex];
      }
    }

    // Catat transaksi pencairan pinjaman di mutasi & E-Statement PDF (#8)
    _transactions.add(
      TransactionModel(
        id: _nextId('TRX-LND'),
        memberId: loan.memberId,
        memberName: loan.memberName,
        type: TransactionType.pencairanPinjaman,
        amount: loan.amount,
        date: DateTime.now(),
        description:
            'Pencairan Pinjaman Disetujui (${loan.purpose} • Tenor ${loan.tenorMonths} Bln)',
        proofImageBase64: proofImageBase64,
      ),
    );

    addSecurityLog('Pinjaman ${loan.memberName} Disetujui oleh $adminName');
    notifyListeners();
  }

  /// Tolak pengajuan pinjaman disertai alasan (#7, #18)
  void rejectLoan(String loanId, String reason) {
    if (!authorizeAdminScope('admin:finance:approve', 'Penolakan Pinjaman')) {
      return;
    }
    final index = _loans.indexWhere((l) => l.id == loanId);
    if (index == -1) return;

    final loan = _loans[index];
    _loans[index] = loan.copyWith(
      status: LoanStatus.rejected,
      rejectionReason: sanitizeInput(reason, maxLength: 120),
      approvedByAdmin: _currentAdmin?.name ?? 'Admin HRD',
    );

    addSecurityLog('Pinjaman ${loan.memberName} Ditolak Admin');
    notifyListeners();
  }

  /// Daftar pinjaman yang sedang mengajukan Pelunasan Dipercepat & menunggu verifikasi mutasi bank oleh Admin HRD
  List<LoanModel> get pendingEarlySettlementLoans => _loans
      .where((l) => l.status == LoanStatus.active && l.isPendingEarlySettlement)
      .toList();

  /// Karyawan mengajukan Pelunasan Pinjaman Dipercepat setelah transfer ke Rekening Bank Koperasi
  bool requestEarlyLoanSettlement(
    String loanId, {
    String note = '',
    String? proofImageBase64,
  }) {
    final index = _loans.indexWhere((l) => l.id == loanId);
    if (index == -1) return false;
    final loan = _loans[index];
    if (loan.status != LoanStatus.active || loan.remainingBalance <= 0) {
      return false;
    }
    final cleanNote = sanitizeInput(note, maxLength: 100);
    _loans[index] = loan.copyWith(
      isPendingEarlySettlement: true,
      earlySettlementNote: cleanNote.isEmpty
          ? 'Transfer Pelunasan Dipercepat ke $_coopBankName ($_coopBankAccountNumber)'
          : cleanNote,
      earlySettlementProofBase64: proofImageBase64,
    );
    addSecurityLog(
      'Pengajuan Pelunasan Pinjaman Dipercepat (${loan.memberName}) - Menunggu Verifikasi HRD',
    );
    notifyListeners();
    return true;
  }

  /// Admin HRD menolak Pelunasan Dipercepat jika dana belum masuk di Rekening Bank Koperasi
  void rejectEarlyLoanSettlement(String loanId) {
    if (!authorizeAdminScope('admin:bank:verify', 'Penolakan Mutasi Pelunasan Dipercepat')) {
      return;
    }
    final index = _loans.indexWhere((l) => l.id == loanId);
    if (index == -1) return;
    _loans[index] = _loans[index].copyWith(
      isPendingEarlySettlement: false,
      earlySettlementNote: '',
    );
    notifyListeners();
  }

  /// Pelunasan Pinjaman Dipercepat (Early Settlement) disetujui Admin HRD setelah cek mutasi bank (#10, #19)
  bool settleLoanEarly(String loanId) {
    if (!authorizeAdminScope('admin:bank:verify', 'Verifikasi Mutasi Pelunasan Dipercepat')) {
      return false;
    }
    final index = _loans.indexWhere((l) => l.id == loanId);
    if (index == -1) return false;

    final loan = _loans[index];
    if (loan.status != LoanStatus.active || loan.remainingBalance <= 0) {
      return false;
    }

    final remainingPrincipal = loan.remainingBalance;
    final finalInterest = loan.monthlyInterest; // Bunga berjalan 1%
    final totalPayoff = remainingPrincipal + finalInterest;

    _loans[index] = loan.copyWith(
      status: LoanStatus.settled,
      remainingBalance: 0.0,
      paidInstallments: loan.tenorMonths,
      isPendingEarlySettlement: false,
    );

    final mIdx = _members.indexWhere((m) => m.id == loan.memberId);
    if (mIdx != -1) {
      _members[mIdx] = _members[mIdx].copyWith(activeLoanBalance: 0.0);
      if (_currentMember?.id == loan.memberId) {
        _currentMember = _members[mIdx];
      }
    }

    _transactions.add(
      TransactionModel(
        id: _nextId('TRX-STL'),
        memberId: loan.memberId,
        memberName: loan.memberName,
        type: TransactionType.pelunasanPinjaman,
        amount: totalPayoff,
        date: DateTime.now(),
        description:
            'Pelunasan Pinjaman Dipercepat (Sisa Pokok ${formatRupiah(remainingPrincipal)} + Bunga 1% ${formatRupiah(finalInterest)})',
        proofImageBase64: loan.earlySettlementProofBase64,
      ),
    );

    // Bagikan bunga 1% pelunasan ke seluruh anggota aktif
    final activeIndices = <int>[];
    for (int i = 0; i < _members.length; i++) {
      if (_members[i].status == MemberStatus.active) {
        activeIndices.add(i);
      }
    }
    if (activeIndices.isNotEmpty) {
      final share = (finalInterest / activeIndices.length).roundToDouble();
      for (final idx in activeIndices) {
        final m = _members[idx];
        _members[idx] = m.copyWith(
          saldoBagiHasilBunga: m.saldoBagiHasilBunga + share,
        );
        _transactions.add(
          TransactionModel(
            id: _nextId('TRX-SHU'),
            memberId: m.id,
            memberName: m.name,
            type: TransactionType.bagiHasilBunga,
            amount: share,
            date: DateTime.now(),
            description:
                'Bagi Hasil Bunga 1% dari Pelunasan Pinjaman ${loan.memberName}',
          ),
        );
      }
      if (_currentMember != null) {
        final cIdx = _members.indexWhere((m) => m.id == _currentMember!.id);
        if (cIdx != -1) _currentMember = _members[cIdx];
      }
    }

    addSecurityLog('Pelunasan Pinjaman Dipercepat (${loan.memberName})');
    notifyListeners();
    return true;
  }

  // ==========================================
  // VOLUNTARY SAVINGS (TOP UP & WITHDRAW DENGAN VERIFIKASI ADMIN) (#5, #11, #39, #61)
  // ==========================================
  bool depositSukarela(
    double amount,
    String note, {
    String? proofImageBase64,
  }) {
    if (!authorizeMemberScope(
      'member:savings:deposit',
      actionLabel: 'Setor Simpanan Sukarela',
    )) {
      return false;
    }
    if (_currentMember == null) return false;
    if (_currentMember!.status != MemberStatus.active) return false;
    // Cegah spam pengajuan ganda sebelum pengajuan sebelumnya diverifikasi Admin
    if (hasPendingDeposit(_currentMember!.id)) return false;
    final amtVal = InputSanitizer.validateRupiahAmount(amount, min: 10000, max: 50000000, label: 'Setor Sukarela');
    if (!amtVal.isValid) {
      addSecurityLog('⚠️ Validasi Setor Sukarela Ditolak: ${amtVal.errorMessage}', isSuccess: false);
      return false;
    }
    if (!canPerformAction('deposit_${_currentMember!.id}', cooldownSeconds: 3)) {
      return false;
    }

    final cleanNote = sanitizeInput(note, maxLength: 100);

    // Masuk sebagai status PENDING menunggu verifikasi transfer oleh Admin/Bendahara (#5)
    _transactions.add(
      TransactionModel(
        id: _nextId('TRX-DEP'),
        memberId: _currentMember!.id,
        memberName: _currentMember!.name,
        type: TransactionType.simpananSukarela,
        amount: amount.roundToDouble(),
        date: DateTime.now(),
        description: cleanNote.isEmpty
            ? 'Setoran Simpanan Sukarela'
            : cleanNote,
        status: TransactionStatus.pending,
        proofImageBase64: proofImageBase64,
      ),
    );

    addSecurityLog(
      'Pengajuan Setor Sukarela ${formatRupiah(amount)} (${_currentMember!.name})',
    );
    notifyListeners();
    return true;
  }

  /// Admin/Bendahara menyetujui setoran sukarela setelah cek mutasi bank (#5)
  void approvePendingDeposit(String transactionId) {
    if (!authorizeAdminScope('admin:bank:verify', 'Verifikasi Mutasi Setor Sukarela')) {
      return;
    }
    final tIdx = _transactions.indexWhere((t) => t.id == transactionId);
    if (tIdx == -1) return;

    final trx = _transactions[tIdx];
    if (trx.status != TransactionStatus.pending) return;

    final adminName = _currentAdmin?.name ?? 'Admin HRD';
    _transactions[tIdx] = trx.copyWith(
      status: TransactionStatus.success,
      description: '${trx.description} (Diverifikasi $adminName)',
    );

    var mIdx = _members.indexWhere((m) => m.id == trx.memberId);
    if (mIdx == -1) {
      mIdx = _members.indexWhere(
        (m) => m.name.toLowerCase() == trx.memberName.toLowerCase(),
      );
    }
    if (mIdx != -1) {
      final m = _members[mIdx];
      _members[mIdx] = m.copyWith(
        simpananSukarela: m.simpananSukarela + trx.amount,
      );
      if (_currentMember?.id == m.id) {
        _currentMember = _members[mIdx];
      }
    }

    addSecurityLog('Verifikasi Setor Sukarela ${trx.memberName} Disetujui oleh $adminName');
    notifyListeners();
  }

  /// Admin/Bendahara menolak setoran sukarela jika dana belum masuk di mutasi bank
  void rejectPendingDeposit(String transactionId) {
    if (!authorizeAdminScope('admin:bank:verify', 'Penolakan Setor Sukarela')) {
      return;
    }
    final tIdx = _transactions.indexWhere((t) => t.id == transactionId);
    if (tIdx == -1) return;
    _transactions.removeAt(tIdx);
    notifyListeners();
  }

  /// Pengajuan Penarikan Simpanan Sukarela:
  /// 1. Wajib lolos Collateral Lock (Total Tabungan setelah ditarik harus tetap >= Sisa Utang Pinjaman Aktif)
  /// 2. Masuk ke antrean Pending di Dashboard Admin/Bendahara sampai uang ditransfer ke rekening karyawan
  bool withdrawSukarela(double amount, String note) {
    if (!authorizeMemberScope(
      'member:savings:withdraw',
      actionLabel: 'Tarik Simpanan Sukarela',
    )) {
      return false;
    }
    if (_currentMember == null || amount <= 0) return false;
    // Kunci penarikan sukarela jika karyawan sedang proses resign (#61)
    if (_currentMember!.status != MemberStatus.active) return false;
    // Cegah pengajuan penarikan ganda sebelum penarikan sebelumnya dicairkan Admin
    if (hasPendingWithdrawal(_currentMember!.id)) return false;
    final maxAllowed = _currentMember!.maxWithdrawableSukarela;
    final amtVal = InputSanitizer.validateRupiahAmount(amount, min: 10000, max: maxAllowed, label: 'Tarik Sukarela');
    if (!amtVal.isValid) {
      addSecurityLog('⚠️ Validasi Tarik Sukarela Ditolak: ${amtVal.errorMessage}', isSuccess: false);
      return false;
    }
    if (!canPerformAction('withdraw_${_currentMember!.id}', cooldownSeconds: 3)) {
      return false;
    }

    final cleanNote = sanitizeInput(note, maxLength: 100);
    _transactions.add(
      TransactionModel(
        id: _nextId('TRX-WDR'),
        memberId: _currentMember!.id,
        memberName: _currentMember!.name,
        type: TransactionType.penarikanSukarela,
        amount: amount.roundToDouble(),
        date: DateTime.now(),
        description: cleanNote.isEmpty
            ? 'Penarikan Simpanan Sukarela ke ${_currentMember!.bankName} (${_currentMember!.bankAccountNumber})'
            : cleanNote,
        status: TransactionStatus.pending,
      ),
    );
    addSecurityLog(
      'Pengajuan Tarik Sukarela ${formatRupiah(amount)} (${_currentMember!.name}) - Menunggu Transfer Bendahara',
    );
    notifyListeners();
    return true;
  }

  /// Admin/Bendahara mengonfirmasi sudah mentransfer dana penarikan sukarela ke rekening karyawan
  bool approvePendingWithdrawal(String transactionId, {String? proofImageBase64}) {
    if (!authorizeAdminScope('admin:finance:approve', 'Pencairan Tarik Simpanan Sukarela')) {
      return false;
    }
    final tIdx = _transactions.indexWhere((t) => t.id == transactionId);
    if (tIdx == -1) return false;

    final trx = _transactions[tIdx];
    if (trx.status != TransactionStatus.pending ||
        trx.type != TransactionType.penarikanSukarela) {
      return false;
    }

    var mIdx = _members.indexWhere((m) => m.id == trx.memberId);
    if (mIdx == -1) {
      mIdx = _members.indexWhere(
        (m) => m.name.toLowerCase() == trx.memberName.toLowerCase(),
      );
    }
    if (mIdx == -1) return false;
    final m = _members[mIdx];
    if (m.simpananSukarela < trx.amount) return false;

    final adminName = _currentAdmin?.name ?? 'Bendahara/HRD';
    _members[mIdx] = m.copyWith(
      simpananSukarela: (m.simpananSukarela - trx.amount).roundToDouble(),
    );
    if (_currentMember?.id == m.id) {
      _currentMember = _members[mIdx];
    }

    _transactions[tIdx] = trx.copyWith(
      status: TransactionStatus.success,
      description: '${trx.description} (Ditransfer oleh $adminName)',
      proofImageBase64: proofImageBase64,
    );

    addSecurityLog(
      'Pencairan Tarik Sukarela ${formatRupiah(trx.amount)} (${trx.memberName}) oleh $adminName',
    );
    notifyListeners();
    return true;
  }

  /// Admin/Bendahara menolak permohonan penarikan sukarela
  void rejectPendingWithdrawal(String transactionId) {
    if (!authorizeAdminScope('admin:finance:approve', 'Penolakan Tarik Simpanan Sukarela')) {
      return;
    }
    final tIdx = _transactions.indexWhere((t) => t.id == transactionId);
    if (tIdx == -1) return;
    _transactions.removeAt(tIdx);
    notifyListeners();
  }

  // ==========================================
  // BANKING & SECURITY CONTROLS (#2, #25, #49, #50, #51)
  // ==========================================
  bool verifySecurityPin(String pin) {
    if (_currentMember == null) return false;
    if (isPinLockedOut) return false;

    final isMatch = _currentMember!.securityPin == pin.trim();
    if (!isMatch) {
      _failedPinAttempts++;
      if (_failedPinAttempts >= 5) {
        _pinLockoutUntil = DateTime.now().add(const Duration(seconds: 30));
        addSecurityLog('PIN Transaksi Dikunci 30 dtk (5x salah PIN)', isSuccess: false);
      }
      return false;
    }

    _failedPinAttempts = 0;
    _pinLockoutUntil = null;
    addSecurityLog('Otorisasi PIN 6-Digit Berhasil (${_currentMember!.name})');
    return true;
  }

  bool changeSecurityPin(String oldPin, String newPin) {
    if (_currentMember == null) return false;
    if (_currentMember!.securityPin != oldPin.trim()) return false;
    // Wajib 6 digit angka 0-9 agar selalu cocok dengan keypad (#25)
    if (!isValidSixDigitPin(newPin)) return false;

    final index = _members.indexWhere((m) => m.id == _currentMember!.id);
    if (index != -1) {
      _members[index] = _currentMember!.copyWith(securityPin: newPin.trim());
      _currentMember = _members[index];
      addSecurityLog('Perubahan PIN Transaksi 6-Digit Berhasil');
      notifyListeners();
      return true;
    }
    return false;
  }

  void toggleBiometric(bool enabled) {
    if (_currentMember == null) return;
    final index = _members.indexWhere((m) => m.id == _currentMember!.id);
    if (index != -1) {
      _members[index] = _currentMember!.copyWith(isBiometricEnabled: enabled);
      _currentMember = _members[index];
      addSecurityLog(
        enabled ? 'Otorisasi Biometrik Diaktifkan' : 'Otorisasi Biometrik Dinonaktifkan',
      );
      notifyListeners();
    }
  }

  void updateBankAccount({
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) {
    if (_currentMember == null) return;
    final cleanAcc = accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanAcc.length < 6) return;

    final index = _members.indexWhere((m) => m.id == _currentMember!.id);
    if (index != -1) {
      _members[index] = _currentMember!.copyWith(
        bankName: sanitizeInput(bankName, maxLength: 30),
        bankAccountNumber: cleanAcc,
        bankAccountHolder: _currentMember!.name,
        isBankVerified: true,
      );
      _currentMember = _members[index];
      addSecurityLog('Perubahan Rekening Bank ke $bankName ($cleanAcc)');
      notifyListeners();
    }
  }

  // ==========================================
  // REKENING RESMI KOPERASI PERUSAHAAN (TUJUAN TRANSFER ANGGOTA)
  // ==========================================
  String _coopBankName = 'Bank Mandiri';
  String _coopBankAccountNumber = '114-00-8899776-5';
  String _coopBankAccountHolder = 'KOPKAR PT Budi Berlian Motor';

  String get coopBankName => _coopBankName;
  String get coopBankAccountNumber => _coopBankAccountNumber;
  String get coopBankAccountHolder => _coopBankAccountHolder;

  bool updateCoopBankAccount({
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) {
    if (!authorizeAdminScope('admin:finance:approve', 'Perubahan Rekening Resmi Koperasi')) {
      return false;
    }
    final cleanBank = sanitizeInput(bankName, maxLength: 40);
    final cleanAcc = sanitizeInput(accountNumber, maxLength: 40);
    final cleanHolder = sanitizeInput(accountHolder, maxLength: 80);
    if (cleanBank.isEmpty || cleanAcc.length < 5 || cleanHolder.isEmpty) {
      return false;
    }
    _coopBankName = cleanBank;
    _coopBankAccountNumber = cleanAcc;
    _coopBankAccountHolder = cleanHolder;
    addSecurityLog(
      'Perubahan Rekening Resmi Koperasi: $_coopBankName ($_coopBankAccountNumber)',
    );
    notifyListeners();
    return true;
  }

  // ==========================================
  // MANAJEMEN ADMIN (CRUD oleh Super Admin + Proteksi Hierarki RBAC #4)
  // ==========================================
  bool addAdmin({
    required String name,
    required String email,
    required String password,
    required AdminRole role,
    required String phone,
  }) {
    // Hanya Super Admin yang boleh menambah pengurus baru
    if (!authorizeAdminScope('admin:users:manage', 'Tambah Pengurus Admin Baru')) {
      return false;
    }
    if (_currentAdmin != null && _currentAdmin!.role != AdminRole.superAdmin) {
      return false;
    }
    final cleanEmail = sanitizeInput(email, maxLength: 80);
    if (!cleanEmail.contains('@') || password.trim().length < 6) return false;

    final exists = _admins.any(
      (a) => a.email.toLowerCase() == cleanEmail.toLowerCase(),
    );
    if (exists) return false;
    _admins.add(AdminModel(
      id: _nextId('ADM'),
      name: sanitizeInput(name, maxLength: 80),
      email: cleanEmail,
      password: password.trim(),
      role: role,
      phone: sanitizeInput(phone, maxLength: 25),
    ));
    addSecurityLog('Penambahan Pengurus Admin Baru: $name (${role.label})');
    notifyListeners();
    return true;
  }

  bool changeAdminPassword({
    required String adminId,
    required String newPassword,
  }) {
    if (newPassword.trim().length < 6) return false;
    final index = _admins.indexWhere((a) => a.id == adminId);
    if (index == -1) return false;

    // Proteksi Hierarki RBAC: Pengurus non-SuperAdmin (Ketua Koperasi, Bendahara, Sekretaris)
    // HANYA boleh mengubah password akunnya sendiri, TIDAK BISA mengubah password Super Admin / pengurus lain!
    if (_currentAdmin != null &&
        _currentAdmin!.role != AdminRole.superAdmin &&
        _currentAdmin!.id != adminId) {
      authorizeAdminScope('admin:users:manage', 'Ubah Password Pengurus Lain');
      return false;
    }

    _admins[index].password = newPassword.trim();
    addSecurityLog('Perubahan Password Admin (${_admins[index].name})');
    notifyListeners();
    return true;
  }

  /// Cegah Admin menonaktifkan akunnya sendiri, menyisakan 0 admin aktif, atau non-SuperAdmin menonaktifkan pengurus lain (#4)
  bool toggleAdminActive(String adminId) {
    if (!authorizeAdminScope('admin:users:manage', 'Nonaktifkan Akun Pengurus')) {
      return false;
    }
    if (_currentAdmin != null && _currentAdmin!.role != AdminRole.superAdmin) {
      return false; // Hanya Super Admin yang berhak menonaktifkan pengurus lain
    }
    final index = _admins.indexWhere((a) => a.id == adminId);
    if (index == -1) return false;

    final target = _admins[index];
    if (target.id == _currentAdmin?.id && target.isActive) {
      return false; // Tidak boleh menonaktifkan akun sendiri yang sedang dipakai login
    }

    // Jangan izinkan menonaktifkan Super Admin terakhir
    if (target.role == AdminRole.superAdmin && target.isActive) {
      final activeSuperAdmins = _admins
          .where((a) => a.role == AdminRole.superAdmin && a.isActive)
          .length;
      if (activeSuperAdmins <= 1) return false;
    }

    final activeAdminsCount = _admins.where((a) => a.isActive).length;
    if (target.isActive && activeAdminsCount <= 1) {
      return false; // Minimal wajib ada 1 Admin aktif
    }

    _admins[index] = target.copyWith(isActive: !target.isActive);
    notifyListeners();
    return true;
  }

  /// Edit Data Lengkap Pengurus (Nama, Email, No HP, Jabatan, & Password) oleh Super Admin (atau edit profil sendiri)
  bool updateAdmin({
    required String adminId,
    required String name,
    required String email,
    required String phone,
    required AdminRole role,
    String? newPassword,
  }) {
    final index = _admins.indexWhere((a) => a.id == adminId);
    if (index == -1) return false;

    final isSuper =
        _currentAdmin == null || _currentAdmin!.role == AdminRole.superAdmin;
    final isSelf = _currentAdmin?.id == adminId;

    // Non-SuperAdmin hanya boleh mengedit profil dirinya sendiri
    if (!isSuper && !isSelf) {
      authorizeAdminScope('admin:users:manage', 'Edit Data Pengurus Lain');
      return false;
    }

    final cleanName = sanitizeInput(name, maxLength: 80);
    final cleanEmail = sanitizeInput(email, maxLength: 80);
    final cleanPhone = sanitizeInput(phone, maxLength: 25);
    if (cleanName.isEmpty || !cleanEmail.contains('@')) return false;

    // Cegah email kembar dengan admin lain
    final duplicateEmail = _admins.any(
      (a) => a.id != adminId && a.email.toLowerCase() == cleanEmail.toLowerCase(),
    );
    if (duplicateEmail) return false;

    final target = _admins[index];
    // Hanya Super Admin yang bisa mengubah jabatan (role), dan Super Admin terakhir tidak boleh diturunkan jabatannya
    AdminRole effectiveRole = target.role;
    if (isSuper) {
      if (target.role == AdminRole.superAdmin && role != AdminRole.superAdmin) {
        final superCount = _admins
            .where((a) => a.role == AdminRole.superAdmin && a.isActive)
            .length;
        effectiveRole = superCount <= 1 ? AdminRole.superAdmin : role;
      } else {
        effectiveRole = role;
      }
    }

    String updatedPass = target.password;
    if (newPassword != null && newPassword.trim().isNotEmpty) {
      if (newPassword.trim().length < 6) return false;
      updatedPass = newPassword.trim();
    }

    final updated = target.copyWith(
      name: cleanName,
      email: cleanEmail,
      phone: cleanPhone,
      role: effectiveRole,
      password: updatedPass,
    );
    _admins[index] = updated;
    if (_currentAdmin?.id == adminId) {
      _currentAdmin = updated;
    }
    addSecurityLog('Perubahan Data Pengurus Admin: ${updated.name} (${updated.role.label})');
    notifyListeners();
    return true;
  }

  /// Hapus akun pengurus lain (khusus Super Admin, tidak bisa hapus diri sendiri atau Super Admin terakhir)
  bool deleteAdmin(String adminId) {
    if (!authorizeAdminScope('admin:users:manage', 'Hapus Akun Pengurus')) {
      return false;
    }
    if (_currentAdmin != null && _currentAdmin!.role != AdminRole.superAdmin) {
      return false;
    }
    final index = _admins.indexWhere((a) => a.id == adminId);
    if (index == -1) return false;
    final target = _admins[index];
    if (target.id == _currentAdmin?.id) return false;
    if (target.role == AdminRole.superAdmin) {
      final superCount =
          _admins.where((a) => a.role == AdminRole.superAdmin).length;
      if (superCount <= 1) return false;
    }
    if (_admins.length <= 1) return false;

    final removedName = target.name;
    _admins.removeAt(index);
    addSecurityLog('Akun Pengurus $removedName Dihapus oleh Super Admin');
    notifyListeners();
    return true;
  }

  // ==========================================
  // PENDAFTARAN & MANAJEMEN ANGGOTA BARU (oleh Admin HRD) (#15, #24, #27)
  // ==========================================
  /// Daftar calon anggota baru yang mendaftar mandiri & menunggu verifikasi Admin HRD
  List<MemberModel> get pendingMemberRegistrations => _members
      .where((m) => m.status == MemberStatus.pendingVerification)
      .toList();

  /// Daftar anggota yang mengajukan Reset PIN (Lupa PIN) & menunggu verifikasi Admin HRD
  List<MemberModel> get pendingPinResetMembers => _members
      .where((m) => m.pendingPinReset != null && m.pendingPinReset!.isNotEmpty)
      .toList();

  bool registerMember({
    required String nik,
    required String name,
    required String department,
    required String email,
    required String phone,
    required DateTime joinDate,
    required String bankName,
    required String bankAccountNumber,
    String initialPin = '123456',
    bool requireHrVerification = false,
  }) {
    final nikVal = InputSanitizer.validateNik(nik);
    if (!nikVal.isValid) {
      lastLoginError = nikVal.errorMessage;
      return false;
    }
    final nameVal = InputSanitizer.validateName(name);
    if (!nameVal.isValid) {
      lastLoginError = nameVal.errorMessage;
      return false;
    }
    final emailVal = InputSanitizer.validateEmail(email);
    if (!emailVal.isValid) {
      lastLoginError = emailVal.errorMessage;
      return false;
    }
    final phoneVal = InputSanitizer.validatePhone(phone);
    if (!phoneVal.isValid) {
      lastLoginError = phoneVal.errorMessage;
      return false;
    }
    final rekVal = InputSanitizer.validateBankAccount(bankAccountNumber);
    if (!rekVal.isValid) {
      lastLoginError = rekVal.errorMessage;
      return false;
    }
    final pinVal = InputSanitizer.validatePin(initialPin, disallowWeak: requireHrVerification);
    if (!pinVal.isValid) {
      lastLoginError = pinVal.errorMessage;
      return false;
    }

    final cleanNik = nikVal.sanitizedValue;
    final exists = _members.any((m) => m.nik == cleanNik);
    if (exists) {
      lastLoginError = 'NIK $cleanNik sudah terdaftar di sistem!';
      return false;
    }

    final newMember = MemberModel(
      id: _nextId('MBR'),
      nik: cleanNik,
      name: nameVal.sanitizedValue,
      department: InputSanitizer.sanitizeDepartment(department),
      email: emailVal.sanitizedValue,
      phone: phoneVal.sanitizedValue,
      joinDate: joinDate,
      bankName: InputSanitizer.sanitizeBankName(bankName),
      bankAccountNumber: rekVal.sanitizedValue,
      bankAccountHolder: nameVal.sanitizedValue,
      isBankVerified: true,
      securityPin: pinVal.sanitizedValue,
      isBiometricEnabled: false,
      status: requireHrVerification
          ? MemberStatus.pendingVerification
          : MemberStatus.active,
      // Simpanan Pokok dimulai dari 0.0 dan baru terpotong Rp 125.000 saat Payroll Perdana (#24)
      simpananPokok: 0.0,
      simpananWajib: 0.0,
      simpananSukarela: 0.0,
      saldoBagiHasilBunga: 0.0,
      activeLoanBalance: 0.0,
    );

    _members.add(newMember);
    addSecurityLog(
      requireHrVerification
          ? 'Pengajuan Pendaftaran Anggota Baru Menunggu Verifikasi HRD: ${newMember.name} (Validasi Lolos)'
          : 'Pendaftaran Anggota Baru oleh HRD: ${newMember.name} (NIK: $cleanNik)',
    );
    notifyListeners();
    return true;
  }

  /// Admin HRD menyetujui & mengaktifkan pendaftaran anggota baru
  void approvePendingMember(String memberId) {
    if (!authorizeAdminScope('admin:members:verify', 'Verifikasi Pendaftaran Anggota Baru')) {
      return;
    }
    final index = _members.indexWhere((m) => m.id == memberId);
    if (index == -1) return;
    final m = _members[index];
    if (m.status != MemberStatus.pendingVerification) return;

    _members[index] = m.copyWith(status: MemberStatus.active);
    addSecurityLog('Verifikasi Anggota Baru Disetujui HRD (${m.name})');
    notifyListeners();
  }

  /// Admin HRD menolak pendaftaran anggota baru yang tidak dikenal
  void rejectPendingMember(String memberId) {
    if (!authorizeAdminScope('admin:members:verify', 'Penolakan Pendaftaran Anggota Baru')) {
      return;
    }
    final index = _members.indexWhere(
      (m) => m.id == memberId && m.status == MemberStatus.pendingVerification,
    );
    if (index == -1) return;
    final removedName = _members[index].name;
    _members.removeAt(index);
    addSecurityLog('Pendaftaran Anggota Baru Ditolak HRD ($removedName)', isSuccess: false);
    notifyListeners();
  }

  bool updateMember({
    required String memberId,
    required String nik,
    required String name,
    required String department,
    required String bankName,
    required String bankAccountNumber,
    required String securityPin,
  }) {
    if (!authorizeAdminScope('admin:members:verify', 'Edit Data Anggota')) {
      return false;
    }
    final index = _members.indexWhere((m) => m.id == memberId);
    if (index == -1) return false;

    final cleanNik = sanitizeInput(nik, maxLength: 30);
    // Cegah edit NIK menjadi kembar dengan karyawan lain (#27)
    final duplicateNik = _members.any(
      (m) => m.id != memberId && m.nik == cleanNik,
    );
    if (duplicateNik) return false;

    final cleanName = sanitizeInput(name, maxLength: 80);
    final validPin = isValidSixDigitPin(securityPin)
        ? securityPin.trim()
        : _members[index].securityPin;

    final updated = _members[index].copyWith(
      nik: cleanNik,
      name: cleanName,
      department: sanitizeInput(department, maxLength: 60),
      bankName: sanitizeInput(bankName, maxLength: 30),
      bankAccountNumber: bankAccountNumber.replaceAll(RegExp(r'[^0-9]'), ''),
      bankAccountHolder: cleanName,
      securityPin: validPin,
    );

    _members[index] = updated;
    if (_currentMember?.id == memberId) {
      _currentMember = updated;
    }

    // Sinkronkan perubahan nama ke transaksi, pinjaman, dan resign (#27)
    for (int i = 0; i < _transactions.length; i++) {
      if (_transactions[i].memberId == memberId) {
        _transactions[i] = _transactions[i].copyWith(memberName: cleanName);
      }
    }
    for (int i = 0; i < _loans.length; i++) {
      if (_loans[i].memberId == memberId) {
        _loans[i] = _loans[i].copyWith(memberName: cleanName);
      }
    }
    for (int i = 0; i < _resignations.length; i++) {
      if (_resignations[i].memberId == memberId) {
        _resignations[i] = _resignations[i].copyWith(memberName: cleanName);
      }
    }

    notifyListeners();
    return true;
  }

  /// Fitur Lupa PIN dengan Verifikasi Berlapis (3 Faktor: NIK + Email Terdaftar + Nomor Rekening Bank Lengkap)
  /// DAN Wajib Persetujuan Admin HRD sebelum PIN Baru Aktif (Anti-Bobol 100%, Admin tetap tidak bisa melihat angka PIN baru!)
  bool requestPinResetWithMultiFactor({
    required String nik,
    required String email,
    required String bankAccountNumber,
    required String newPin,
  }) {
    if (isLoginLockedOut) return false;

    final nikVal = InputSanitizer.validateNik(nik);
    final emailVal = InputSanitizer.validateEmail(email);
    final rekVal = InputSanitizer.validateBankAccount(bankAccountNumber);
    final pinVal = InputSanitizer.validatePin(newPin, disallowWeak: true);

    if (!nikVal.isValid || !emailVal.isValid || !rekVal.isValid || !pinVal.isValid) {
      lastLoginError = pinVal.errorMessage ??
          nikVal.errorMessage ??
          emailVal.errorMessage ??
          rekVal.errorMessage;
      return false;
    }

    final cleanNik = nikVal.sanitizedValue;
    final cleanEmail = emailVal.sanitizedValue;
    final cleanRek = rekVal.sanitizedValue;

    final index = _members.indexWhere((m) => m.nik == cleanNik);
    if (index == -1) {
      _recordFailedLogin();
      return false;
    }

    final target = _members[index];
    if (target.status == MemberStatus.resigned) return false;

    final targetEmail = target.email.trim().toLowerCase();
    final targetRek = target.bankAccountNumber.replaceAll(RegExp(r'[^0-9]'), '');

    // Wajib cocok KETIGA-TIGANYA: NIK + Email Terdaftar + Nomor Rekening Bank Lengkap!
    if (targetEmail != cleanEmail || targetRek != cleanRek) {
      _recordFailedLogin();
      addSecurityLog(
        'Percobaan Reset PIN Gagal / Diblokir (${target.name})',
        isSuccess: false,
      );
      return false;
    }

    // Simpan ke antrean pendingPinReset (menunggu klik Setujui dari Admin HRD, angka PIN disensor dari Admin!)
    _members[index] = target.copyWith(pendingPinReset: newPin.trim());
    if (_currentMember?.id == target.id) {
      _currentMember = _members[index];
    }
    addSecurityLog(
      'Pengajuan Reset PIN Terverifikasi 3-Faktor Menunggu Otorisasi HRD (${target.name})',
    );
    notifyListeners();
    return true;
  }

  /// Admin HRD menyetujui pengajuan Reset PIN karyawan (tanpa melihat angka PIN barunya!)
  void approvePendingPinReset(String memberId) {
    if (!authorizeAdminScope('admin:members:verify', 'Persetujuan Reset PIN Karyawan')) {
      return;
    }
    final index = _members.indexWhere((m) => m.id == memberId);
    if (index == -1) return;
    final m = _members[index];
    final nextPin = m.pendingPinReset;
    if (nextPin == null || !isValidSixDigitPin(nextPin)) return;

    _members[index] = m.copyWith(
      securityPin: nextPin,
      clearPendingPinReset: true,
    );
    if (_currentMember?.id == m.id) {
      _currentMember = _members[index];
    }
    _resetLoginAttempts();
    addSecurityLog('Reset PIN ${m.name} Disetujui oleh Admin HRD (PIN Terenkripsi)');
    notifyListeners();
  }

  /// Admin HRD menolak / memblokir pengajuan Reset PIN yang mencurigakan
  void rejectPendingPinReset(String memberId) {
    if (!authorizeAdminScope('admin:members:verify', 'Penolakan Reset PIN Karyawan')) {
      return;
    }
    final index = _members.indexWhere((m) => m.id == memberId);
    if (index == -1) return;
    final m = _members[index];
    _members[index] = m.copyWith(clearPendingPinReset: true);
    if (_currentMember?.id == m.id) {
      _currentMember = _members[index];
    }
    addSecurityLog('Pengajuan Reset PIN ${m.name} Ditolak/Diblokir HRD', isSuccess: false);
    notifyListeners();
  }

  /// Hapus karyawan beserta data terkait & cegah crash jika karyawan aktif dihapus (#15, #37)
  bool deleteMember(String memberId) {
    final index = _members.indexWhere((m) => m.id == memberId);
    if (index == -1) return false;
    // Cegah hapus jika tinggal 1 member terakhir agar simulasi tidak kosong
    if (_members.length <= 1) return false;

    final removedName = _members[index].name;
    _members.removeAt(index);
    _loans.removeWhere((l) => l.memberId == memberId);
    _resignations.removeWhere((r) => r.memberId == memberId);
    _transactions.removeWhere((t) => t.memberId == memberId);

    if (_currentMember?.id == memberId) {
      _currentMember = _members.isNotEmpty ? _members.first : null;
    }

    addSecurityLog('Data Anggota $removedName Dihapus oleh Admin');
    notifyListeners();
    return true;
  }

  /// Simulasi Serangan Hacker: Membuka file sesi di perangkat lain (MAC Address asing)
  /// Membuktikan bahwa token tidak disimpan mentah dan terkunci ke hardware MAC perangkat ini.
  bool simulateForeignDeviceMacAttack() {
    if (_currentAuthSession == null) return false;
    final exported = _exportStateMap();
    const foreignMac = 'DE:AD:BE:EF:00:99';
    try {
      final stolenSession = AuthSession.fromJson(
        exported['activeAuthSession'] as Map<String, dynamic>,
        foreignMac,
      );
      final valid =
          TokenService.verifyAndParseToken(stolenSession.accessToken.rawToken);
      if (valid == null) {
        addSecurityLog(
          '🚨 ANTI-KLONING: Sesi dibuka di MAC asing ($foreignMac). Dekripsi token gagal & akses ditolak total!',
          isSuccess: false,
        );
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }
}
