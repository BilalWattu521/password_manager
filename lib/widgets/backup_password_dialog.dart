import 'package:flutter/material.dart';

enum _DialogMode { exportNew, importExisting }

/// A reusable modal dialog that collects a backup password from the user.
///
/// For export it shows two fields (password + confirm), for import only one.
/// Returns the entered password string, or `null` if the user cancels.
class BackupPasswordDialog extends StatefulWidget {
  /// Whether this dialog is for creating a new backup (export) or
  /// entering an existing backup password (import).
  final bool isExport;

  const BackupPasswordDialog({super.key, required this.isExport});

  /// Convenience helper to show the dialog and await the result.
  static Future<String?> show(
    BuildContext context, {
    required bool isExport,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BackupPasswordDialog(isExport: isExport),
    );
  }

  @override
  State<BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<BackupPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pwController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePw = true;
  bool _obscureConfirm = true;

  _DialogMode get _mode =>
      widget.isExport ? _DialogMode.exportNew : _DialogMode.importExisting;

  @override
  void dispose() {
    _pwController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_pwController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExport = _mode == _DialogMode.exportNew;

    return AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            isExport ? Icons.lock_outline : Icons.lock_open_outlined,
            color: Colors.teal,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            isExport ? 'Create Backup Password' : 'Enter Backup Password',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isExport
                  ? 'Set a password to protect your backup.\n'
                    'You will need it to restore on a new device.'
                  : 'Enter the password you used when the backup was created.',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(height: 20),
            _PasswordField(
              controller: _pwController,
              label: 'Backup Password',
              obscure: _obscurePw,
              onToggle: () => setState(() => _obscurePw = !_obscurePw),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password cannot be empty';
                if (isExport && v.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
              onSubmitted: isExport ? null : (_) => _submit(),
            ),
            if (isExport) ...[
              const SizedBox(height: 14),
              _PasswordField(
                controller: _confirmController,
                label: 'Confirm Password',
                obscure: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                validator: (v) {
                  if (v != _pwController.text) return 'Passwords do not match';
                  return null;
                },
                onSubmitted: (_) => _submit(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _submit,
          child: Text(isExport ? 'Export' : 'Import'),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    this.validator,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF2C2C2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.teal, width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
            size: 20,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }
}
