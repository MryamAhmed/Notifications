// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:notifecation/main.dart';

void main() {
  testWidgets('Notification spike screen renders actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Phase 1: Local Notifications'), findsOneWidget);
    expect(find.text('Request notification permission'), findsOneWidget);
    expect(find.text('Show notification'), findsOneWidget);
    expect(find.text('Update notification with progress'), findsOneWidget);
    expect(find.text('Cancel notification'), findsOneWidget);

    expect(
        find.textContaining('Channel: progress_notifications'), findsOneWidget);
  });
}
