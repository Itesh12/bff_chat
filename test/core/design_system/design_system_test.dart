import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/core/design_system/design_system.dart';

void main() {
  group('AppGap Tests', () {
    testWidgets('AppGap.v16 creates a vertical gap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('A'),
                AppGap.v16(),
                Text('B'),
              ],
            ),
          ),
        ),
      );

      final gapFinder = find.byType(AppGap);
      expect(gapFinder, findsOneWidget);
      
      final SizedBox sizeBox = tester.widget<SizedBox>(find.descendant(
        of: gapFinder,
        matching: find.byType(SizedBox),
      ));
      expect(sizeBox.height, AppSpacing.s16);
      expect(sizeBox.width, isNull);
    });

    testWidgets('AppGap.h8 creates a horizontal gap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Text('A'),
                AppGap.h8(),
                Text('B'),
              ],
            ),
          ),
        ),
      );

      final gapFinder = find.byType(AppGap);
      expect(gapFinder, findsOneWidget);

      final SizedBox sizeBox = tester.widget<SizedBox>(find.descendant(
        of: gapFinder,
        matching: find.byType(SizedBox),
      ));
      expect(sizeBox.width, AppSpacing.s8);
      expect(sizeBox.height, isNull);
    });
  });

  group('AppChip Tests', () {
    testWidgets('renders chip label with correct tag padding', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppChip(label: 'Work', color: Colors.blue),
          ),
        ),
      );

      expect(find.text('Work'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container));
      expect(container.decoration, isA<BoxDecoration>());
      
      final dec = container.decoration as BoxDecoration?;
      expect(dec?.borderRadius, equals(AppRadius.max));
    });
  });

  group('AppCard Tests', () {
    testWidgets('renders child and registers tap callbacks', (tester) async {
      bool isTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              onTap: () => isTapped = true,
              child: const Text('Inner Content'),
            ),
          ),
        ),
      );

      expect(find.text('Inner Content'), findsOneWidget);
      await tester.tap(find.text('Inner Content'));
      expect(isTapped, isTrue);
    });
  });

  group('AppButton Tests', () {
    testWidgets('primary variant renders correctly and handles clicks', (tester) async {
      bool isClicked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.primary(
              text: 'Save',
              onPressed: () => isClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('Save'), findsOneWidget);
      await tester.tap(find.text('Save'));
      expect(isClicked, isTrue);
    });

    testWidgets('onPressedAsync executes loading and triggers callback', (tester) async {
      bool isFired = false;
      final completer = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.primary(
              text: 'Submit Async',
              onPressedAsync: () async {
                isFired = true;
                await completer.future;
              },
            ),
          ),
        ),
      );

      expect(find.text('Submit Async'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Tap to trigger async operation
      await tester.tap(find.text('Submit Async'));
      await tester.pump(); // Start callback

      expect(isFired, isTrue);
      // Verify loading state is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle(); // Resolve future and animate

      // Loader is gone, back to text
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Submit Async'), findsOneWidget);
    });
  });

  group('AppIconButton Tests', () {
    testWidgets('renders standard icon and taps', (tester) async {
      bool isClicked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIconButton.secondary(
              icon: Icons.star,
              onPressed: () => isClicked = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
      await tester.tap(find.byIcon(Icons.star));
      expect(isClicked, isTrue);
    });
  });

  group('AppTextField Tests', () {
    testWidgets('renders password field and toggles obscure text visibility', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTextField.password(
              hintText: 'Passcode',
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);

      // Tap show password visibility toggle
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      final toggledTextField = tester.widget<TextField>(find.byType(TextField));
      expect(toggledTextField.obscureText, isFalse);
    });

    testWidgets('search field debounces query changes', (tester) async {
      String result = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField.search(
              hintText: 'Search...',
              onChanged: (val) => result = val,
              debounceDuration: const Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Meet');
      await tester.pump();

      // Debounce period is 100ms, should be blank initially
      expect(result, equals(''));

      // Wait for debouncer
      await tester.pump(const Duration(milliseconds: 120));
      expect(result, equals('Meet'));
    });
  });

  group('AppScaffold Tests', () {
    testWidgets('renders scaffold children and displays loader/error banners', (tester) async {
      bool isRetried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppScaffold(
              title: 'Dashboard Page',
              errorMessage: 'Network connection lost',
              onRetry: () => isRetried = true,
              body: const Text('Scaffold Content'),
            ),
          ),
        ),
      );

      // Verify title appBar & error text shown
      expect(find.text('Dashboard Page'), findsOneWidget);
      expect(find.text('Network connection lost'), findsOneWidget);
      expect(find.text('Scaffold Content'), findsNothing); // Overridden by error

      // Tap retry
      await tester.tap(find.text('Try Again'));
      expect(isRetried, isTrue);
    });
  });
}
