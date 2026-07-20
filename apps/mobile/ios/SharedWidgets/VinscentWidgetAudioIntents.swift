import AppIntents
import Foundation

enum VinscentWidgetIntentError: LocalizedError {
  case appProcessRequired

  var errorDescription: String? {
    "The widget action must run in the containing app process."
  }
}

@available(iOS 18.0, *)
struct ToggleVinscentWidgetRecordingIntent: AudioRecordingIntent {
  static var title: LocalizedStringResource = "Toggle widget recording"
  static var description = IntentDescription(
    "Starts or stops the 15-second couple recording."
  )
  static var openAppWhenRun = false

  init() {}

  func perform() async throws -> some IntentResult {
    #if WIDGET_EXTENSION
      throw VinscentWidgetIntentError.appProcessRequired
    #else
      try await VinscentWidgetAudioController.shared.toggleRecording()
      return .result()
    #endif
  }
}

@available(iOS 18.0, *)
struct ToggleVinscentWidgetPlaybackIntent: AudioPlaybackIntent {
  static var title: LocalizedStringResource = "Toggle widget playback"
  static var description = IntentDescription(
    "Plays or stops the current couple recording."
  )
  static var openAppWhenRun = false

  init() {}

  func perform() async throws -> some IntentResult {
    #if WIDGET_EXTENSION
      throw VinscentWidgetIntentError.appProcessRequired
    #else
      try await VinscentWidgetAudioController.shared.togglePlayback()
      return .result()
    #endif
  }
}
