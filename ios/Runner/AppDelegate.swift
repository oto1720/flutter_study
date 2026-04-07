import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // MethodChannel の登録は GeneratedPluginRegistrant より前に行う
    let controller = window?.rootViewController as! FlutterViewController
    let deviceChannel = FlutterMethodChannel(
      name: "com.example.flutter_study/device",
      binaryMessenger: controller.binaryMessenger
    )
    deviceChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getDeviceModel":
        // UIDevice.current.model は "iPhone" / "iPad" を返す
        // より詳細なモデル名（例: iPhone16,1）は sysctlbyname で取得可能
        result(UIDevice.current.model)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
