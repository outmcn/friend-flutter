import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dd/main.dart';

void main() {
  testWidgets('DD onboarding UI renders', (tester) async {
    await tester.pumpWidget(const DDApp());
    expect(find.text('DD'), findsOneWidget);
    expect(find.text('开始使用'), findsOneWidget);
  });

  testWidgets('DD auth flow opens home shell', (tester) async {
    await tester.pumpWidget(const DDApp());
    await tester.tap(find.text('开始使用'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();
    expect(find.text('首页'), findsWidgets);
    expect(find.text('发现'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}
