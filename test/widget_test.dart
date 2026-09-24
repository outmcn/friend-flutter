import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:friend_app/main.dart';
import 'package:friend_app/pages/game_page.dart';

void main() {
  testWidgets('Friend login UI renders', (tester) async {
    await tester.pumpWidget(const FriendApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Friend'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
  });

  testWidgets('home game entry opens Gomoku', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.tap(find.text('进入游戏'));
    await tester.pumpAndSettle();
    expect(find.text('五子棋'), findsOneWidget);
    await tester.tap(find.text('五子棋'));
    await tester.pumpAndSettle();
    expect(find.byType(GomokuPage), findsOneWidget);
  });
}
