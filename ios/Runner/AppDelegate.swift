import UIKit
import Flutter
import DingRTC

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, DingRtcEngineDelegate {
  private var rtcEngine: DingRtcEngine?
  private var rtcChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    let channel = FlutterMethodChannel(name: "com.outmcn.dd/aliyun_rtc", binaryMessenger: controller.binaryMessenger)
    rtcChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleRtc(call: call, result: result)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleRtc(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "join":
      guard let args = call.arguments as? [String: Any],
            let appId = args["appId"] as? String,
            let channelId = args["channelId"] as? String,
            let userId = args["userId"] as? String,
            let userName = args["userName"] as? String,
            let nonce = args["nonce"] as? String,
            let timestampText = args["timestamp"] as? String,
            let token = args["token"] as? String,
            let gslb = args["gslb"] as? String else {
        result(FlutterError(code: "invalid_args", message: "RTC 参数无效", details: nil))
        return
      }
      let engine = DingRtcEngine.createInstance(self, extras: nil)
      rtcEngine = engine
      let auth = DingRtcAuthInfo()
      auth.appId = appId
      auth.channelId = channelId
      auth.userId = userId
      auth.token = token
      auth.gslbServer = gslb.isEmpty ? nil : gslb
      _ = engine.subscribeAllRemoteAudioStreams(true)
      _ = engine.enableSpeakerphone(true)
      _ = engine.startAudioPlayer()
      _ = engine.startAudioCapture()
      _ = engine.publishLocalAudioStream(true)
      let code = engine.joinChannel(auth, name: userName) { [weak self] (errorCode: Int, channelName: String, joinedUserId: String, _ elapsed: Int) in
        DispatchQueue.main.async {
          if errorCode == 0 {
            self?.rtcChannel?.invokeMethod("joined", arguments: ["channelId": channelName, "userId": joinedUserId])
          } else {
            self?.rtcChannel?.invokeMethod("error", arguments: ["code": errorCode])
          }
        }
      }
      if code != 0 {
        result(FlutterError(code: "join_failed", message: "加入 RTC 频道失败", details: code))
      } else {
        result(true)
      }
    case "subscribeRemoteAudio":
      let enabled = (call.arguments as? Bool) ?? true
      result(rtcEngine?.subscribeAllRemoteAudioStreams(enabled) == 0)
    case "mute":
      let muted = (call.arguments as? Bool) ?? false
      result(rtcEngine?.muteLocalAudio(muted) == 0)
    case "leave":
      let code = rtcEngine?.leaveChannel() ?? 0
      result(code == 0)
      rtcEngine = nil
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onRemoteUserOffLineNotify(_ uid: String, offlineReason reason: DingRtcUserOfflineReason) {
    DispatchQueue.main.async { [weak self] in
      self?.rtcChannel?.invokeMethod("remoteLeft", arguments: ["userId": uid, "reason": reason.rawValue])
    }
  }

  func onRemoteTrackAvailableNotify(_ uid: String, audioTrack: DingRtcAudioTrack, videoTrack: DingRtcVideoTrack) {
    DispatchQueue.main.async { [weak self] in
      self?.rtcChannel?.invokeMethod("remoteTrack", arguments: ["userId": uid, "audio": audioTrack.rawValue])
    }
  }

  func onLeaveChannelResult(_ result: Int32, stats: DingRtcStats) {
    DispatchQueue.main.async { [weak self] in
      self?.rtcChannel?.invokeMethod("left", arguments: ["code": result])
    }
  }
}
