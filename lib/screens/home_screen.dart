import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:password_manager/services/backup_service.dart';
import 'package:password_manager/services/database_helper.dart';
import 'package:password_manager/screens/credential_list_screen.dart';
import 'package:password_manager/screens/add_credential_screen.dart';
import 'package:password_manager/screens/change_pin_screen.dart';
import 'package:password_manager/widgets/backup_password_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _dbHelper = DatabaseHelper();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _allApps = [];
  List<Map<String, dynamic>> _filteredApps = [];

  @override
  void initState() {
    super.initState();
    _loadApps();
    _searchController.addListener(_filterApps);
  }

  bool _isBusy = false;
  String _busyLabel = '';
  String _busySubtitle = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    final apps = await _dbHelper.getAppsWithCounts();
    setState(() {
      _allApps = apps;
      _filteredApps = apps;
    });
  }

  // ── Export ──────────────────────────────────────────────────────────────

  Future<void> _exportPasswords() async {
    final password = await BackupPasswordDialog.show(context, isExport: true);
    if (password == null || !mounted) return;

    // Phase 1: Encrypt and write the file — show busy overlay during this.
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
      // Always hide the overlay BEFORE the share sheet opens.
      if (mounted) setState(() => _isBusy = false);
    }

    // Phase 2: Open the share sheet — no busy overlay so the UI is clean.
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
    } catch (e) {
      if (mounted) _showSnack('Failed to share backup.', isError: true);
    }
  }

  // ── Import ──────────────────────────────────────────────────────────────

  Future<void> _importPasswords() async {
    // Step 1: Pick file first (no busy overlay yet — file picker is open).
    late String fileContent;
    try {
      final content = await BackupService.pickBackupFile();
      if (content == null || !mounted) return; // user cancelled
      fileContent = content;
    } on BackupException catch (e) {
      if (mounted) _showSnack(e.message, isError: true);
      return;
    }

    // Step 2: Ask for the backup password (file is already in memory).
    if (!mounted) return;
    final password = await BackupPasswordDialog.show(context, isExport: false);
    if (password == null || !mounted) return;

    // Step 3: Decrypt and import (show busy overlay during this CPU work).
    setState(() {
      _isBusy = true;
      _busyLabel = 'Decrypting Backup';
      _busySubtitle = 'Verifying password and\nrestoring your credentials';
    });
    try {
      final count = await BackupService.decryptAndImport(fileContent, password);
      if (mounted) {
        _showSnack(
          '$count ${count == 1 ? 'credential' : 'credentials'} imported!',
          isError: false,
        );
        await _loadApps();
      }
    } on BackupException catch (e) {
      if (mounted) _showSnack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ── Helper ───────────────────────────────────────────────────────────────

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _filterApps() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredApps = _allApps
          .where(
            (app) => (app['appName'] as String).toLowerCase().contains(query),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'Your Passwords',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                color: const Color(0xFF1C1C1E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  if (value == 'export') _exportPasswords();
                  if (value == 'import') _importPasswords();
                  if (value == 'change_pin') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangePinScreen(),
                      ),
                    );
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(
                          Icons.upload_outlined,
                          color: Colors.teal,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Export Passwords',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'import',
                    child: Row(
                      children: [
                        Icon(
                          Icons.download_outlined,
                          color: Colors.teal,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Import Passwords',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'change_pin',
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_reset_rounded,
                          color: Colors.tealAccent,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Change PIN',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Header with total count
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${_allApps.length} App${_allApps.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                // Search Box
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search apps or websites',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Apps List
                Expanded(
                  child: _filteredApps.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 64,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _allApps.isEmpty
                                    ? 'No passwords yet'
                                    : 'No results found',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _filteredApps.length,
                          itemBuilder: (context, index) {
                            final appData = _filteredApps[index];
                            final appName = appData['appName'] as String;
                            final count = appData['count'] as int;

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CredentialsListScreen(appName: appName),
                                  ),
                                ).then((_) => _loadApps());
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[800]!),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            appName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$count credential${count != 1 ? 's' : ''}',
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey[600],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.teal,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddCredentialScreen()),
              ).then((_) => _loadApps());
            },
            child: const Icon(Icons.add, color: Colors.black),
          ),
        ),
        // Busy overlay — glassmorphism card with backdrop blur
        if (_isBusy)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: Colors.black.withAlpha(140),
              child: Center(
                child: Container(
                  width: 230,
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 28,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.teal.withAlpha(77),
                      width: 1.5,
                    ),
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
                      // Shield icon with glow ring
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.teal.withAlpha(30),
                          border: Border.all(
                            color: Colors.teal.withAlpha(100),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: Colors.teal,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Slim spinner
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          color: Colors.teal,
                          strokeWidth: 2.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      // Title
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
                      // Subtitle
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
}
