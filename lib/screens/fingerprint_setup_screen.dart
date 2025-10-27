import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

class FingerprintSetupScreen extends StatefulWidget {
  const FingerprintSetupScreen({super.key});

  @override
  State<FingerprintSetupScreen> createState() => _FingerprintSetupScreenState();
}

class _FingerprintSetupScreenState extends State<FingerprintSetupScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isDeviceSupported = false;
  bool _canCheckBiometrics = false;
  String _message = "Press the button to set up fingerprint authentication.";

  @override
  void initState() {
    super.initState();
    _checkDeviceSupport();
  }

  Future<void> _checkDeviceSupport() async {
    try {
      final bool isSupported = await _auth.isDeviceSupported();
      final bool canCheck = await _auth.canCheckBiometrics;

      setState(() {
        _isDeviceSupported = isSupported;
        _canCheckBiometrics = canCheck;
      });
    } on PlatformException catch (e) {
      setState(() => _message = "Error checking biometrics: ${e.message}");
    }
  }

  Future<void> _authenticate() async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Scan your fingerprint to enable secure access',
        // 👇 options moved directly into authenticate() parameters
        biometricOnly: true,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Fingerprint Authentication',
            cancelButton: 'Cancel',
          ),
          IOSAuthMessages(cancelButton: 'Cancel'),
        ],
      );

      if (!mounted) return;

      setState(() {
        _message = didAuthenticate
            ? "Fingerprint setup successful!"
            : "Authentication failed. Try again.";
      });

      if (didAuthenticate) {
        await _secureStorage.write(key: 'fingerprint_enabled', value: 'true');

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Fingerprint successfully enabled!"),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } on PlatformException catch (e) {
      setState(() => _message = "Authentication error: ${e.message}");
    } on Exception catch (e) {
      setState(() => _message = "Unexpected error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool available = _isDeviceSupported && _canCheckBiometrics;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Fingerprint Setup"),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.fingerprint_rounded,
              size: 100,
              color: Colors.teal,
            ),
            const SizedBox(height: 30),
            Text(
              _message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: available ? _authenticate : null,
              icon: const Icon(Icons.lock_open),
              label: const Text("Enable Fingerprint Unlock"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!available) ...[
              const SizedBox(height: 16),
              const Text(
                "Your device doesn't support biometrics or it's not set up yet.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
