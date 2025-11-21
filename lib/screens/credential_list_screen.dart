import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_screen_lock/flutter_screen_lock.dart';
import 'package:password_manager/services/database_helper.dart';
import 'package:password_manager/widgets/credential_card.dart';
import 'package:password_manager/screens/edit_credential_screen.dart';
import 'package:password_manager/screens/add_credential_screen.dart';

class CredentialsListScreen extends StatefulWidget {
  final String appName;

  const CredentialsListScreen({super.key, required this.appName});

  @override
  State<CredentialsListScreen> createState() => _CredentialsListScreenState();
}

class _CredentialsListScreenState extends State<CredentialsListScreen> {
  final _dbHelper = DatabaseHelper();
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
  }

  void _verifyPin(VoidCallback onSuccess) async {
    final pin = await _storage.read(key: 'user_pin');
    if (pin == null) return;
    if (!mounted) return;

    screenLock(
      context: context,
      correctString: pin,
      onUnlocked: () {
        Navigator.pop(context);
        onSuccess();
      },
      title: const Text(
        'Verify your PIN',
        style: TextStyle(color: Colors.white),
      ),
      deleteButton: const Icon(Icons.backspace, size: 40, color: Colors.white),
    );
  }

  void _showConfirmationDialog({
    required String title,
    required String message,
    required VoidCallback onConfirm,
    bool isDelete = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text(
              'Confirm',
              style: TextStyle(color: isDelete ? Colors.red : Colors.teal),
            ),
          ),
        ],
      ),
    );
  }

  void _handleEditCredential({
    required int id,
    required String appName,
    required String username,
    required String password,
  }) async {
    _showConfirmationDialog(
      title: 'Edit Password',
      message: 'Are you sure you want to edit this password?',
      onConfirm: () {
        _verifyPin(() {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditCredentialScreen(
                id: id,
                appName: appName,
                username: username,
                password: password,
              ),
            ),
          ).then((_) => setState(() {}));
        });
      },
    );
  }

  void _handleDeleteCredential(int id) async {
    _showConfirmationDialog(
      title: 'Delete Password',
      message:
          'Are you sure you want to delete this password? This action cannot be undone.',
      isDelete: true,
      onConfirm: () {
        _verifyPin(() async {
          await _dbHelper.deleteCredential(id);
          if (mounted) {
            // Check if there are any remaining credentials for this app
            final remainingCredentials = await _dbHelper.getCredentialsForApp(
              widget.appName,
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Credential deleted')),
              );

              if (remainingCredentials.isEmpty) {
                // If no credentials left, go back to Home Screen immediately but safely
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    Navigator.pop(context);
                  }
                });
              } else {
                // Otherwise, just refresh the list
                setState(() {});
              }
            }
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.appName),
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.teal),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _dbHelper.getCredentialsForApp(widget.appName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            );
          }

          final credentials = snapshot.data ?? [];

          if (credentials.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.key_off, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text(
                    'No credentials',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: credentials.length,
            itemBuilder: (context, index) {
              final cred = credentials[index];
              return CredentialCard(
                id: cred['id'],
                username: cred['username'],
                password: cred['password'],
                onEdit: () {
                  _handleEditCredential(
                    id: cred['id'],
                    appName: widget.appName,
                    username: cred['username'],
                    password: cred['password'],
                  );
                },
                onDelete: () {
                  _handleDeleteCredential(cred['id']);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddCredentialScreen(appName: widget.appName),
            ),
          ).then((_) => setState(() {}));
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
