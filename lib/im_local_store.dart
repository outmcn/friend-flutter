import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Small JSON-backed local IM store. It keeps the chat contract isolated so it
/// can later be replaced by SQLite without changing the page/service API.
class ImLocalStore {
  static Future<dynamic> _read() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/friend_im_cache.json');
    if (!await file.exists()) return <String, dynamic>{};
    try {
      return jsonDecode(await file.readAsString());
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<void> _write(Map<String, dynamic> data) async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/friend_im_cache.json');
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(data), flush: true);
    await temp.rename(file.path);
  }

  static Future<List<Map<String, dynamic>>> messages(
      String conversationId) async {
    final data = await _read();
    final raw = data['messages'] is Map
        ? (data['messages'] as Map)[conversationId]
        : null;
    return raw is List
        ? raw
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList()
        : <Map<String, dynamic>>[];
  }

  static Future<void> saveMessages(
      String conversationId, List<Map<String, dynamic>> messages) async {
    final data = Map<String, dynamic>.from(await _read() as Map);
    final all = data['messages'] is Map
        ? Map<String, dynamic>.from((data['messages'] as Map).cast())
        : <String, dynamic>{};
    all[conversationId] = messages;
    data['messages'] = all;
    await _write(data);
  }
}
