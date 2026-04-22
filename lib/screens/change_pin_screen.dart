import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_screen_lock/flutter_screen_lock.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  bool _biometricsAvailable = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isEnabled =
          (await _storage.read(key: 'use_fingerprint')) == 'true';
      if (mounted) {
        setState(() {
          _biometricsAvailable = canCheck && isEnabled;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Change PIN (requires old PIN) ──────────────────────────────────────

  void _startChangePinFlow() async {
    final currentPin = await _storage.read(key: 'user_pin');
    if (currentPin == null || !mounted) return;

    // Step 1: Verify the current PIN
    screenLock(
      context: context,
      correctString: currentPin,
      canCancel: true,
      title: const Text(
        'Enter Current PIN',
        style: TextStyle(color: Colors.white, fontSize: 22),
      ),
      deleteButton:
          const Icon(Icons.backspace, size: 40, color: Colors.white),
      onUnlocked: () {
        // Step 2: Navigator.pop closes the verification screen,
        // then we open the create flow
        Navigator.of(context).pop();
        Future.microtask(() => _openCreatePinFlow(isReset: false));
      },
    );
  }

  // ── Forgot PIN (biometrics only) ────────────────────────────────────────

  Future<void> _startForgotPinFlow() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verify your fingerprint to reset your PIN',
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Fingerprint Required',
            cancelButton: 'Cancel',
          ),
        ],
      );

      if (authenticated && mounted) {
        _openCreatePinFlow(isReset: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Fingerprint authentication failed. Try again.', isError: true);
      }
    }
  }

  // ── Shared: open screenLockCreate ───────────────────────────────────────

  void _openCreatePinFlow({required bool isReset}) {
    screenLockCreate(
      context: context,
      deleteButton:
          const Icon(Icons.backspace, size: 40, color: Colors.white),
      title: Text(
        isReset ? 'Set New PIN' : 'Set New PIN',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      confirmTitle: const Text(
        'Confirm New PIN',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      onConfirmed: (newPin) async {
        await _storage.write(key: 'user_pin', value: newPin);
        if (mounted) {
          Navigator.of(context).pop(); // close create screen
          _showSnack('PIN updated successfully!', isError: false);
        }
      },
    );
  }

  // ── Snackbar ────────────────────────────────────────────────────────────

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? Colors.red[700] : Colors.teal[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'PIN Settings',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon banner
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.teal.withAlpha(30),
                          border: Border.all(
                            color: Colors.teal.withAlpha(100),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          size: 44,
                          color: Colors.tealAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Manage Your PIN',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your PIN locks the app and protects all your credentials.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // ── Change PIN card ──────────────────────────────────
                    _OptionCard(
                      icon: Icons.lock_outline_rounded,
                      iconColor: Colors.tealAccent,
                      title: 'Change PIN',
                      subtitle: 'You\'ll need to enter your current PIN first.',
                      onTap: _startChangePinFlow,
                    ),

                    const SizedBox(height: 16),

                    // ── Forgot PIN card (biometrics only) ────────────────
                    if (_biometricsAvailable)
                      _OptionCard(
                        icon: Icons.fingerprint_rounded,
                        iconColor: Colors.purpleAccent,
                        title: 'Forgot PIN?',
                        subtitle:
                            'Reset your PIN using fingerprint authentication.',
                        onTap: _startForgotPinFlow,
                        accentColor: Colors.purple,
                      ),

                    if (!_biometricsAvailable)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey[800]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.grey[500], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Fingerprint reset is unavailable.\nEnable fingerprint in Settings → Security.',
                                style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Reusable option card ─────────────────────────────────────────────────────

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color accentColor;

  const _OptionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accentColor = Colors.teal,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[800]!),
          boxShadow: [
            BoxShadow(
              color: accentColor.withAlpha(20),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withAlpha(25),
                border: Border.all(color: accentColor.withAlpha(80), width: 1),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}
