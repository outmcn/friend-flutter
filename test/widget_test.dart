import 'package:flutter_test/flutter_test.dart';
import 'package:dd/main.dart';

void main() {
  testWidgets('authentication screen is the app entry point', (tester) async {
    await tester.pumpWidget(const FriendUiApp());
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('没有账号？注册'), findsOneWidget);
  });
}
