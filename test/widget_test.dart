import 'package:flutter_test/flutter_test.dart';
import 'package:kopkar_app/main.dart';
import 'package:kopkar_app/models/member_model.dart';
import 'package:kopkar_app/services/coop_service.dart';
import 'package:kopkar_app/services/token_service.dart';
import 'package:kopkar_app/services/input_sanitizer.dart';
import 'package:kopkar_app/services/csrf_service.dart';

void main() {
  testWidgets('KopkarApp smoke test renders OnboardingScreen', (WidgetTester tester) async {
    final coop = CoopService();
    await tester.pumpWidget(KopkarApp(coopService: coop));
    expect(find.text('Mulai Sekarang'), findsOneWidget);
  });

  group('CoopService Core Accounting & Security Tests', () {
    final coop = CoopService();

    setUp(() {
      coop.resetToDefaultDemoData();
      coop.seedDemoMembersForTesting();
    });

    test('Active member count only includes MemberStatus.active', () {
      // Seed data has Agus (active) and Sarah (pendingResign); Dimas (and his loan) was removed
      expect(coop.activeMemberCount, 1);
      expect(coop.totalMonthlyLoanInterestPool, 0.0);
      expect(coop.monthlyInterestSharePerMember, 0.0);
    });

    test('Active member count is 0 when all members are cleared', () {
      coop.resetToDefaultDemoData();
      expect(coop.activeMemberCount, 0);
      expect(coop.monthlyInterestSharePerMember, 0.0);
    });

    test('Dual-Token AuthSession (Access 15m + Refresh 30d) is issued and validated', () {
      final session = coop.currentAuthSession;
      expect(session, isNotNull);
      expect(session!.accessToken.tokenType, 'access');
      expect(session.refreshToken.tokenType, 'refresh');
      expect(session.rotationCount, 0);
      expect(coop.isSessionTokenValid, true);

      // Verify token tampering protection
      final tampered = '${session.accessToken.rawToken}tampered';
      final verified = TokenService.verifyAndParseToken(tampered);
      expect(verified, isNull); // Must reject tampered token!
    });

    test('Refresh Token Rotation safely rotates tokens and invalidates the previous refresh token', () {
      final oldRefreshId = coop.currentRefreshToken!.tokenId;
      final oldAccessId = coop.currentAuthToken!.tokenId;

      final rotated = coop.rotateTokenSession();
      expect(rotated, true);
      expect(coop.currentAuthSession!.rotationCount, 1);
      expect(coop.currentRefreshToken!.tokenId, isNot(oldRefreshId));
      expect(coop.currentAuthToken!.tokenId, isNot(oldAccessId));
      expect(coop.usedRefreshTokenIds.contains(oldRefreshId), true);
    });

    test('Anti-Theft Replay Detection locks out stolen token replay attack', () {
      // Simulate hacker trying to replay the old token
      final theftTriggered = coop.simulateTokenTheftAttack();
      expect(theftTriggered, false);
      expect(coop.isLoggedIn, false); // Auto kicked out!
      expect(coop.currentAuthSession, isNull);
    });

    test('New member registration starts with Rp 0 Pokok and gets Rp 125.000 deducted on first payroll', () {
      final registered = coop.registerMember(
        nik: '2026999888',
        name: 'Bambang Pamungkas',
        department: 'Operasional',
        email: 'bambang@perusahaan.com',
        phone: '081200001111',
        joinDate: DateTime(2026, 10, 1),
        bankName: 'BCA',
        bankAccountNumber: '1234567890',
      );
      expect(registered, true);

      final bambangBefore = coop.members.firstWhere((m) => m.nik == '2026999888');
      expect(bambangBefore.simpananPokok, 0.0);
      expect(bambangBefore.simpananWajib, 0.0);

      // Execute payroll for October 2026
      final result = coop.executeMonthlyPayrollBatch(month: 10, year: 2026);
      expect(result['alreadyExecuted'], false);
      expect(result['month1Count'], 1); // Bambang is month-1

      final bambangAfter = coop.members.firstWhere((m) => m.nik == '2026999888');
      expect(bambangAfter.simpananPokok, 100000.0);
      expect(bambangAfter.simpananWajib, 25000.0);

      // Anti-double payroll guard prevents running October 2026 twice
      final duplicateRun = coop.executeMonthlyPayrollBatch(month: 10, year: 2026);
      expect(duplicateRun['alreadyExecuted'], true);
    });

    test('Resignation refund includes Simpanan Pokok + Wajib + Sukarela + Bagi Hasil Bunga 1%', () {
      final sarahResign = coop.resignations.first;
      expect(sarahResign.grossRefund, 2100000.0);
      expect(sarahResign.netRefund, 2100000.0);

      coop.approveAndDisburseResignation(sarahResign.id);
      final sarahAfter = coop.members.firstWhere((m) => m.id == sarahResign.memberId);
      expect(sarahAfter.status, MemberStatus.resigned);
      expect(sarahAfter.totalSavings, 0.0);
    });

    test('Ketua Koperasi cannot change Super Admin password or deactivate Super Admin', () {
      // Login as Ketua Koperasi (Siti Rahayu - ADM-002)
      final loggedIn = coop.loginAsAdmin('ketua@kopkar.com', 'ketua456');
      expect(loggedIn, true);
      expect(coop.currentAdmin?.canManageAdmins, false);

      // Attempt to change Super Admin (ADM-001) password -> must fail
      final hackAttempt = coop.changeAdminPassword(
        adminId: 'ADM-001',
        newPassword: 'hackedpassword',
      );
      expect(hackAttempt, false);

      // Attempt to deactivate Super Admin (ADM-001) -> must fail
      final deactivateAttempt = coop.toggleAdminActive('ADM-001');
      expect(deactivateAttempt, false);

      // Ketua Koperasi CAN change her own password (ADM-002)
      final ownChange = coop.changeAdminPassword(
        adminId: 'ADM-002',
        newPassword: 'ketuabaru123',
      );
      expect(ownChange, true);
    });

    test('Token and Refresh Token are encrypted with Device MAC Address and fail on foreign MAC', () {
      final member = coop.members.first;
      final session = TokenService.createMemberSession(member);

      const deviceMacA = '36:D5:18:A7:81:7F';
      const foreignMacB = 'AA:BB:CC:DD:EE:FF';

      // 1. Serialisasi ke JSON: Token TIDAK disimpan mentah, melainkan terenkripsi ENC:MAC256:...
      final exportedJson = session.toJson(deviceMacA);
      final rawAccessStored = exportedJson['accessToken']['rawToken'] as String;
      final rawRefreshStored = exportedJson['refreshToken']['rawToken'] as String;

      expect(rawAccessStored.startsWith('ENC:MAC256:'), true);
      expect(rawRefreshStored.startsWith('ENC:MAC256:'), true);
      expect(rawAccessStored.contains('eyJhbGciOi'), false); // Tidak ada string JWT mentah!

      // 2. Dekripsi di Perangkat Asli (MAC A) -> Berhasil dipulihkan
      final restoredSession = AuthSession.fromJson(exportedJson, deviceMacA);
      expect(restoredSession.accessToken.rawToken, session.accessToken.rawToken);
      expect(restoredSession.refreshToken.rawToken, session.refreshToken.rawToken);
      expect(restoredSession.isSessionAlive, true);

      // 3. Dekripsi di Perangkat Asing (MAC B) -> Gagal didekripsi (Anti-Kloning)
      final foreignSession = AuthSession.fromJson(exportedJson, foreignMacB);
      expect(foreignSession.accessToken.rawToken, ''); // Gagal didekripsi!
      expect(foreignSession.refreshToken.rawToken, '');
      expect(foreignSession.isSessionAlive, false); // Sesi otomatis mati total!
    });

    test('FLAG_SECURE and Inactivity Auto-Lock mechanisms work seamlessly', () async {
      // 1. FLAG_SECURE toggle
      expect(coop.isFlagSecureEnabled, true);
      await coop.toggleFlagSecure(false);
      expect(coop.isFlagSecureEnabled, false);
      await coop.toggleFlagSecure(true);
      expect(coop.isFlagSecureEnabled, true);

      // 2. Auto-Lock toggle and locking
      expect(coop.isAutoLockEnabled, true);
      expect(coop.isAppLocked, false);

      coop.lockAppNow();
      expect(coop.isAppLocked, true);

      // Attempt unlock with wrong PIN -> fails
      final wrongUnlock = coop.unlockAppWithPin('999999');
      expect(wrongUnlock, false);
      expect(coop.isAppLocked, true);

      // Unlock with correct PIN ('123456') -> succeeds
      final correctUnlock = coop.unlockAppWithPin('123456');
      expect(correctUnlock, true);
      expect(coop.isAppLocked, false);

      // Lock again and unlock with biometric
      coop.lockAppNow();
      expect(coop.isAppLocked, true);
      coop.unlockWithBiometric();
      expect(coop.isAppLocked, false);
    });

    test('RBAC OAuth2 JWT Scopes, Anti-IDOR Guard, and Salted SHA-256 Credential Hashing work strictly', () {
      // 1. Salted SHA-256 Credential Hashing & Verification
      final hashedPin = TokenService.hashCredential('123456');
      expect(hashedPin.startsWith('SHA256:'), true);
      expect(TokenService.verifyCredential('123456', hashedPin), true);
      expect(TokenService.verifyCredential('654321', hashedPin), false);

      // 2. Member Session has OAuth2 Scopes & Anti-IDOR Guard blocks cross-account access
      expect(coop.activeSessionScopes.contains('member:savings:deposit'), true);
      expect(
        coop.authorizeMemberScope(
          'member:savings:deposit',
          targetMemberId: coop.currentMember?.id,
        ),
        true,
      );
      expect(
        coop.authorizeMemberScope(
          'member:savings:deposit',
          targetMemberId: 'MBR-HACKER-999',
        ),
        false, // Anti-IDOR blocks access to another member's ID!
      );

      // 3. Sekretaris Role (ADM-004): Has admin:members:verify, blocked from Payroll & Bank Mutation
      final secLogin = coop.loginAsAdmin('sekretaris@kopkar.com', 'sekretaris123');
      expect(secLogin, true);
      expect(coop.currentAdmin?.canVerifyMembers, true);
      expect(coop.currentAdmin?.canVerifyBankMutation, false);
      expect(coop.currentAdmin?.canExecutePayroll, false);

      final secPayrollAttempt = coop.executeMonthlyPayrollBatch(month: 11, year: 2026);
      expect(secPayrollAttempt['unauthorized'], true);

      // 4. Bendahara Role (ADM-003): Has Bank & Finance & Payroll, blocked from HRD Member Verification
      final benLogin = coop.loginAsAdmin('bendahara@kopkar.com', 'bendahara789');
      expect(benLogin, true);
      expect(coop.currentAdmin?.canVerifyBankMutation, true);
      expect(coop.currentAdmin?.canApproveFinance, true);
      expect(coop.currentAdmin?.canVerifyMembers, false);
      expect(
        coop.authorizeAdminScope('admin:members:verify', 'Verifikasi Anggota Baru'),
        false,
      );
      expect(
        coop.authorizeAdminScope('admin:bank:verify', 'Verifikasi Mutasi Bank'),
        true,
      );
    });

    test('Input Validation & Sanitization Engine neutralizes XSS, SQLi, weak PINs, and invalid formats strictly', () {
      // 1. Anti-XSS and HTML Tag Stripping
      const rawXss = "<script>alert('pwned')</script><iframe src='evil.com'></iframe>Halo Koperasi";
      final cleanText = InputSanitizer.sanitizeText(rawXss);
      expect(cleanText, 'Halo Koperasi');
      expect(cleanText.contains('<script>'), false);
      expect(cleanText.contains('<iframe'), false);

      // 2. Anti-SQL Injection pattern neutralization
      const rawSqli = "Budi Santoso' OR 1=1; DROP TABLE members; --";
      final cleanSqli = InputSanitizer.sanitizeText(rawSqli);
      expect(cleanSqli.contains('--'), false);
      expect(cleanSqli.contains('DROP TABLE'), false);

      // 3. Weak PIN Detection (Sequential, Repeated, or Short)
      expect(InputSanitizer.isWeakPin('123456'), true);
      expect(InputSanitizer.isWeakPin('654321'), true);
      expect(InputSanitizer.isWeakPin('000000'), true);
      expect(InputSanitizer.isWeakPin('111111'), true);
      expect(InputSanitizer.isWeakPin('121212'), true);
      expect(InputSanitizer.isWeakPin('849201'), false); // Strong random PIN

      final weakVal = InputSanitizer.validatePin('123456', disallowWeak: true);
      expect(weakVal.isValid, false);
      expect(weakVal.errorMessage?.contains('terlalu mudah'), true);

      final strongVal = InputSanitizer.validatePin('849201', disallowWeak: true);
      expect(strongVal.isValid, true);
      expect(strongVal.sanitizedValue, '849201');

      // 4. Phone Number Normalization
      expect(InputSanitizer.sanitizePhone('+6281234567890'), '081234567890');
      expect(InputSanitizer.sanitizePhone('0812-3456-7890'), '081234567890');
      final phoneVal = InputSanitizer.validatePhone('+6281234567890');
      expect(phoneVal.isValid, true);
      expect(phoneVal.sanitizedValue, '081234567890');

      // 5. Email RFC Validation
      expect(InputSanitizer.validateEmail('budi.santoso@budiberlian.co.id').isValid, true);
      expect(InputSanitizer.validateEmail('invalid-email-no-at.com').isValid, false);

      // 6. Bank Account Validation
      expect(InputSanitizer.validateBankAccount('1234-5678-90').isValid, true);
      expect(InputSanitizer.validateBankAccount('1234-5678-90').sanitizedValue, '1234567890');
      expect(InputSanitizer.validateBankAccount('123').isValid, false); // Less than 8 digits

      // 7. Financial Amount Validation
      expect(InputSanitizer.validateRupiahAmount(50000.0).isValid, true);
      expect(InputSanitizer.validateRupiahAmount(-1000.0).isValid, false);
      expect(InputSanitizer.validateRupiahAmount(0.0).isValid, false);

      // 8. Member Registration rejects invalid NIK and invalid Email
      final badReg = coop.registerMember(
        nik: 'X', // Too short
        name: 'Hacker',
        department: 'Umum',
        email: 'bad-email',
        phone: '081234567890',
        joinDate: DateTime.now(),
        bankName: 'BCA',
        bankAccountNumber: '1234567890',
      );
      expect(badReg, false);
      expect(coop.lastLoginError?.contains('terlalu pendek'), true);

      // 9. Loan Application rejects exceeding maxLimit or negative amount
      final member = coop.members.first;
      final badLoan = coop.applyForLoan(
        member: member,
        amount: member.maxLoanLimit + 50000000,
        tenorMonths: 6,
        purpose: 'Melebihi Limit',
      );
      expect(badLoan, false);
    });

    test('Enterprise Anti-CSRF Protection & Cross-Origin Validation Suite (OWASP ASVS L3)', () {
      const sessionId = 'MBR-001-SESSION-ABC';

      // 1. Token Generation & Format
      final tokenObj = CsrfService.generateToken(sessionId: sessionId);
      expect(tokenObj.rawToken.startsWith('CSRF.'), true);
      expect(tokenObj.nonce.isNotEmpty, true);
      expect(tokenObj.signature.isNotEmpty, true);
      expect(tokenObj.sessionId, sessionId);
      expect(tokenObj.isExpired, false);
      expect(tokenObj.maskedToken.contains('••••••••'), true);

      // 2. Token Verification - Valid Token
      final isValid = CsrfService.verifyToken(tokenObj.rawToken, expectedSessionId: sessionId);
      expect(isValid, true);

      // 3. Token Verification - Tampered Nonce / Signature
      final tamperedSig = '${tokenObj.rawToken.substring(0, tokenObj.rawToken.length - 4)}XXXX';
      expect(CsrfService.verifyToken(tamperedSig, expectedSessionId: sessionId), false);

      // 4. Token Verification - Wrong Session ID (Session Binding Security)
      expect(CsrfService.verifyToken(tokenObj.rawToken, expectedSessionId: 'ATTACKER-SESSION-XYZ'), false);

      // 5. Token Verification - Expired Token
      final expiredToken = CsrfService.generateToken(sessionId: sessionId, duration: const Duration(seconds: -10));
      expect(expiredToken.isExpired, true);
      expect(CsrfService.verifyToken(expiredToken.rawToken, expectedSessionId: sessionId), false);

      // 6. Origin / Referer Whitelist Validation
      expect(CsrfService.isOriginAllowed('http://localhost:8080'), true);
      expect(CsrfService.isOriginAllowed('http://127.0.0.1:8089'), true);
      expect(CsrfService.isOriginAllowed('http://192.168.18.122:8088'), true);
      expect(CsrfService.isOriginAllowed('https://anqvtgusqrrcdnbgnxgf.supabase.co'), true);
      expect(CsrfService.isOriginAllowed(null), true); // Native mobile client
      expect(CsrfService.isOriginAllowed(''), true);
      expect(CsrfService.isOriginAllowed('https://evil-attacker-site.com'), false);
      expect(CsrfService.isOriginAllowed('http://phishing-kopkar.org'), false);

      // 7. Headers Generation
      final headers = CsrfService.getMutationHeaders(tokenObj);
      expect(headers[CsrfService.headerCsrfToken], tokenObj.rawToken);
      expect(headers[CsrfService.headerRequestedWith], CsrfService.headerRequestedWithValue);
      expect(headers['Sec-Fetch-Site'], 'same-origin');

      // 8. CoopService Active CSRF Token Auto-Issuance & Session Binding
      expect(coop.currentCsrfToken != null, true);
      final coopToken = coop.currentCsrfToken!;
      expect(coopToken.isExpired, false);

      // 9. CoopService authorizeCsrf succeeds for legitimate requests
      final authSuccess = coop.authorizeCsrf(
        incomingOrigin: 'http://localhost:8080',
        actionLabel: 'Pencairan Sukarela Valid',
      );
      expect(authSuccess, true);

      // 10. CoopService simulateCsrfAttack intercepts and blocks foreign forgery attempts
      final initialLogs = coop.securityLogs.length;
      final attackBlocked = coop.simulateCsrfAttack(
        attackOrigin: 'https://hacker-evil-domain.xyz',
        forgedToken: 'CSRF.fake_nonce.9999999999.invalid_signature',
      );
      expect(attackBlocked, true);
      expect(coop.securityLogs.length, greaterThan(initialLogs));
      expect(coop.securityLogs.first['title']?.contains('CSRF BLOCKED') ?? false, true);
    });
  });
}

