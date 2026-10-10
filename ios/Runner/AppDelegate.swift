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
    let channel = FlutterMethodChannel(
      name: "com.outmcn.dd/aliyun_rtc",
      binaryMessenger: controller.binaryMessenger
    )
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
            let token = args["token"] as? String else {
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
      _ = engine.publishLocalAudioStream(true)
      let code = engine.joinChannel(auth, name: userId) { [weak self] (errorCode: Int, channelName: String, joinedUserId: String, _ elapsed: Int) in
        DispatchQueue.main.async {
          if errorCode == 0 {
            self?.rtcChannel?.invokeMethod("joined", arguments: ["channelId": channelName, "userId": joinedUserId])
          } else {
            self?.rtcChannel?.invokeMethod("error", arguments: ["code": errorCode])
          }
        }
      }
      if code != 0 { result(FlutterError(code: "join_failed", message: "加入 RTC 频道失败", details: code)) }
      else { result(true) }
    case "mute":
      let enabled = (call.arguments as? Bool) ?? false
      result(rtcEngine?.publishLocalAudioStream(!enabled) == 0)
    case "leave":
      result(rtcEngine?.leaveChannel() == 0)
      rtcEngine = nil
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
