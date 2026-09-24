import 'package:flutter_test/flutter_test.dart';
// ignore_for_file: avoid_relative_lib_imports
import '../lib/models/matrix_chat_message.dart';

void main() {
  test('chat message keeps sender direction and body', () {
    const message = MatrixChatMessage(
      eventId: r'$event:matrix.friend.outmcn.net',
      senderId: '@friend_2:matrix.friend.outmcn.net',
      body: '你好',
      isMine: true,
    );

    expect(message.body, '你好');
    expect(message.isMine, isTrue);
  });
}
