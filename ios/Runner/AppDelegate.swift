import UIKit
import Flutter
import DingRTC
import UserNotifications
import MapKit
import CoreLocation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, DingRtcEngineDelegate {
  private var rtcEngine: DingRtcEngine?
  private var leavingEngine: DingRtcEngine?
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
    let channel = FlutterMethodChannel(name: "com.outmcn.friend/location_picker", binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "pickLocation" else {
        result(FlutterMethodNotImplemented)
        return
      }
      DispatchQueue.main.async {
        let picker = NativeLocationPickerViewController()
        picker.onComplete = { payload in
          result(payload)
        }
        picker.onCancel = { result(nil) }
        let navigation = UINavigationController(rootViewController: picker)
        controller.present(navigation, animated: true)
      }
    }

    let rtcChannel = FlutterMethodChannel(name: "com.outmcn.dd/aliyun_rtc", binaryMessenger: controller.binaryMessenger)
    self.rtcChannel = rtcChannel
    rtcChannel.setMethodCallHandler { [weak self] call, result in
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
      let engine = DingRtcEngine.createInstance(self, extras: nil)
      rtcEngine = engine
      let authInfo = DingRtcAuthInfo()
      authInfo.appId = appId
      authInfo.channelId = channelId
      authInfo.userId = userId
      authInfo.token = token
      authInfo.gslbServer = "https://gslb.dingrtc.com"
      _ = engine.setAudioSessionOperationRestriction(.none)
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
    case "speaker":
      let enabled = (call.arguments as? Bool) ?? false
      result(rtcEngine?.enableSpeakerphone(enabled) == 0)
    case "leave":
      guard let engine = rtcEngine else {
        result(true)
        return
      }
      leavingEngine = engine
      rtcEngine = nil
      _ = engine.publishLocalAudioStream(false)
      _ = engine.stopAudioCapture()
      _ = engine.stopAudioPlayer()
      let code = engine.leaveChannel()
      result(code == 0 ? true : FlutterError(code: "leave_failed", message: "离开 RTC 频道失败", details: code))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onNetworkQualityChanged(_ uid: String, up upQuality: DingRtcNetworkQuality, downNetworkQuality downQuality: DingRtcNetworkQuality) {
    DispatchQueue.main.async { [weak self] in
      self?.rtcChannel?.invokeMethod("networkQuality", arguments: ["userId": uid, "up": upQuality.rawValue, "down": downQuality.rawValue])
    }
  }

  func onOccurWarning(_ warn: Int32, message: String) {
    DispatchQueue.main.async { [weak self] in
      self?.rtcChannel?.invokeMethod("warning", arguments: ["code": warn, "message": message])
    }
  }

  func onOccurError(_ error: Int32, message: String) {
    DispatchQueue.main.async { [weak self] in
      self?.rtcChannel?.invokeMethod("rtcError", arguments: ["code": error, "message": message])
    }
  }

  func onFirstAudioPacketSent(withTimecost timeCost: Int32) {
    DispatchQueue.main.async { [weak self] in
      self?.rtcChannel?.invokeMethod("firstAudioSent", arguments: ["timeCost": timeCost])
    }
  }

  func onFirstAudioPacketReceived(withUid uid: String, timeCost: Int32) {
    DispatchQueue.main.async { [weak self] in
      self?.rtcChannel?.invokeMethod("firstAudioReceived", arguments: ["userId": uid, "timeCost": timeCost])
    }
  }

  func onUserAudioMuted(_ uid: String, audioMuted isMute: Bool) {
    DispatchQueue.main.async { [weak self] in
      self?.rtcChannel?.invokeMethod("remoteMuted", arguments: ["userId": uid, "muted": isMute])
    }
  }
  func onBye(_ code: DingRtcOnByeType) {
    let engine = rtcEngine ?? leavingEngine
    rtcEngine = nil
    leavingEngine = nil
    if let engine {
      _ = engine.publishLocalAudioStream(false)
      _ = engine.stopAudioCapture()
      _ = engine.stopAudioPlayer()
      DingRtcEngine.destroyInstance(engine)
    }
    DispatchQueue.main.async { [weak self] in
      self?.rtcChannel?.invokeMethod("bye", arguments: ["code": code.rawValue])
    }
  }
  func onRemoteUser(onLineNotify uid: String, elapsed: Int32) {
    DispatchQueue.main.async { [weak self] in
      self?.rtcChannel?.invokeMethod("remoteJoined", arguments: ["userId": uid, "elapsed": elapsed])
    }
  }

  func onAudioPublishStateChanged(_ oldState: DingRtcPublishState, newState: DingRtcPublishState, elapseSinceLastState: Int, channel: String) {
    DispatchQueue.main.async { [weak self] in
      self?.rtcChannel?.invokeMethod("audioPublishState", arguments: ["oldState": oldState.rawValue, "newState": newState.rawValue, "channelId": channel])
    }
  }

  func onAudioSubscribeStateChanged(_ uid: String, oldState: DingRtcSubscribeState, newState: DingRtcSubscribeState, elapseSinceLastState: Int, channel: String) {
    DispatchQueue.main.async { [weak self] in
      self?.rtcChannel?.invokeMethod("audioSubscribeState", arguments: ["userId": uid, "oldState": oldState.rawValue, "newState": newState.rawValue, "channelId": channel])
    }
  }

  func onConnectionStatusChanged(_ status: DingRtcConnectionStatus, reason: DingRtcConnectionStatusChangeReason) {
    DispatchQueue.main.async { [weak self] in
      self?.rtcChannel?.invokeMethod("connectionStatus", arguments: ["status": status.rawValue, "reason": reason.rawValue])
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
    let engine = leavingEngine ?? rtcEngine
    rtcEngine = nil
    leavingEngine = nil
    if let engine {
      DingRtcEngine.destroyInstance(engine)
    }
    DispatchQueue.main.async { [weak self] in
      self?.rtcChannel?.invokeMethod("left", arguments: ["code": result])
    }
  }
}

private final class NativeLocationPickerViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
  var onComplete: (([String: Any]) -> Void)?
  var onCancel: (() -> Void)?
  private let mapView = MKMapView()
  private let locationManager = CLLocationManager()
  private let pin = UIImageView(image: UIImage(systemName: "mappin.and.ellipse"))
  private let currentLocationButton = UIButton(type: .system)
  private var bestLocation: CLLocation?
  private var locationDeadline: DispatchWorkItem?

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    mapView.frame = view.bounds
    mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    mapView.delegate = self
    mapView.showsUserLocation = true
    view.addSubview(mapView)
    currentLocationButton.setImage(UIImage(systemName: "location.fill"), for: .normal)
    currentLocationButton.tintColor = .systemBlue
    currentLocationButton.backgroundColor = .systemBackground
    currentLocationButton.layer.cornerRadius = 22
    currentLocationButton.layer.shadowColor = UIColor.black.cgColor
    currentLocationButton.layer.shadowOpacity = 0.15
    currentLocationButton.layer.shadowRadius = 4
    currentLocationButton.layer.shadowOffset = CGSize(width: 0, height: 2)
    currentLocationButton.translatesAutoresizingMaskIntoConstraints = false
    currentLocationButton.addTarget(self, action: #selector(returnToCurrentLocation), for: .touchUpInside)
    view.addSubview(currentLocationButton)
    NSLayoutConstraint.activate([
      currentLocationButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      currentLocationButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -150),
      currentLocationButton.widthAnchor.constraint(equalToConstant: 44),
      currentLocationButton.heightAnchor.constraint(equalToConstant: 44)
    ])
        pin.tintColor = .systemRed
    pin.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(pin)
    NSLayoutConstraint.activate([
      pin.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      pin.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
      pin.widthAnchor.constraint(equalToConstant: 38),
      pin.heightAnchor.constraint(equalToConstant: 44)
    ])
    let cancel = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelPressed))
    let done = UIBarButtonItem(title: "发送此位置", style: .done, target: self, action: #selector(donePressed))
    navigationItem.leftBarButtonItem = cancel
    navigationItem.rightBarButtonItem = done
    title = "选择位置"
    navigationController?.navigationBar.topItem?.title = "选择位置"
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.distanceFilter = kCLDistanceFilterNone
    locationManager.requestWhenInUseAuthorization()
    locationManager.startUpdatingLocation()
    let deadline = DispatchWorkItem { [weak self] in
      self?.finishInitialLocation()
    }
    locationDeadline = deadline
    DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: deadline)
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    for location in locations where location.horizontalAccuracy >= 0 {
      if bestLocation == nil || location.horizontalAccuracy < bestLocation!.horizontalAccuracy {
        bestLocation = location
      }
      if location.horizontalAccuracy <= 30 {
        finishInitialLocation()
        break
      }
    }
  }

  private func finishInitialLocation() {
    locationDeadline?.cancel()
    locationManager.stopUpdatingLocation()
    guard let location = bestLocation else { return }
    let region = MKCoordinateRegion(
      center: location.coordinate,
      latitudinalMeters: 250,
      longitudinalMeters: 250
    )
    mapView.setRegion(region, animated: true)
  }

  func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    // 地址在点击发送时统一反向解析，避免拖动过程中保存过期地址。
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    locationDeadline?.cancel()
    locationManager.stopUpdatingLocation()
  }

  @objc private func returnToCurrentLocation() {
    guard let location = bestLocation else {
      locationManager.startUpdatingLocation()
      return
    }
    mapView.setRegion(
      MKCoordinateRegion(
        center: location.coordinate,
        latitudinalMeters: 250,
        longitudinalMeters: 250
      ),
      animated: true
    )
  }

  @objc private func cancelPressed() {
    onCancel?()
    dismiss(animated: true)
  }

  @objc private func donePressed() {
    let location = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
    let geocoder = CLGeocoder()
    geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
      guard let self else { return }
      let place = placemarks?.first
      let address = [place?.administrativeArea, place?.locality, place?.subLocality, place?.thoroughfare, place?.subThoroughfare]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
      self.onComplete?([
        "latitude": location.coordinate.latitude,
        "longitude": location.coordinate.longitude,
        "title": place?.name ?? "选择的位置",
        "address": address.isEmpty ? "地址暂不可用" : address
      ])
      self.dismiss(animated: true)
    }
  }
}
