import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'fingerprint_setup_screen.dart';
import 'lock_screen.dart';
import '../widgets/pin_keypad.dart';

class PinScreen extends StatefulWidget {
  final bool isFirstTime;
  const PinScreen({super.key, this.isFirstTime = false});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> with WidgetsBindingObserver {
  String enteredPin = "";
  final _storage = const FlutterSecureStorage();
  final LocalAuthentication _auth = LocalAuthentication();

  int attempts = 0;
  DateTime? lockoutUntil;
  Timer? _lockTimer;
  int remainingLockSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLockoutState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lockTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLockoutOrRedirect();
    }
  }

  Future<void> _loadLockoutState() async {
    String? attemptsStr = await _storage.read(key: 'pin_attempts');
    String? lockoutStr = await _storage.read(key: 'lockout_until');

    setState(() {
      attempts = int.tryParse(attemptsStr ?? '0') ?? 0;
      if (lockoutStr != null) lockoutUntil = DateTime.tryParse(lockoutStr);
      if (lockoutUntil != null) {
        final diff = lockoutUntil!.difference(DateTime.now()).inSeconds;
        if (diff > 0) _startLockTimer(diff);
      }
    });
  }

  void _startLockTimer(int seconds) {
    remainingLockSeconds = seconds;
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (remainingLockSeconds <= 0) {
          timer.cancel();
          lockoutUntil = null;
        } else {
          remainingLockSeconds--;
        }
      });
    });
  }

  void _checkLockoutOrRedirect() {
    if (lockoutUntil != null && DateTime.now().isBefore(lockoutUntil!)) {
      final remaining = lockoutUntil!.difference(DateTime.now()).inSeconds;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Too many attempts. Try again in $remaining seconds."),
        ),
      );
      _startLockTimer(remaining);
    }
  }

  bool get isLocked =>
      lockoutUntil != null && DateTime.now().isBefore(lockoutUntil!);

  void onNumberPress(String number) async {
    if (isLocked) return;

    if (enteredPin.length < 4) {
      setState(() => enteredPin += number);

      if (enteredPin.length == 4) {
        if (widget.isFirstTime) {
          await _storage.write(key: 'pin_code', value: enteredPin);
          await _storage.write(key: 'pin_set', value: 'true');
          _askFingerprintOption();
        } else {
          final storedPin = await _storage.read(key: 'pin_code');
          if (enteredPin == storedPin) {
            // correct
            await _storage.write(key: 'pin_attempts', value: '0');
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LockScreen()),
            );
          } else {
            // wrong PIN
            setState(() => enteredPin = "");
            attempts++;
            await _storage.write(
              key: 'pin_attempts',
              value: attempts.toString(),
            );

            if (attempts % 3 == 0) {
              final lockSeconds = attempts == 3 ? 30 : 60;
              lockoutUntil = DateTime.now().add(Duration(seconds: lockSeconds));
              await _storage.write(
                key: 'lockout_until',
                value: lockoutUntil!.toIso8601String(),
              );
              _startLockTimer(lockSeconds);
            }

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isLocked
                      ? "Too many wrong attempts. Try again in $remainingLockSeconds seconds."
                      : "Incorrect PIN. Try again.",
                ),
              ),
            );
          }
        }
      }
    }
  }

  void onBackspace() {
    if (isLocked || enteredPin.isEmpty) return;
    setState(() => enteredPin = enteredPin.substring(0, enteredPin.length - 1));
  }

  Future<void> _askFingerprintOption() async {
    if (!mounted) return;

    final useFingerprint = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Enable Fingerprint?"),
        content: const Text(
          "Would you like to enable fingerprint unlock for faster access?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No, Thanks"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes, Enable"),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (useFingerprint == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FingerprintSetupScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LockScreen()),
      );
    }
  }

  Future<void> _forgotPin() async {
    bool authenticated = false;
    try {
      authenticated = await _auth.authenticate(
        localizedReason: 'Authenticate to reset your PIN',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Authentication failed: $e")));
      return;
    }

    if (authenticated && mounted) {
      await _storage.delete(key: 'pin_code');
      await _storage.delete(key: 'pin_set');
      await _storage.delete(key: 'fingerprint_enabled');
      await _storage.delete(key: 'pin_attempts');
      await _storage.delete(key: 'lockout_until');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PinScreen(isFirstTime: true)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  const SizedBox(height: 30),
                  Text(
                    widget.isFirstTime
                        ? "Set Your PIN"
                        : isLocked
                        ? "Locked! Wait $remainingLockSeconds s"
                        : "Enter PIN",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      bool filled = index < enteredPin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? Colors.tealAccent : Colors.white24,
                        ),
                      );
                    }),
                  ),
                ],
              ),
              PinKeypad(
                onNumberPress: onNumberPress,
                onBackspace: onBackspace,
                disabled: isLocked, // pass lock state
              ),
              if (!widget.isFirstTime)
                TextButton(
                  onPressed: isLocked ? null : _forgotPin,
                  child: const Text(
                    "Forgot PIN?",
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
