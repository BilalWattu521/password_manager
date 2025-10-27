import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinKeypad extends StatelessWidget {
  final Function(String) onNumberPress;
  final VoidCallback onBackspace;
  final bool disabled; // 🔹 new parameter

  const PinKeypad({
    super.key,
    required this.onNumberPress,
    required this.onBackspace,
    this.disabled = false, // 🔹 default false
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        buildKeypadRow(["1", "2", "3"]),
        buildKeypadRow(["4", "5", "6"]),
        buildKeypadRow(["7", "8", "9"]),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 90), // empty slot
            keypadButton("0"),
            backspaceButton(),
          ],
        ),
      ],
    );
  }

  Widget buildKeypadRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: numbers.map((num) => keypadButton(num)).toList(),
    );
  }

  Widget keypadButton(String number) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: GestureDetector(
        onTap: disabled
            ? null // 🔹 ignore taps when disabled
            : () {
                HapticFeedback.lightImpact();
                onNumberPress(number);
              },
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: disabled
                ? Colors.white24
                : Colors.white10, // 🔹 visual feedback
            shape: BoxShape.circle,
            border: Border.all(
              color: disabled ? Colors.white38 : Colors.white24,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: TextStyle(
              color: disabled
                  ? Colors.white38
                  : Colors.white, // 🔹 visual feedback
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget backspaceButton() {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: GestureDetector(
        onTap: disabled
            ? null // 🔹 ignore taps when disabled
            : () {
                HapticFeedback.mediumImpact();
                onBackspace();
              },
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: disabled ? Colors.white24 : Colors.white10,
            shape: BoxShape.circle,
            border: Border.all(
              color: disabled ? Colors.white38 : Colors.white24,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.backspace_rounded,
            color: disabled ? Colors.white38 : Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
