import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

class MatrixSession extends ChangeNotifier {
  MatrixSession._(this.client);

  final Client client;
  bool ready = false;
  String? error;

  static Future<MatrixSession> create() async {
    final directory = await getApplicationSupportDirectory();
    final database = await sqflite.openDatabase(
      '${directory.path}/friend_matrix.sqlite',
    );
    final matrixDatabase = await MatrixSdkDatabase.init(
      'friend_matrix',
      database: database,
    );
    final client = Client('Friend Matrix', database: matrixDatabase);
    await client.checkHomeserver(Uri.parse('https://matrix.friend.outmcn.net'));
    final session = MatrixSession._(client);
    await session._restore();
    return session;
  }

  Future<void> _restore() async {
    try {
      if (client.isLogged()) {
        ready = true;
      }
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> login({required String userId, required String password}) async {
    error = null;
    notifyListeners();
    try {
      await client.login(
        AuthenticationTypes.password,
        identifier: AuthenticationUserIdentifier(user: userId),
        password: password,
        initialDeviceDisplayName: 'Friend Flutter',
      );
      ready = true;
      client.backgroundSync = true;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  List<Room> directRooms() =>
      client.rooms.where((room) => room.isDirectChat).toList();

  Stream<void> get updates => client.onSync.stream.map((_) {});

  bool get isLoggedIn => client.isLogged();

  Future<void> sendText(Room room, String text) async {
    final value = text.trim();
    if (value.isEmpty) return;
    await room.sendTextEvent(value);
  }

  Future<void> logout() async {
    await client.logout();
    ready = false;
    notifyListeners();
  }

  @override
  void dispose() {
    client.dispose();
    super.dispose();
  }
}
