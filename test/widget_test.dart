// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:zoloz_repro_demo/main.dart';

void main() {
  testWidgets('Repro app renders title', (WidgetTester tester) async {
    await tester.pumpWidget(const ReproApp());

    expect(find.text('ZOLOZ Flutter Repro'), findsOneWidget);
    expect(find.text('Start ZOLOZ'), findsOneWidget);
  });
}
