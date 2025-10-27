import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'pin_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with WidgetsBindingObserver {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isBiometricAvailable = false;
  bool _fingerprintEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      _lockOnResume();
    }
  }

  Future<void> _lockOnResume() async {
    String? pinSet = await _secureStorage.read(key: 'pin_set');
    if (pinSet == 'true' && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PinScreen(isFirstTime: false)),
      );
    }
  }

  Future<void> _checkBiometricAvailability() async {
    bool canCheck = await _auth.canCheckBiometrics;
    bool isDeviceSupported = await _auth.isDeviceSupported();
    String? storedFingerprint = await _secureStorage.read(
      key: 'fingerprint_enabled',
    );

    if (!mounted) return;
    setState(() {
      _isBiometricAvailable = canCheck && isDeviceSupported;
      _fingerprintEnabled = storedFingerprint == 'true';
    });
  }

  Future<void> _authenticateFingerprint() async {
    try {
      bool authenticated = await _auth.authenticate(
        localizedReason: 'Scan your fingerprint to unlock',
        biometricOnly: true,
      );

      if (!mounted) return;

      if (authenticated) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const PinScreen(isFirstTime: false),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Fingerprint not recognized"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Fingerprint authentication failed: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.white70),
              const SizedBox(height: 20),
              const Text(
                'Password Vault',
                style: TextStyle(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 60),
              if (_isBiometricAvailable && _fingerprintEnabled)
                GestureDetector(
                  onTap: _authenticateFingerprint,
                  child: const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white10,
                    child: Icon(
                      Icons.fingerprint,
                      size: 60,
                      color: Colors.tealAccent,
                    ),
                  ),
                ),
              if (_isBiometricAvailable && _fingerprintEnabled)
                const SizedBox(height: 16),
              if (_isBiometricAvailable && _fingerprintEnabled)
                const Text(
                  'Touch to unlock',
                  style: TextStyle(color: Colors.white60, fontSize: 16),
                ),
              const SizedBox(height: 40),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PinScreen(isFirstTime: false),
                    ),
                  );
                },
                child: const Text(
                  'Use PIN instead',
                  style: TextStyle(color: Colors.tealAccent, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
