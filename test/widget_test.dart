import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:memovault/app.dart';
import 'package:memovault/core/services/theme_service.dart';

void main() {
  testWidgets('App renders without crashing', (tester) async {
    Get.put<ThemeService>(ThemeService(), permanent: true);
    await tester.pumpWidget(const App());
    expect(find.byType(App), findsOneWidget);
  });
}
