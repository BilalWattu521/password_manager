import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'confirm_pin_screen.dart';
import '../widgets/pin_keypad.dart';

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  String enteredPin = "";
  final _storage = const FlutterSecureStorage();

  void onNumberPress(String number) {
    if (enteredPin.length < 4) {
      setState(() => enteredPin += number);

      if (enteredPin.length == 4) {
        Future.delayed(const Duration(milliseconds: 200), () async {
          await _storage.write(key: 'temp_pin', value: enteredPin);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ConfirmPinScreen(initialPin: enteredPin),
            ),
          );
        });
      }
    }
  }

  void onBackspace() {
    if (enteredPin.isNotEmpty) {
      setState(
        () => enteredPin = enteredPin.substring(0, enteredPin.length - 1),
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
                    "Set Your PIN",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Enter a 4-digit PIN to secure your app.",
                    style: TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 40),

                  // PIN circles
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      bool filled = index < enteredPin.length;
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

              // Reused keypad
              PinKeypad(onNumberPress: onNumberPress, onBackspace: onBackspace),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
