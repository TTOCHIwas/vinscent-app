import AppIntents
import Foundation

enum VinscentWidgetIntentError: LocalizedError {
  case appProcessRequired

  var errorDescription: String? {
    "위젯 동작을 실행하려면 단짠 앱 프로세스가 필요해요"
  }
}

@available(iOS 18.0, *)
struct ToggleVinscentWidgetRecordingIntent: AudioRecordingIntent {
  static var title: LocalizedStringResource = "위젯 녹음 시작 또는 종료"
  static var description = IntentDescription(
    "15초 녹음을 시작하거나 종료해요"
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
  static var title: LocalizedStringResource = "위젯 녹음 재생 또는 정지"
  static var description = IntentDescription(
    "현재 녹음을 재생하거나 멈춰요"
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
