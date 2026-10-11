import UIKit
import Flutter
import DingRTC
import UserNotifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, DingRtcEngineDelegate, UNUserNotificationCenterDelegate {
  private var rtcEngine: DingRtcEngine?
  private var rtcChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    application.registerForRemoteNotifications()
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

  func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if let type = userInfo["type"] as? String, type == "call:incoming" {
      rtcChannel?.invokeMethod("remoteCallIncoming", arguments: userInfo)
    }
    completionHandler(.newData)
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound, .badge])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    rtcChannel?.invokeMethod("notificationTapped", arguments: response.notification.request.content.userInfo)
    completionHandler()
  }

  private func handleRtc(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "join":
      guard let args = call.arguments as? [String: Any],
            let appId = args["appId"] as? String,
            let channelId = args["channelId"] as? String,
            let userId = args["userId"] as? String,
            let token = args["token"] as? String,
            !token.isEmpty else {
        result(FlutterError(code: "invalid_args", message: "RTC Token 参数无效", details: nil))
        return
      }
      let engine = DingRtcEngine.createInstance(self, extras: nil)
      rtcEngine = engine
      let authInfo = DingRtcAuthInfo()
      authInfo.appId = appId
      authInfo.channelId = channelId
      authInfo.userId = userId
      authInfo.token = token
      authInfo.gslbServer = "https://rgslb.rtc.aliyuncs.com"
      _ = engine.subscribeAllRemoteAudioStreams(true)
      _ = engine.enableSpeakerphone(true)
      _ = engine.startAudioPlayer()
      _ = engine.startAudioCapture()
      _ = engine.publishLocalAudioStream(true)
      let code = engine.joinChannel(authInfo, name: nil) { [weak self] errorCode, channelName, joinedUserId, _ in
        DispatchQueue.main.async {
          if errorCode == 0 {
            self?.rtcChannel?.invokeMethod("joined", arguments: ["channelId": channelName, "userId": joinedUserId])
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
      result(rtcEngine?.publishLocalAudioStream(!muted) == 0)
    case "leave":
      let engine = rtcEngine
      _ = engine?.publishLocalAudioStream(false)
      _ = engine?.stopAudioCapture()
      _ = engine?.stopAudioPlayer()
      let code = engine?.leaveChannel() ?? 0
      result(code == 0)
      DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2.0) {
        if let engine {
          DingRtcEngine.destroyInstance(engine)
        }
        DispatchQueue.main.async { [weak self] in
          self?.rtcEngine = nil
        }
      }
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
