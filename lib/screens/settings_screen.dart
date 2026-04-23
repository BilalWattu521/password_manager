import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_screen_lock/flutter_screen_lock.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:share_plus/share_plus.dart';
import 'package:password_manager/services/backup_service.dart';
import 'package:password_manager/widgets/backup_password_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  bool _deviceHasBiometrics = false;
  bool _fingerprintEnabled = false;
  bool _loading = true;

  // Busy overlay state
  bool _isBusy = false;
  String _busyLabel = '';
  String _busySubtitle = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final available = await _localAuth.getAvailableBiometrics();
    final hasEnrolled = available.isNotEmpty;
    final isEnabled =
        (await _storage.read(key: 'use_fingerprint')) == 'true';
    if (mounted) {
      setState(() {
        _deviceHasBiometrics = hasEnrolled;
        _fingerprintEnabled = hasEnrolled && isEnabled;
        _loading = false;
      });
    }
  }

  // ── Fingerprint toggle ──────────────────────────────────────────────────

  Future<void> _toggleFingerprint(bool value) async {
    if (value) {
      try {
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Verify your fingerprint to enable this feature',
          authMessages: const [
            AndroidAuthMessages(
              signInTitle: 'Enable Fingerprint',
              cancelButton: 'Cancel',
            ),
          ],
        );
        if (!authenticated || !mounted) return;
      } catch (_) {
        if (mounted) _showSnack('Fingerprint verification failed.', isError: true);
        return;
      }
    }
    await _storage.write(
        key: 'use_fingerprint', value: value ? 'true' : 'false');
    if (mounted) {
      setState(() => _fingerprintEnabled = value);
      _showSnack(
        value ? 'Fingerprint enabled.' : 'Fingerprint disabled.',
        isError: false,
      );
    }
  }

  // ── Export ──────────────────────────────────────────────────────────────

  Future<void> _exportPasswords() async {
    final password = await BackupPasswordDialog.show(context, isExport: true);
    if (password == null || !mounted) return;

    setState(() {
      _isBusy = true;
      _busyLabel = 'Encrypting Backup';
      _busySubtitle = 'Securing your passwords\nwith AES-256 encryption';
    });

    late String filePath;
    try {
      filePath = await BackupService.prepareBackup(password);
    } on BackupException catch (e) {
      if (mounted) _showSnack(e.message, isError: true);
      return;
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }

    if (!mounted) return;
    try {
      final result = await BackupService.shareBackup(filePath);
      if (!mounted) return;
      switch (result.status) {
        case ShareResultStatus.success:
          _showSnack('Backup saved successfully!', isError: false);
        case ShareResultStatus.dismissed:
          _showSnack('Backup was not saved.', isError: true);
        case ShareResultStatus.unavailable:
          _showSnack('Sharing is not available on this device.', isError: true);
      }
    } catch (_) {
      if (mounted) _showSnack('Failed to share backup.', isError: true);
    }
  }

  // ── Import ──────────────────────────────────────────────────────────────

  Future<void> _importPasswords() async {
    late String fileContent;
    try {
      final content = await BackupService.pickBackupFile();
      if (content == null || !mounted) return;
      fileContent = content;
    } on BackupException catch (e) {
      if (mounted) _showSnack(e.message, isError: true);
      return;
    }

    if (!mounted) return;
    final password = await BackupPasswordDialog.show(context, isExport: false);
    if (password == null || !mounted) return;

    setState(() {
      _isBusy = true;
      _busyLabel = 'Decrypting Backup';
      _busySubtitle = 'Verifying password and\nrestoring your credentials';
    });
    try {
      final count =
          await BackupService.decryptAndImport(fileContent, password);
      if (mounted) {
        _showSnack(
          '$count ${count == 1 ? 'credential' : 'credentials'} imported!',
          isError: false,
        );
        // Signal home screen to reload
        Navigator.of(context).pop(true);
      }
    } on BackupException catch (e) {
      if (mounted) _showSnack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ── Change PIN ──────────────────────────────────────────────────────────

  void _startChangePinFlow() async {
    final currentPin = await _storage.read(key: 'user_pin');
    if (currentPin == null || !mounted) return;

    screenLock(
      context: context,
      correctString: currentPin,
      canCancel: true,
      title: const Text(
        'Enter Current PIN',
        style: TextStyle(color: Colors.white, fontSize: 22),
      ),
      deleteButton:
          const Icon(Icons.backspace, size: 40, color: Colors.white),
      onUnlocked: () {
        Navigator.of(context).pop();
        Future.microtask(() => _openCreatePinFlow());
      },
    );
  }

  // ── Forgot PIN (fingerprint only) ────────────────────────────────────────

  Future<void> _startForgotPinFlow() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verify your fingerprint to reset your PIN',
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Fingerprint Required',
            cancelButton: 'Cancel',
          ),
        ],
      );
      if (authenticated && mounted) _openCreatePinFlow();
    } catch (_) {
      if (mounted) {
        _showSnack('Fingerprint authentication failed. Try again.',
            isError: true);
      }
    }
  }

  void _openCreatePinFlow() {
    screenLockCreate(
      context: context,
      deleteButton:
          const Icon(Icons.backspace, size: 40, color: Colors.white),
      title: const Text(
        'Set New PIN',
        style: TextStyle(
            color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
      ),
      confirmTitle: const Text(
        'Confirm New PIN',
        style: TextStyle(
            color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
      ),
      onConfirmed: (newPin) async {
        await _storage.write(key: 'user_pin', value: newPin);
        if (mounted) {
          Navigator.of(context).pop();
          _showSnack('PIN updated successfully!', isError: false);
        }
      },
    );
  }

  // ── Snackbar ────────────────────────────────────────────────────────────

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? Colors.red[700] : Colors.teal[700],
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon:
                  const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            title: const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
          ),
          body: _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: Colors.tealAccent))
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                    children: [
                      // ── Biometrics ───────────────────────────────────
                      if (_deviceHasBiometrics) ...[
                        _SectionHeader(label: 'Biometrics'),
                        const SizedBox(height: 10),
                        _buildFingerprintTile(),
                        const SizedBox(height: 28),
                      ],

                      // ── Backup ───────────────────────────────────────
                      _SectionHeader(label: 'Backup'),
                      const SizedBox(height: 10),
                      _SettingsTile(
                        icon: Icons.upload_outlined,
                        iconColor: Colors.tealAccent,
                        title: 'Export Passwords',
                        subtitle:
                            'Save an AES-256 encrypted backup file.',
                        onTap: _exportPasswords,
                      ),
                      const SizedBox(height: 10),
                      _SettingsTile(
                        icon: Icons.download_outlined,
                        iconColor: Colors.tealAccent,
                        title: 'Import Passwords',
                        subtitle:
                            'Restore credentials from a backup file.',
                        onTap: _importPasswords,
                      ),
                      const SizedBox(height: 28),

                      // ── PIN ──────────────────────────────────────────
                      _SectionHeader(label: 'PIN'),
                      const SizedBox(height: 10),
                      _SettingsTile(
                        icon: Icons.lock_outline_rounded,
                        iconColor: Colors.tealAccent,
                        title: 'Change PIN',
                        subtitle:
                            'Verify your current PIN to set a new one.',
                        onTap: _startChangePinFlow,
                      ),
                      if (_fingerprintEnabled) ...[
                        const SizedBox(height: 10),
                        _SettingsTile(
                          icon: Icons.fingerprint_rounded,
                          iconColor: Colors.purpleAccent,
                          title: 'Forgot PIN?',
                          subtitle:
                              'Reset your PIN using fingerprint.',
                          onTap: _startForgotPinFlow,
                          accentColor: Colors.purple,
                        ),
                      ],
                    ],
                  ),
                ),
        ),

        // ── Busy overlay ─────────────────────────────────────────────────
        if (_isBusy)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: Colors.black.withAlpha(140),
              child: Center(
                child: Container(
                  width: 230,
                  padding: const EdgeInsets.symmetric(
                      vertical: 36, horizontal: 28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                        color: Colors.teal.withAlpha(77), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withAlpha(50),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.teal.withAlpha(30),
                          border: Border.all(
                              color: Colors.teal.withAlpha(100), width: 1.5),
                        ),
                        child: const Icon(Icons.shield_outlined,
                            color: Colors.teal, size: 34),
                      ),
                      const SizedBox(height: 24),
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                            color: Colors.teal, strokeWidth: 2.5),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        _busyLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _busySubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12.5,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFingerprintTile() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: SwitchListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        secondary: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.teal.withAlpha(25),
            border:
                Border.all(color: Colors.teal.withAlpha(80), width: 1),
          ),
          child: const Icon(Icons.fingerprint_rounded,
              color: Colors.tealAccent, size: 24),
        ),
        title: const Text(
          'Use Fingerprint',
          style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _deviceHasBiometrics
              ? 'Applies to lock screen & password viewing'
              : 'No biometrics found on this device',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        value: _fingerprintEnabled,
        onChanged: _deviceHasBiometrics ? _toggleFingerprint : null,
        activeThumbColor: Colors.tealAccent,
        inactiveThumbColor: Colors.grey[600],
        inactiveTrackColor: Colors.grey[800],
      ),
    );
  }
}

// ── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: Colors.grey[500],
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ── Reusable settings tile ───────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color accentColor;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accentColor = Colors.teal,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withAlpha(25),
                border: Border.all(
                    color: accentColor.withAlpha(80), width: 1),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          height: 1.4)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[700], size: 20),
          ],
        ),
      ),
    );
  }
}
