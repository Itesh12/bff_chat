import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/core/design_system/feedback/app_snack_bar.dart';

void main() {
  group('AppSnackBar Integration & Null-Safety Tests', () {
    testWidgets('AppSnackBar triggers without crashing under test environments', (tester) async {
      // 1. Build a basic scaffold context
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      AppSnackBar.success(
                        title: 'Success Title',
                        message: 'Success Message',
                      );
                      AppSnackBar.error(
                        title: 'Error Title',
                        message: 'Error Message',
                      );
                      AppSnackBar.info(
                        title: 'Info Title',
                        message: 'Info Message',
                      );
                    },
                    child: const Text('Show Snackbars'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // 2. Tap to trigger AppSnackBar calls
      final btn = find.text('Show Snackbars');
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      
      // 3. Pump enough frames to make sure animations and timers complete cleanly
      await tester.pumpAndSettle();
      
      // If we reach here without throwing, then the null-safe check inside AppSnackBar works
      // flawlessly even when AppColorScheme is not present in ThemeData.
    });
  });
}
