import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dd/main.dart';

void main() {
  testWidgets('original onboarding layout renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingPage()));
    expect(find.text('开始使用'), findsOneWidget);
  });

  testWidgets('original shell widget is constructible', (tester) async {
    final shell = const DDShell();
    expect(shell, isA<DDShell>());
  });
}
