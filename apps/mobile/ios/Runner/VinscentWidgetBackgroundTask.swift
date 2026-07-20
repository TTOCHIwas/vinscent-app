import BackgroundTasks
import Foundation

enum VinscentWidgetBackgroundTask {
  private static var isRegistered = false

  static func register() {
    guard !isRegistered else {
      return
    }
    isRegistered = BGTaskScheduler.shared.register(
      forTaskWithIdentifier:
        VinscentWidgetConstants.recordingUploadTaskIdentifier,
      using: nil
    ) { task in
      guard let processingTask = task as? BGProcessingTask else {
        task.setTaskCompleted(success: false)
        return
      }
      handle(processingTask)
    }
  }

  static func schedule() {
    let request = BGProcessingTaskRequest(
      identifier: VinscentWidgetConstants.recordingUploadTaskIdentifier
    )
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = false
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15)
    try? BGTaskScheduler.shared.submit(request)
  }

  private static func handle(_ task: BGProcessingTask) {
    guard #available(iOS 18.0, *) else {
      task.setTaskCompleted(success: false)
      return
    }
    let operation = Task { @MainActor in
      let completed = await VinscentWidgetAudioController.shared
        .resumePendingUpload()
      task.setTaskCompleted(success: completed && !Task.isCancelled)
    }
    task.expirationHandler = {
      operation.cancel()
    }
  }
}
