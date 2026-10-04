import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dd/main.dart';

void main() {
  testWidgets('authentication entry shows restore state', (tester) async {
    await tester.pumpWidget(const FriendUiApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
