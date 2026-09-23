import 'package:flutter_test/flutter_test.dart';
import 'package:friend_app/main.dart';

void main() {
  testWidgets('Friend login UI renders', (tester) async {
    await tester.pumpWidget(const FriendApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Friend'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
  });
}
