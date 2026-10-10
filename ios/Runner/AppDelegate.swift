import UIKit
import Flutter
import AliVCSDK_ARTC

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, AliRtcEngineDelegate {
  private var rtcEngine: AliRtcEngine?
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
            let token = args["token"] as? String else {
        result(FlutterError(code: "invalid_args", message: "RTC 参数无效", details: nil))
        return
      }
      let engine = AliRtcEngine.sharedInstance(self, extras: nil)
      rtcEngine = engine
      engine.setDefaultSubscribeAllRemoteAudioStreams(true)
      engine.subscribeAllRemoteAudioStreams(true)
      engine.publishLocalAudioStream(true)
      let code = engine.joinChannel(
        token,
        channelId: channelId,
        userId: userId,
        name: userName
      ) { [weak self] errorCode, joinedChannel, joinedUserId, _ in
        DispatchQueue.main.async {
          if errorCode == 0 {
            self?.rtcChannel?.invokeMethod("joined", arguments: ["channelId": joinedChannel, "userId": joinedUserId])
          } else {
            self?.rtcChannel?.invokeMethod("error", arguments: ["code": errorCode])
          }
        }
      }
      result(code == 0 ? true : FlutterError(code: "join_failed", message: "加入 RTC 频道失败", details: code))
    case "subscribeRemoteAudio":
      let enabled = (call.arguments as? Bool) ?? true
      result(rtcEngine?.subscribeAllRemoteAudioStreams(enabled) == 0)
    case "mute":
      let muted = (call.arguments as? Bool) ?? false
      result(rtcEngine?.muteLocalAudio(muted) == 0)
    case "leave":
      let code = rtcEngine?.leaveChannel() ?? 0
      result(code == 0)
      AliRtcEngine.destroy()
      rtcEngine = nil
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onRemoteUserOffLineNotify(_ uid: String, offlineReason reason: AliRtcUserOfflineReason) {
    DispatchQueue.main.async { [weak self] in
      self?.rtcChannel?.invokeMethod("remoteLeft", arguments: ["userId": uid, "reason": reason.rawValue])
    }
  }

  func onRemoteTrackAvailableNotify(_ uid: String, audioTrack: AliRtcAudioTrack, videoTrack: AliRtcVideoTrack) {
    DispatchQueue.main.async { [weak self] in
      self?.rtcChannel?.invokeMethod("remoteTrack", arguments: ["userId": uid, "audio": audioTrack.rawValue])
    }
  }

  func onLeaveChannelResult(_ result: Int32, stats: AliRtcStats) {
    DispatchQueue.main.async { [weak self] in
      self?.rtcChannel?.invokeMethod("left", arguments: ["code": result])
    }
  }
}
