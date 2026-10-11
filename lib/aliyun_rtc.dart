import 'dart:convert';

import 'package:flutter/services.dart';

/// Flutter bridge for the native Alibaba Cloud DingRTC audio engine.
class AliyunRtcBridge {
  static const _channel = MethodChannel('com.outmcn.dd/aliyun_rtc');

  static Future<void> join(Map<String, dynamic> rtc) async {
    final rawToken = '${rtc['token'] ?? ''}';
    final payload = <String, dynamic>{
      'appid': '${rtc['appId'] ?? ''}',
      'channelid': '${rtc['channelId'] ?? ''}',
      'userid': '${rtc['userId'] ?? ''}',
      'nonce': '${rtc['nonce'] ?? ''}',
      'timestamp': rtc['timestamp'] is int
          ? rtc['timestamp']
          : int.tryParse('${rtc['timestamp'] ?? ''}') ?? 0,
      'token': rawToken,
    };
    final singleParameterToken = '${rtc['token'] ?? ''}'.startsWith('000')
        ? rawToken
        : '000${base64Encode(utf8.encode(jsonEncode(payload)))}';
    await _channel.invokeMethod('join', {'token': singleParameterToken});
  }

  static Future<void> setMuted(bool muted) async {
    await _channel.invokeMethod('mute', muted);
  }

  static Future<void> leave() async {
    await _channel.invokeMethod('leave');
  }

  /// Subscribes to remote audio and forwards native lifecycle events to Dart.
  static Future<void> subscribeRemoteAudio(bool enabled) async {
    await _channel.invokeMethod('subscribeRemoteAudio', enabled);
  }

  static void setEventHandler(
      void Function(String method, dynamic args)? handler) {
    _channel.setMethodCallHandler((call) async {
      handler?.call(call.method, call.arguments);
    });
  }
}
