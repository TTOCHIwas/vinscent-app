import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    VinscentWidgetMicrophonePermission.synchronize()
    if #available(iOS 18.0, *) {
      Task { @MainActor in
        _ = await VinscentWidgetAudioController.shared.resumePendingUpload()
      }
    }
  }

}
