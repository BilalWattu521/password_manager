import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CredentialCard extends StatefulWidget {
  final int id;
  final String username;
  final String password;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CredentialCard({
    super.key,
    required this.id,
    required this.username,
    required this.password,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<CredentialCard> createState() => _CredentialCardState();
}

class _CredentialCardState extends State<CredentialCard> {
  bool _isPasswordVisible = false;
  final _localAuth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();
  bool _hasBiometric = false;
  String? _masterPin;

  @override
  void initState() {
    super.initState();
    _checkBiometricAndLoadPin();
  }

  Future<void> _checkBiometricAndLoadPin() async {
    final canCheckBio = await _localAuth.canCheckBiometrics;
    _masterPin = await _storage.read(key: 'user_pin');
    setState(() {
      _hasBiometric = canCheckBio;
    });
  }

  Future<bool> _authenticateWithBiometrics() async {
    try {
      final result = await _localAuth.authenticate(
        localizedReason: 'Authenticate to view password',
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Fingerprint Authentication',
            cancelButton: 'Cancel',
          ),
        ],
      );

      // If biometric fails or returns false, fallback to PIN on emulator
      if (!result && mounted) {
        debugPrint("Biometric auth failed, falling back to PIN");
        _showPinVerificationDialog();
      }
      return result;
    } catch (e) {
      debugPrint("Biometric error: $e, falling back to PIN");
      // On error, fallback to PIN verification
      if (mounted) {
        _showPinVerificationDialog();
      }
      return false;
    }
  }

  void _showPinVerificationDialog() {
    final pinController = TextEditingController();
    bool isPinVisible = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Verify PIN',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your master PIN to view password',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                obscureText: !isPinVisible,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter PIN',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  counterText: '',
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPinVisible ? Icons.visibility : Icons.visibility_off,
                      color: Colors.teal,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => isPinVisible = !isPinVisible),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                if (pinController.text == _masterPin) {
                  Navigator.pop(context);
                  setState(() => _isPasswordVisible = true);
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Invalid PIN')));
                }
              },
              child: const Text('Verify', style: TextStyle(color: Colors.teal)),
            ),
          ],
        ),
      ),
    );
  }

  void _togglePasswordVisibility() async {
    if (_isPasswordVisible) {
      // If already visible, just hide it
      setState(() => _isPasswordVisible = false);
      return;
    }

    // If trying to show password, authenticate
    if (_hasBiometric) {
      // Device has biometric - use biometric
      final authenticated = await _authenticateWithBiometrics();
      if (authenticated) {
        setState(() => _isPasswordVisible = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication failed')),
          );
        }
      }
    } else {
      // No biometric - fallback to PIN verification
      _showPinVerificationDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Username',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.teal, size: 20),
                    onPressed: widget.onEdit,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: widget.onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          Text(
            widget.username,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Password',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Tooltip(
                message: _hasBiometric
                    ? 'Use fingerprint'
                    : 'Enter PIN to view',
                child: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.teal,
                    size: 20,
                  ),
                  onPressed: _togglePasswordVisibility,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
          Text(
            _isPasswordVisible
                ? widget.password
                : '•' * (widget.password.length),
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
