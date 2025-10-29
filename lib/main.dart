import 'package:flutter/material.dart';
import 'package:flutter_app_lock/flutter_app_lock.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'screens/set_pin_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _storage = const FlutterSecureStorage();
  bool? _isPinSet;

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  Future<void> _checkPinStatus() async {
    final pin = await _storage.read(key: 'user_pin');
    setState(() {
      _isPinSet = pin != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking PIN status
    if (_isPinSet == null) {
      return MaterialApp(
        title: 'Password Manager',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: Colors.black,
          primaryColor: Colors.teal,
        ),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // If PIN is not set, skip AppLock and go directly to SetPinScreen
    if (!_isPinSet!) {
      return MaterialApp(
        title: 'Password Manager',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: Colors.black,
          primaryColor: Colors.teal,
        ),
        home: SetPinScreen(
          onPinCreated: () {
            setState(() {
              _isPinSet = true;
            });
          },
        ),
      );
    }

    // If PIN is set, wrap with AppLock
    return MaterialApp(
      title: 'Password Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.teal,
      ),
      builder: (context, child) => AppLock(
        // Lock the app immediately on any lifecycle change
        initialBackgroundLockLatency: const Duration(seconds: 0),
        initiallyEnabled: true,
        builder: (context, arg) => child!,
        // Show lock screen when app is locked
        lockScreenBuilder: (context) => const LockScreen(),
      ),
      // Always show HomeScreen as the main content
      // Lock screen will overlay it based on AppLock state
      home: const HomeScreen(),
    );
  }
}
