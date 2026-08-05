import Flutter
import UIKit

/// Мост в Dart: собрана ли программа из TestFlight (у sandbox-чека
/// App Store имя sandboxReceipt). Нужно рекламе: TestFlight — это
/// release-конфигурация, kDebugMode там false, но крутить боевые
/// блоки в тестовой сборке нельзя — там включаются тестовые.
private class EnvChannel: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "synapse/env", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      if call.method == "isTestFlight" {
        let receipt = Bundle.main.appStoreReceiptURL?.lastPathComponent
        result(receipt == "sandboxReceipt")
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "EnvChannel") {
      EnvChannel.register(with: registrar)
    }
  }
}
