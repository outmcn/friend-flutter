import UIKit
import Flutter
import DingRTC
import UserNotifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  private var rtcEngine: DingRtcEngine?
  private var rtcDelegate: CallRtcDelegate?
  private var leavingEngine: DingRtcEngine?
  private var leavingDelegate: CallRtcDelegate?
  private var rtcGeneration = 0
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

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if let type = userInfo["type"] as? String, type == "call:incoming" {
      rtcChannel?.invokeMethod("remoteCallIncoming", arguments: userInfo)
    }
    completionHandler(.newData)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  override func userNotificationCenter(
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
      let argsSession = args["sessionId"] as? String ?? ""
      rtcGeneration += 1
      let generation = rtcGeneration
      let oldEngine = rtcEngine
      let oldDelegate = rtcDelegate
      rtcEngine = nil
      rtcDelegate = nil
      oldDelegate?.destroy()
      leavingEngine = nil
      leavingDelegate = nil
      let delegate = CallRtcDelegate()
      delegate.emit = { [weak self] method, args in
        guard let self, self.rtcGeneration == generation else { return }
        var payload = args
        payload["sessionId"] = argsSession
        self.rtcChannel?.invokeMethod(method, arguments: payload)
      }
      let engine = DingRtcEngine.createInstance(delegate, extras: nil)
      delegate.engine = engine
      rtcDelegate = delegate
      rtcEngine = engine
      let authInfo = DingRtcAuthInfo()
      authInfo.appId = appId
      authInfo.channelId = channelId
      authInfo.userId = userId
      authInfo.token = token
      authInfo.gslbServer = "https://gslb.dingrtc.com"
      _ = engine.setAudioSessionOperationRestriction(.none)
      _ = engine.subscribeAllRemoteAudioStreams(true)
      _ = engine.enableSpeakerphone(false)
      _ = engine.startAudioPlayer()
      _ = engine.startAudioCapture()
      _ = engine.publishLocalAudioStream(true)
      let code = engine.joinChannel(authInfo, name: nil) { [weak self] errorCode, channelName, joinedUserId, _ in
        DispatchQueue.main.async {
          guard let self, self.rtcGeneration == generation else { return }
          if errorCode == 0 {
            delegate.emit?("joined", ["channelId": channelName, "userId": joinedUserId])
          } else {
            delegate.emit?("error", ["code": errorCode])
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
    case "speaker":
      let enabled = (call.arguments as? Bool) ?? false
      result(rtcEngine?.enableSpeakerphone(enabled) == 0)
    case "leave":
      guard let engine = rtcEngine else {
        result(true)
        return
      }
      rtcGeneration += 1
      let oldDelegate = rtcDelegate
      rtcEngine = nil
      rtcDelegate = nil
      leavingEngine = engine
      leavingDelegate = oldDelegate
      _ = engine.publishLocalAudioStream(false)
      _ = engine.stopAudioCapture()
      _ = engine.stopAudioPlayer()
      let code = engine.leaveChannel()
      result(code == 0 ? true : FlutterError(code: "leave_failed", message: "离开 RTC 频道失败", details: code))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

}

private final class CallRtcDelegate: NSObject, DingRtcEngineDelegate {
  var engine: DingRtcEngine?
  var emit: ((String, [String: Any]) -> Void)?

  func destroy() {
    guard let current = engine else { return }
    engine = nil
    _ = current.publishLocalAudioStream(false)
    _ = current.stopAudioCapture()
    _ = current.stopAudioPlayer()
    DingRtcEngine.destroyInstance(current)
  }

  func onNetworkQualityChanged(_ uid: String, up upQuality: DingRtcNetworkQuality, downNetworkQuality downQuality: DingRtcNetworkQuality) {
    DispatchQueue.main.async { [weak self] in
      self?.emit?("networkQuality", ["userId": uid, "up": upQuality.rawValue, "down": downQuality.rawValue])
    }
  }

  func onOccurWarning(_ warn: Int32, message: String) {
    DispatchQueue.main.async { [weak self] in
      self?.emit?("warning", ["code": warn, "message": message])
    }
  }

  func onOccurError(_ error: Int32, message: String) {
    DispatchQueue.main.async { [weak self] in
      self?.emit?("rtcError", ["code": error, "message": message])
    }
  }

  func onFirstAudioPacketSent(withTimecost timeCost: Int32) {
    DispatchQueue.main.async { [weak self] in
      self?.emit?("firstAudioSent", ["timeCost": timeCost])
    }
  }

  func onFirstAudioPacketReceived(withUid uid: String, timeCost: Int32) {
    DispatchQueue.main.async { [weak self] in
      self?.emit?("firstAudioReceived", ["userId": uid, "timeCost": timeCost])
    }
  }

  func onUserAudioMuted(_ uid: String, audioMuted isMute: Bool) {
    DispatchQueue.main.async { [weak self] in
      self?.emit?("remoteMuted", ["userId": uid, "muted": isMute])
    }
  }
  func onBye(_ code: DingRtcOnByeType) {
    DispatchQueue.main.async { [weak self] in
      self?.emit?("bye", ["code": code.rawValue])
    }
  }
  func onRemoteUser(onLineNotify uid: String, elapsed: Int32) {
    DispatchQueue.main.async { [weak self] in
      self?.emit?("remoteJoined", ["userId": uid, "elapsed": elapsed])
    }
  }

  func onAudioPublishStateChanged(_ oldState: DingRtcPublishState, newState: DingRtcPublishState, elapseSinceLastState: Int, channel: String) {
    DispatchQueue.main.async { [weak self] in
      self?.emit?("audioPublishState", ["oldState": oldState.rawValue, "newState": newState.rawValue, "channelId": channel])
    }
  }

  func onAudioSubscribeStateChanged(_ uid: String, oldState: DingRtcSubscribeState, newState: DingRtcSubscribeState, elapseSinceLastState: Int, channel: String) {
    DispatchQueue.main.async { [weak self] in
      self?.emit?("audioSubscribeState", ["userId": uid, "oldState": oldState.rawValue, "newState": newState.rawValue, "channelId": channel])
    }
  }

  func onConnectionStatusChanged(_ status: DingRtcConnectionStatus, reason: DingRtcConnectionStatusChangeReason) {
    DispatchQueue.main.async { [weak self] in
      self?.emit?("connectionStatus", ["status": status.rawValue, "reason": reason.rawValue])
    }
  }
  func onRemoteUserOffLineNotify(_ uid: String, offlineReason reason: DingRtcUserOfflineReason) {
    DispatchQueue.main.async { [weak self] in
      self?.emit?("remoteLeft", ["userId": uid, "reason": reason.rawValue])
    }
  }

  func onRemoteTrackAvailableNotify(_ uid: String, audioTrack: DingRtcAudioTrack, videoTrack: DingRtcVideoTrack) {
    DispatchQueue.main.async { [weak self] in
      self?.emit?("remoteTrack", ["userId": uid, "audio": audioTrack.rawValue])
    }
  }

  func onLeaveChannelResult(_ result: Int32, stats: DingRtcStats) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.emit?("left", ["code": result])
    }
  }
}
