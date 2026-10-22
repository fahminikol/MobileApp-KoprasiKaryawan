import 'dart:async';
import 'package:flutter/material.dart';
import '../services/coop_service.dart';
import '../theme/app_theme.dart';

/// ============================================================================
/// AUTO-LOCK WRAPPER: PROTEKSI INACTIVITY SESSION TIMEOUT (3-5 MENIT)
/// ============================================================================
/// Mendeteksi setiap sentuhan layar (pointer down/move/up). Jika tidak ada
/// interaksi selama periode timeout (default 3 menit), aplikasi otomatis
/// mengunci layar dengan overlay PIN / Biometrik demi menjaga kerahasiaan
/// saldo simpanan & pinjaman karyawan saat HP ditinggal.
class AutoLockWrapper extends StatefulWidget {
  final Widget child;
  final CoopService coopService;

  const AutoLockWrapper({
    super.key,
    required this.child,
    required this.coopService,
  });

  @override
  State<AutoLockWrapper> createState() => _AutoLockWrapperState();
}

class _AutoLockWrapperState extends State<AutoLockWrapper> {
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    widget.coopService.addListener(_onCoopChanged);
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    widget.coopService.removeListener(_onCoopChanged);
    super.dispose();
  }

  void _onCoopChanged() {
    if (mounted) setState(() {});
  }

  void _startTimer() {
    _inactivityTimer?.cancel();
    if (!widget.coopService.isAutoLockEnabled) return;
    if (widget.coopService.isAppLocked) return;

    final seconds = widget.coopService.autoLockTimeoutSeconds;
    _inactivityTimer = Timer(Duration(seconds: seconds), () {
      if (mounted && widget.coopService.isAutoLockEnabled) {
        widget.coopService.lockAppNow();
      }
    });
  }

  void _onUserInteraction() {
    if (!widget.coopService.isAppLocked) {
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onUserInteraction(),
      onPointerMove: (_) => _onUserInteraction(),
      onPointerUp: (_) => _onUserInteraction(),
      child: Stack(
        children: [
          widget.child,
          if (widget.coopService.isAppLocked)
            Positioned.fill(
              child: _AutoLockOverlay(
                coopService: widget.coopService,
                onUnlocked: () {
                  _startTimer();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _AutoLockOverlay extends StatefulWidget {
  final CoopService coopService;
  final VoidCallback onUnlocked;

  const _AutoLockOverlay({
    required this.coopService,
    required this.onUnlocked,
  });

  @override
  State<_AutoLockOverlay> createState() => _AutoLockOverlayState();
}

class _AutoLockOverlayState extends State<_AutoLockOverlay> {
  String _enteredPin = '';
  String? _errorMessage;

  void _onKeyPress(String val) {
    if (widget.coopService.isPinLockedOut) {
      setState(() {
        _enteredPin = '';
        _errorMessage =
            '🛡️ Terkunci! Tunggu ${widget.coopService.remainingPinLockoutSeconds} detik.';
      });
      return;
    }

    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += val;
        _errorMessage = null;
      });

      if (_enteredPin.length == 6) {
        _submitPin();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _submitPin() {
    final ok = widget.coopService.unlockAppWithPin(_enteredPin);
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() {
        _enteredPin = '';
        _errorMessage = widget.coopService.isPinLockedOut
            ? '🚨 Sesi dikunci 30 dtk (5x salah PIN)!'
            : 'PIN salah! Sisa percobaan: ${widget.coopService.remainingPinAttempts}x';
      });
    }
  }

  void _onBiometric() {
    widget.coopService.unlockWithBiometric();
    widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.coopService.currentMember;
    final isBiometricActive = member?.isBiometricEnabled ?? true;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0F172A).withValues(alpha: 0.98),
              const Color(0xFF1E293B).withValues(alpha: 0.98),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const Spacer(flex: 1),

                // Shield Lock Icon
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryBlueLight, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                const Text(
                  'KOPKAR PT BUDI BERLIAN MOTOR',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sesi Terkunci Otomatis',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Aplikasi dikunci setelah tidak ada aktivitas demi privasi data keuangan Anda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // 6 Dots PIN Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    final isFilled = index < _enteredPin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? AppTheme.primaryBlue : Colors.transparent,
                        border: Border.all(
                          color: isFilled ? AppTheme.primaryBlue : const Color(0xFF64748B),
                          width: 2,
                        ),
                        boxShadow: isFilled
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                )
                              ]
                            : null,
                      ),
                    );
                  }),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFFCA5A5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],

                const Spacer(flex: 2),

                // Keypad 1-9
                for (var r = 0; r < 3; r++) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var c = 1; c <= 3; c++) ...[
                        _buildKey('${r * 3 + c}'),
                        if (c < 3) const SizedBox(width: 24),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // Bottom row: Biometric / 0 / Backspace
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isBiometricActive)
                      _buildIconButton(
                        icon: Icons.fingerprint_rounded,
                        color: AppTheme.primaryBlueLight,
                        onTap: _onBiometric,
                      )
                    else
                      const SizedBox(width: 68, height: 68),
                    const SizedBox(width: 24),
                    _buildKey('0'),
                    const SizedBox(width: 24),
                    _buildIconButton(
                      icon: Icons.backspace_rounded,
                      color: const Color(0xFF94A3B8),
                      onTap: _onBackspace,
                    ),
                  ],
                ),

                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKey(String number) {
    return InkWell(
      onTap: () => _onKeyPress(number),
      borderRadius: BorderRadius.circular(34),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF334155).withValues(alpha: 0.5),
          border: Border.all(color: const Color(0xFF475569), width: 1.5),
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(34),
      child: SizedBox(
        width: 68,
        height: 68,
        child: Center(
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }
}
