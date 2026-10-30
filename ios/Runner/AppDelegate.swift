import UIKit
import Flutter
import UserNotifications
import MapKit
import CoreLocation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

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
    let locationFactory = NativeMapViewFactory(messenger: controller.binaryMessenger)
    self.registrar(forPlugin: "NativeMapView")?.register(locationFactory, withId: "com.outmcn.friend/native_map_view")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if let type = userInfo["type"] as? String, type == "call:incoming" {
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
    completionHandler()
  }



private final class NativeMapViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger; super.init() }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    NativeMapView(frame: frame, viewId: viewId, messenger: messenger)
  }
}

private final class NativeMapView: NSObject, FlutterPlatformView, MKMapViewDelegate, CLLocationManagerDelegate {
  private let mapView: MKMapView
  private let locationManager = CLLocationManager()
  private let channel: FlutterMethodChannel
  private var bestLocation: CLLocation?
  private var deadline: DispatchWorkItem?

  init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger) {
    mapView = MKMapView(frame: frame)
    channel = FlutterMethodChannel(name: "com.outmcn.friend/location_picker_\(viewId)", binaryMessenger: messenger)
    super.init()
    mapView.delegate = self
    mapView.showsUserLocation = true
    mapView.mapType = .standard
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "returnToCurrentLocation": self.returnToCurrentLocation(); result(nil)
      case "sendSelectedLocation": self.sendSelectedLocation(result)
      default: result(FlutterMethodNotImplemented)
      }
    }
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.distanceFilter = kCLDistanceFilterNone
    locationManager.requestWhenInUseAuthorization()
    locationManager.startUpdatingLocation()
    let item = DispatchWorkItem { [weak self] in self?.finishLocation() }
    deadline = item
    DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: item)
  }

  func view() -> UIView { mapView }
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    for location in locations where location.horizontalAccuracy >= 0 {
      if bestLocation == nil || location.horizontalAccuracy < bestLocation!.horizontalAccuracy { bestLocation = location }
      if location.horizontalAccuracy <= 30 { finishLocation(); break }
    }
  }
  private func finishLocation() {
    deadline?.cancel(); locationManager.stopUpdatingLocation()
    guard let location = bestLocation else { return }
    mapView.setRegion(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 250, longitudinalMeters: 250), animated: true)
    notifyLocation(location)
  }
  private func returnToCurrentLocation() {
    guard let location = bestLocation else { locationManager.startUpdatingLocation(); return }
    mapView.setRegion(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 250, longitudinalMeters: 250), animated: true)
    notifyLocation(location)
  }
  private func notifyLocation(_ location: CLLocation) {
    CLGeocoder().reverseGeocodeLocation(location) { [weak self] places, _ in
      guard let self else { return }
      let place = places?.first
      let address = [place?.administrativeArea, place?.locality, place?.subLocality, place?.thoroughfare, place?.subThoroughfare].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: " ")
      self.channel.invokeMethod("locationChanged", arguments: ["latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude, "title": place?.name ?? "当前位置", "address": address.isEmpty ? "地址暂不可用" : address])
    }
  }
  private func sendSelectedLocation(_ result: @escaping FlutterResult) {
    let location = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
    CLGeocoder().reverseGeocodeLocation(location) { places, _ in
      let place = places?.first
      let address = [place?.administrativeArea, place?.locality, place?.subLocality, place?.thoroughfare, place?.subThoroughfare].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: " ")
      result(["latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude, "title": place?.name ?? "选择的位置", "address": address.isEmpty ? "地址暂不可用" : address])
    }
  }
  func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    notifyLocation(CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude))
  }
}
