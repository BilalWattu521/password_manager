import 'package:flutter/material.dart';
import 'package:flutter_app_lock/flutter_app_lock.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_screen_lock/flutter_screen_lock.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();
  String? _savedPin;
  bool _fingerprintEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _savedPin = await _storage.read(key: 'user_pin');
    _fingerprintEnabled =
        (await _storage.read(key: 'use_fingerprint')) == 'true';
    setState(() {});
  }

  Future<bool> _authenticateWithBiometrics() async {
    try {
      final canAuthenticate = await _localAuth.canCheckBiometrics;
      if (!canAuthenticate) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock your app',
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Fingerprint Authentication',
            cancelButton: 'Cancel',
          ),
        ],
      );
    } catch (e) {
      debugPrint("Biometric error: $e");
      return false;
    }
  }

  void _onSuccessUnlock() {
    // Tell AppLock that the app has been unlocked
    AppLock.of(context)!.didUnlock();
  }

  void _showLockScreen(BuildContext context) {
    if (_savedPin == null) return;

    screenLock(
      context: context,
      correctString: _savedPin!,
      canCancel: false,
      title: const Text(
        'Enter your PIN',
        style: TextStyle(color: Colors.white, fontSize: 22),
      ),
      customizedButtonChild: Icon(
        Icons.fingerprint,
        size: 60,
        color: _fingerprintEnabled ? Colors.tealAccent : Colors.grey,
      ),
      customizedButtonTap: () async {
        final success = await _authenticateWithBiometrics();
        if (success && mounted) {
          _onSuccessUnlock();
        }
      },
      deleteButton: const Icon(Icons.backspace, size: 40, color: Colors.white),
      onUnlocked: () {
        _onSuccessUnlock();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_savedPin == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.tealAccent),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showLockScreen(context);
    });

    return const Scaffold(backgroundColor: Colors.black);
  }
}
