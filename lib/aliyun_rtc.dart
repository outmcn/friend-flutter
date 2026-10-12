import 'package:flutter/services.dart';

/// Flutter bridge for the native Alibaba Cloud DingRTC audio engine.
class AliyunRtcBridge {
  static const _channel = MethodChannel('com.outmcn.dd/aliyun_rtc');

  static int _generation = 0;
  static String? _sessionId;

  static Future<void> join(Map<String, dynamic> rtc) async {
    _sessionId = '${++_generation}';
    await _channel.invokeMethod('join', {
      'sessionId': _sessionId,
      'appId': '${rtc['appId'] ?? ''}',
      'channelId': '${rtc['channelId'] ?? ''}',
      'userId': '${rtc['userId'] ?? ''}',
      'token': '${rtc['token'] ?? ''}',
    });
  }

  static Future<void> setMuted(bool muted) async {
    await _channel.invokeMethod('mute', muted);
  }

  static Future<void> setSpeakerEnabled(bool enabled) async {
    await _channel.invokeMethod('speaker', enabled);
  }

  static Future<void> leave() async {
    _sessionId = null;
    await _channel.invokeMethod('leave');
  }

  static Future<void> subscribeRemoteAudio(bool enabled) async {
    await _channel.invokeMethod('subscribeRemoteAudio', enabled);
  }

  static void setEventHandler(
      void Function(String method, dynamic args)? handler) {
    _channel.setMethodCallHandler((call) async {
      final args = call.arguments;
      if (args is Map &&
          args['sessionId'] != null &&
          args['sessionId'] != _sessionId) {
        return;
      }
      handler?.call(call.method, args);
    });
  }
}
