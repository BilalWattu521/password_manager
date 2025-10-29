import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_screen_lock/flutter_screen_lock.dart';

class SetPinScreen extends StatelessWidget {
  final VoidCallback onPinCreated;

  const SetPinScreen({super.key, required this.onPinCreated});

  @override
  Widget build(BuildContext context) {
    const storage = FlutterSecureStorage();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32),
              child: const Text(
                'Welcome to \nPassword Manager',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
              child: const Text(
                'Please set a 4-digit PIN to secure your data.',
                style: TextStyle(color: Colors.white70, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Create PIN",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              onPressed: () {
                screenLockCreate(
                  context: context,
                  deleteButton: const Icon(
                    Icons.backspace,
                    size: 40,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Create a 4-digit PIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  confirmTitle: const Text(
                    'Confirm your PIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onConfirmed: (pin) async {
                    // Save the PIN
                    await storage.write(key: 'user_pin', value: pin);

                    if (context.mounted) {
                      // Notify parent that PIN was created
                      onPinCreated();
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
