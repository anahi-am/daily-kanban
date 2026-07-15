import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_kanban/main.dart';

void main() {
  testWidgets('App renders board page', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DailyPrioritiesApp());
    await tester.pump();
    expect(find.text('Daily Priorities'), findsOneWidget);
  });
}
