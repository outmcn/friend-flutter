import 'package:flutter_test/flutter_test.dart';
// ignore_for_file: avoid_relative_lib_imports
import '../lib/models/matrix_room_view.dart';

void main() {
  test('room view data keeps real Matrix room fields', () {
    const data = MatrixRoomViewData(
      roomId: '!room:matrix.friend.outmcn.net',
      title: 'Alice',
      preview: '你好',
      unreadCount: 2,
    );

    expect(data.roomId, '!room:matrix.friend.outmcn.net');
    expect(data.title, 'Alice');
    expect(data.preview, '你好');
    expect(data.unreadCount, 2);
  });
}
