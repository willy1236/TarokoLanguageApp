import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 活動地圖選點的 Google Maps SDK 金鑰（Info.plist 的 GMSApiKey，限制為本 App bundle id）。
    // 要跟 lib/core/constants/maps_config.dart 的 iOS 金鑰一起填，空著時不顯示地圖選點。
    if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String, !key.isEmpty {
      GMSServices.provideAPIKey(key)
    }
    GeneratedPluginRegistrant.register(with: self)
    // 後台影片背景上傳從斷點續傳時，系統會先複製剩下的部分；排之前查剩餘空間（lib/services/video_upload/background_upload_io.dart）。
    if let registrar = registrar(forPlugin: "TrukuStorage") {
      FlutterMethodChannel(name: "truku/storage", binaryMessenger: registrar.messenger())
        .setMethodCallHandler { call, result in
          guard call.method == "freeBytes" else {
            result(FlutterMethodNotImplemented)
            return
          }
          let values = try? FileManager.default.temporaryDirectory
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
          if let bytes = values?.volumeAvailableCapacityForImportantUsage {
            result(NSNumber(value: bytes))
          } else {
            result(nil)
          }
        }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
