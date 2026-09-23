import 'package:flutter_test/flutter_test.dart';
import 'package:friend_app/main.dart';

void main() {
  testWidgets('Friend UI renders four tabs', (tester) async {
    await tester.pumpWidget(const FriendApp());
    expect(find.text('Friend'), findsOneWidget);
    expect(find.text('发现'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}
