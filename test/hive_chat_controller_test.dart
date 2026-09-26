import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:friend_app/flyer_example/hive_chat_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    Hive.init('./test/.hive_test');
    if (await Hive.boxExists('chat')) await Hive.deleteBoxFromDisk('chat');
  });

  tearDown(() async {
    if (Hive.isBoxOpen('chat')) await Hive.box('chat').close();
    if (await Hive.boxExists('chat')) await Hive.deleteBoxFromDisk('chat');
  });

  test('opens an empty chat box for a first-time Local session', () async {
    expect(await Hive.boxExists('chat'), isFalse);
    if (!await Hive.boxExists('chat')) await Hive.openBox('chat');
    final controller = HiveChatController();
    expect(controller.messages, isEmpty);
    controller.dispose();
  });
}
