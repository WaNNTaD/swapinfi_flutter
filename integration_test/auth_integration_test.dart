import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_swapinfi/main.dart'; // Adjust this path if necessary
import 'package:new_swapinfi/providers/auth/auth_provider.dart';
import 'package:new_swapinfi/providers/storage/secure_storage_service.dart';

void main() {
  testWidgets('Test de connexion avec des identifiants valides',
      (WidgetTester tester) async {
    // Mock or create instances of AuthProvider and SecureStorageService
    final authProvider = AuthProvider(); // Or use a mock if needed
    final secureStorageService =
        SecureStorageService(); // Or use a mock if needed

    // Load the app's main widget with the required parameters
    await tester.pumpWidget(App(
      authProvider: authProvider,
      secureStorageService: secureStorageService,
    ));

    // Wait for the UI to stabilize
    await tester.pumpAndSettle();

    // Find the text fields and button by their keys
    final emailField = find.byKey(Key('emailField'));
    final passwordField = find.byKey(Key('passwordField'));
    final loginButton = find.byKey(Key('loginButton'));

    // Ensure the fields are found
    expect(emailField, findsOneWidget);
    expect(passwordField, findsOneWidget);
    expect(loginButton, findsOneWidget);

    // Enter text into the fields
    await tester.enterText(emailField, 'test@test.test');
    await tester.enterText(passwordField, 'Test123*');

    // Close the keyboard
    await tester.testTextInput.receiveAction(TextInputAction.done);

    // Wait for the UI to stabilize
    await tester.pumpAndSettle();

    // Tap the login button
    await tester.tap(loginButton);

    // Wait for the UI to stabilize after the button press
    await tester.pumpAndSettle();

    // Additional verification (e.g., checking for navigation or state changes)
  });
}
