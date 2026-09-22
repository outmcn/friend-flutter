import 'package:flutter_test/flutter_test.dart';
import 'package:friend_app/main.dart';

void main() {
  testWidgets('Friend app renders', (tester) async {
    await tester.pumpWidget(const FriendApp());
    expect(find.text('Friend'), findsOneWidget);
  });
}
