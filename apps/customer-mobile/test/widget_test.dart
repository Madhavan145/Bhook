// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

import 'package:bhook_customer/src/app.dart';

void main() {
  testWidgets('customer app opens the sign-in screen',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpWidget(const ProviderScope(child: BhookCustomerApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Welcome back'), findsOneWidget);
  });
}
