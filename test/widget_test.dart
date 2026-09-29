import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dd/main.dart';

void main() {
  testWidgets('DD onboarding UI renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingPage()));
    expect(find.text('DD'), findsOneWidget);
    expect(find.text('开始使用'), findsOneWidget);
  });

  testWidgets('DD auth flow opens home shell', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingPage()));
    await tester.tap(find.text('开始使用'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('密码登录'));
    await tester.pumpAndSettle();
    expect(find.text('密码登录'), findsOneWidget);
    expect(find.text('使用手机号和密码登录 DD'), findsOneWidget);
  });
}
