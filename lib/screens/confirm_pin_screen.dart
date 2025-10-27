import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'fingerprint_setup_screen.dart';
import 'lock_screen.dart';
import '../widgets/pin_keypad.dart';

class ConfirmPinScreen extends StatefulWidget {
  final String initialPin;
  const ConfirmPinScreen({super.key, required this.initialPin});

  @override
  State<ConfirmPinScreen> createState() => _ConfirmPinScreenState();
}

class _ConfirmPinScreenState extends State<ConfirmPinScreen> {
  String confirmPin = "";
  final _storage = const FlutterSecureStorage();

  void onNumberPress(String number) async {
    if (confirmPin.length < 4) {
      setState(() => confirmPin += number);

      if (confirmPin.length == 4) {
        if (confirmPin == widget.initialPin) {
          await _storage.write(key: 'pin_code', value: confirmPin);
          await _storage.write(key: 'pin_set', value: 'true');

          if (!mounted) return;

          // Ask for fingerprint setup
          _askFingerprintOption();
        } else {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("PINs do not match. Try again.")),
          );
          // Reset entry to allow re-entry
          setState(() => confirmPin = "");
        }
      }
    }
  }

  void _askFingerprintOption() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Enable Fingerprint?"),
        content: const Text(
          "Would you like to enable fingerprint unlock for faster access?",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Skip fingerprint → go to LockScreen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LockScreen()),
              );
            },
            child: const Text("No, Thanks"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Go to fingerprint setup
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const FingerprintSetupScreen(),
                ),
              );
            },
            child: const Text("Yes, Enable"),
          ),
        ],
      ),
    );
  }

  void onBackspace() {
    if (confirmPin.isNotEmpty) {
      setState(
        () => confirmPin = confirmPin.substring(0, confirmPin.length - 1),
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
                  const Text(
                    "Confirm PIN",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Re-enter your 4-digit PIN to confirm.",
                    style: TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      bool filled = index < confirmPin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
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
              PinKeypad(onNumberPress: onNumberPress, onBackspace: onBackspace),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
