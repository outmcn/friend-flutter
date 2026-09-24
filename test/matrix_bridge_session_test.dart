import 'package:flutter_test/flutter_test.dart';
// ignore_for_file: avoid_relative_lib_imports
import '../lib/models/matrix_bridge_session.dart';

void main() {
  test(
    'parses the server-issued Matrix session without using Friend token',
    () {
      final session = MatrixBridgeSession.fromJson(const {
        'userId': '@friend_2:matrix.friend.outmcn.net',
        'deviceId': 'DEVICE123',
        'accessToken': 'matrix-access-token',
      });

      expect(session.userId, '@friend_2:matrix.friend.outmcn.net');
      expect(session.deviceId, 'DEVICE123');
      expect(session.accessToken, 'matrix-access-token');
    },
  );
}
