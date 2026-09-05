import Flutter
import UIKit

enum VinscentDeviceCalendarBridgeRegistration {
  static func register(
    with registrar: FlutterPluginRegistrar?,
    registerBridge: (FlutterPluginRegistrar) -> Void = { registrar in
      VinscentDeviceCalendarBridge.register(with: registrar)
    }
  ) {
    guard let registrar else {
      return
    }
    registerBridge(registrar)
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    VinscentWidgetBackgroundTask.register()
    VinscentWidgetMicrophonePermission.synchronize()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    VinscentWidgetMicrophonePermission.synchronize()
    if #available(iOS 18.0, *) {
      Task { @MainActor in
        _ = await VinscentWidgetAudioController.shared.resumePendingUpload()
      }
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    VinscentDeviceCalendarBridgeRegistration.register(
      with: engineBridge.pluginRegistry.registrar(
        forPlugin: "VinscentDeviceCalendarBridge"
      )
    )
  }
}
