import 'package:flutter/material.dart';
import '../services/coop_service.dart';
import '../theme/app_theme.dart';

class SecurityPinDialog extends StatefulWidget {
  final CoopService coopService;
  final String title;
  final String amount;
  final String destination;
  final VoidCallback onVerified;

  const SecurityPinDialog({
    super.key,
    required this.coopService,
    required this.title,
    required this.amount,
    required this.destination,
    required this.onVerified,
  });

  static void show(
    BuildContext context, {
    required CoopService coopService,
    required String title,
    required String amount,
    required String destination,
    required VoidCallback onVerified,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SecurityPinDialog(
        coopService: coopService,
        title: title,
        amount: amount,
        destination: destination,
        onVerified: onVerified,
      ),
    );
  }

  @override
  State<SecurityPinDialog> createState() => _SecurityPinDialogState();
}

class _SecurityPinDialogState extends State<SecurityPinDialog> {
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
        _validatePin();
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

  void _validatePin() {
    if (widget.coopService.isPinLockedOut) {
      setState(() {
        _enteredPin = '';
        _errorMessage =
            '🛡️ Terlalu banyak salah PIN! Coba lagi dalam ${widget.coopService.remainingPinLockoutSeconds} detik.';
      });
      return;
    }

    final isValid = widget.coopService.verifySecurityPin(_enteredPin);
    if (isValid) {
      Navigator.pop(context);
      widget.onVerified();
    } else {
      setState(() {
        _enteredPin = '';
        _errorMessage = widget.coopService.isPinLockedOut
            ? '🛡️ PIN dikunci 30 detik karena 5x salah (Anti-Brute Force)!'
            : '❌ PIN Transaksi salah! Sisa percobaan: ${widget.coopService.remainingPinAttempts}x';
      });
    }
  }

  void _handleBiometric() {
    final member = widget.coopService.currentMember;
    if (member == null || !member.isBiometricEnabled) {
      setState(() {
        _errorMessage = 'Fitur Biometrik sedang dinonaktifkan di pengaturan akun Anda.';
      });
      return;
    }
    if (widget.coopService.isPinLockedOut) {
      setState(() {
        _errorMessage =
            '🛡️ PIN sedang terkunci! Biometrik ditangguhkan selama ${widget.coopService.remainingPinLockoutSeconds} detik.';
      });
      return;
    }

    widget.coopService.addSecurityLog('Otorisasi Biometrik Transaksi (${member.name})');
    Navigator.pop(context);
    widget.onVerified();
  }

  @override
  Widget build(BuildContext context) {
    final isBiometricAllowed =
        widget.coopService.currentMember?.isBiometricEnabled ?? false;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppTheme.primaryBlueLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.security_rounded, color: AppTheme.primaryBlue, size: 28),
          ),
          const SizedBox(height: 10),

          Text(
            widget.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark),
          ),
          const SizedBox(height: 4),
          Text(
            'Otorisasi: ${widget.amount} • ${widget.destination}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 18),

          // 6 PIN Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              final isFilled = index < _enteredPin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? AppTheme.primaryBlue : Colors.transparent,
                  border: Border.all(
                    color: isFilled ? AppTheme.primaryBlue : const Color(0xFFCBD5E1),
                    width: 2,
                  ),
                ),
              );
            }),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.dangerRed,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 20),

          _buildKeypad(isBiometricAllowed),
        ],
      ),
    );
  }

  Widget _buildKeypad(bool isBiometricAllowed) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['1', '2', '3'].map((k) => _buildKeyButton(k)).toList(),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['4', '5', '6'].map((k) => _buildKeyButton(k)).toList(),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['7', '8', '9'].map((k) => _buildKeyButton(k)).toList(),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (isBiometricAllowed)
              IconButton(
                tooltip: 'Otorisasi Biometrik',
                icon: const Icon(Icons.fingerprint_rounded, size: 28, color: AppTheme.primaryBlue),
                onPressed: _handleBiometric,
              )
            else
              const SizedBox(width: 48, height: 48),
            _buildKeyButton('0'),
            IconButton(
              icon: const Icon(Icons.backspace_outlined, size: 22, color: AppTheme.textDark),
              onPressed: _onBackspace,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyButton(String val) {
    return GestureDetector(
      onTap: () => _onKeyPress(val),
      child: Container(
        width: 65,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            val,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark),
          ),
        ),
      ),
    );
  }
}
