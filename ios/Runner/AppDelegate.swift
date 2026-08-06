import AppTrackingTransparency
import Flutter
import UIKit

/// Мост в Dart, два вызова:
/// - isTestFlight: собрана ли программа из TestFlight (у sandbox-чека
///   App Store имя sandboxReceipt). TestFlight — release-конфигурация,
///   kDebugMode там false, но крутить боевые блоки нельзя — включаются
///   тестовые.
/// - requestTracking: системный ATT-алерт. Вызывается из Ads.init()
///   ДО инициализации рекламного SDK — Apple требует показывать запрос
///   до начала отслеживания (Guideline 5.1.2).
private class EnvChannel: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "synapse/env", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isTestFlight":
        let receipt = Bundle.main.appStoreReceiptURL?.lastPathComponent
        result(receipt == "sandboxReceipt")
      case "requestTracking":
        // Повторный вызов при уже данном ответе безвреден: система
        // возвращает сохранённый статус без показа алерта.
        ATTrackingManager.requestTrackingAuthorization { status in
          DispatchQueue.main.async { result(Int(status.rawValue)) }
        }
      default:
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
