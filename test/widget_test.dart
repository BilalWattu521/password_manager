import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/main.dart';

void main() {
  const MethodChannel channel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'read') {
            return null; // Simulate no PIN set
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('MyApp shows loading then SetPinScreen when no PIN is set', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our loading indicator is shown.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Trigger a frame to allow the Future to complete.
    await tester.pumpAndSettle();

    // Verify that SetPinScreen is shown by finding the "Create PIN" button text.
    expect(find.text('Create PIN'), findsOneWidget);
    expect(find.text('Welcome to \nPassword Manager'), findsOneWidget);
  });
}
