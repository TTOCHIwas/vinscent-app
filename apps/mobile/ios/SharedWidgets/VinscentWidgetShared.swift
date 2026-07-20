import Foundation
import WidgetKit

enum VinscentWidgetConstants {
  static let appGroupId = "group.com.vinscent.vinscent"
  static let characterKind = "VinscentCharacterWidget"
  static let cardKind = "VinscentCardWidget"
  static let recordingActivityKind = "VinscentRecordingActivity"
  static let recordingUploadTaskIdentifier =
    "com.vinscent.vinscent.widget-recording-upload"

  static let characterImagePathKey = "widget_character_image_path"
  static let recordingAudioPathKey = "widget_recording_audio_path"
  static let partnerCardImagePathKey = "widget_partner_card_image_path"
  static let characterPlayingKey = "widget_character_playing"
  static let characterPlayingStartedAtKey = "widget_character_playing_started_at"
  static let microphonePermissionGrantedKey =
    "widget_microphone_permission_granted"
  static let recordingPhaseKey = "widget_recording_phase"
  static let recordingIdKey = "widget_recording_id"
  static let recordingDraftPathKey = "widget_recording_draft_path"
  static let recordingStartedAtKey = "widget_recording_started_at"
  static let recordingDurationKey = "widget_recording_duration"
  static let recordingUploadAttemptKey = "widget_recording_upload_attempt"

  static let maximumRecordingDurationMilliseconds = 15_000
  static let maximumRecordingDuration: TimeInterval = 15
  static let maximumRecordingBytes = 4 * 1024 * 1024
  static let maximumUploadAttempts = 3

  static let cardURL = URL(string: "vinscent://widget/card?homeWidget")!
  static let recordURL = URL(string: "vinscent://widget/record?homeWidget")!
}

enum VinscentWidgetRecordingPhase: String {
  case idle
  case recording
  case uploading
}

struct VinscentWidgetSnapshot {
  let characterImagePath: String?
  let recordingAudioPath: String?
  let partnerCardImagePath: String?
  let isCharacterPlaying: Bool
  let characterPlayingStartedAt: Date?
  let microphonePermissionGranted: Bool
  let recordingPhase: VinscentWidgetRecordingPhase
  let recordingStartedAt: Date?

  static func load() -> VinscentWidgetSnapshot {
    let defaults = VinscentWidgetStateStore.defaults
    let playingStartedAt = date(
      fromMilliseconds: defaults?.double(
        forKey: VinscentWidgetConstants.characterPlayingStartedAtKey
      ) ?? 0
    )
    let isPlaying = defaults?.bool(
      forKey: VinscentWidgetConstants.characterPlayingKey
    ) ?? false
    return VinscentWidgetSnapshot(
      characterImagePath: existingFilePath(
        defaults?.string(forKey: VinscentWidgetConstants.characterImagePathKey)
      ),
      recordingAudioPath: existingFilePath(
        defaults?.string(forKey: VinscentWidgetConstants.recordingAudioPathKey)
      ),
      partnerCardImagePath: existingFilePath(
        defaults?.string(forKey: VinscentWidgetConstants.partnerCardImagePathKey)
      ),
      isCharacterPlaying: isPlaying && isRecentPlayback(playingStartedAt),
      characterPlayingStartedAt: playingStartedAt,
      microphonePermissionGranted: defaults?.bool(
        forKey: VinscentWidgetConstants.microphonePermissionGrantedKey
      ) ?? false,
      recordingPhase: VinscentWidgetRecordingPhase(
        rawValue: defaults?.string(
          forKey: VinscentWidgetConstants.recordingPhaseKey
        ) ?? ""
      ) ?? .idle,
      recordingStartedAt: date(
        fromMilliseconds: defaults?.double(
          forKey: VinscentWidgetConstants.recordingStartedAtKey
        ) ?? 0
      )
    )
  }

  private static func existingFilePath(_ path: String?) -> String? {
    guard let path, !path.isEmpty, FileManager.default.fileExists(atPath: path) else {
      return nil
    }
    return path
  }

  private static func date(fromMilliseconds milliseconds: Double) -> Date? {
    guard milliseconds > 0 else {
      return nil
    }
    return Date(timeIntervalSince1970: milliseconds / 1000)
  }

  private static func isRecentPlayback(_ startedAt: Date?) -> Bool {
    guard let startedAt else {
      return false
    }
    return Date().timeIntervalSince(startedAt) <
      VinscentWidgetConstants.maximumRecordingDuration + 5
  }
}

enum VinscentWidgetStateStore {
  static var defaults: UserDefaults? {
    UserDefaults(suiteName: VinscentWidgetConstants.appGroupId)
  }

  static var recordingPhase: VinscentWidgetRecordingPhase {
    VinscentWidgetRecordingPhase(
      rawValue: defaults?.string(
        forKey: VinscentWidgetConstants.recordingPhaseKey
      ) ?? ""
    ) ?? .idle
  }

  static func markRecording(
    recordingId: String,
    fileURL: URL,
    startedAt: Date
  ) {
    guard let defaults else {
      return
    }
    defaults.set(
      VinscentWidgetRecordingPhase.recording.rawValue,
      forKey: VinscentWidgetConstants.recordingPhaseKey
    )
    defaults.set(recordingId, forKey: VinscentWidgetConstants.recordingIdKey)
    defaults.set(fileURL.path, forKey: VinscentWidgetConstants.recordingDraftPathKey)
    defaults.set(
      startedAt.timeIntervalSince1970 * 1000,
      forKey: VinscentWidgetConstants.recordingStartedAtKey
    )
    defaults.removeObject(forKey: VinscentWidgetConstants.recordingDurationKey)
    defaults.set(0, forKey: VinscentWidgetConstants.recordingUploadAttemptKey)
    reloadCharacterWidget()
  }

  static func markUploading(fileURL: URL, durationMilliseconds: Int) {
    guard let defaults else {
      return
    }
    defaults.set(
      VinscentWidgetRecordingPhase.uploading.rawValue,
      forKey: VinscentWidgetConstants.recordingPhaseKey
    )
    defaults.set(fileURL.path, forKey: VinscentWidgetConstants.recordingDraftPathKey)
    defaults.set(
      durationMilliseconds,
      forKey: VinscentWidgetConstants.recordingDurationKey
    )
    defaults.removeObject(forKey: VinscentWidgetConstants.recordingStartedAtKey)
    reloadCharacterWidget()
  }

  static func markIdle(deleteDraft: Bool) {
    guard let defaults else {
      return
    }
    if deleteDraft,
      let path = defaults.string(forKey: VinscentWidgetConstants.recordingDraftPathKey),
      isOwnedRecordingDraft(URL(fileURLWithPath: path))
    {
      try? FileManager.default.removeItem(atPath: path)
    }
    defaults.set(
      VinscentWidgetRecordingPhase.idle.rawValue,
      forKey: VinscentWidgetConstants.recordingPhaseKey
    )
    defaults.removeObject(forKey: VinscentWidgetConstants.recordingIdKey)
    defaults.removeObject(forKey: VinscentWidgetConstants.recordingDraftPathKey)
    defaults.removeObject(forKey: VinscentWidgetConstants.recordingStartedAtKey)
    defaults.removeObject(forKey: VinscentWidgetConstants.recordingDurationKey)
    defaults.removeObject(forKey: VinscentWidgetConstants.recordingUploadAttemptKey)
    reloadCharacterWidget()
  }

  static func markCharacterPlaying(_ isPlaying: Bool) {
    defaults?.set(isPlaying, forKey: VinscentWidgetConstants.characterPlayingKey)
    if isPlaying {
      defaults?.set(
        Date().timeIntervalSince1970 * 1000,
        forKey: VinscentWidgetConstants.characterPlayingStartedAtKey
      )
    } else {
      defaults?.removeObject(
        forKey: VinscentWidgetConstants.characterPlayingStartedAtKey
      )
    }
    reloadCharacterWidget()
  }

  static func setMicrophonePermissionGranted(_ isGranted: Bool) {
    defaults?.set(
      isGranted,
      forKey: VinscentWidgetConstants.microphonePermissionGrantedKey
    )
    reloadCharacterWidget()
  }

  static func pendingUpload() -> (
    recordingId: String,
    fileURL: URL,
    durationMilliseconds: Int
  )? {
    guard recordingPhase == .uploading,
      let defaults,
      let recordingId = defaults.string(
        forKey: VinscentWidgetConstants.recordingIdKey
      ),
      let path = defaults.string(
        forKey: VinscentWidgetConstants.recordingDraftPathKey
      ),
      isValidRecordingDraft(URL(fileURLWithPath: path))
    else {
      return nil
    }
    let duration = defaults.integer(
      forKey: VinscentWidgetConstants.recordingDurationKey
    )
    guard duration > 0,
      duration <= VinscentWidgetConstants.maximumRecordingDurationMilliseconds
    else {
      return nil
    }
    return (recordingId, URL(fileURLWithPath: path), duration)
  }

  static func interruptedRecording() -> (
    recordingId: String,
    fileURL: URL,
    durationMilliseconds: Int
  )? {
    guard recordingPhase == .recording,
      let defaults,
      let recordingId = defaults.string(
        forKey: VinscentWidgetConstants.recordingIdKey
      ),
      let path = defaults.string(
        forKey: VinscentWidgetConstants.recordingDraftPathKey
      ),
      let startedAt = VinscentWidgetSnapshot.load().recordingStartedAt,
      isValidRecordingDraft(URL(fileURLWithPath: path))
    else {
      return nil
    }
    let elapsed = Int(Date().timeIntervalSince(startedAt) * 1000)
    let duration = min(
      max(elapsed, 1),
      VinscentWidgetConstants.maximumRecordingDurationMilliseconds
    )
    return (recordingId, URL(fileURLWithPath: path), duration)
  }

  static func incrementUploadAttempt() -> Int {
    guard let defaults else {
      return VinscentWidgetConstants.maximumUploadAttempts
    }
    let next = defaults.integer(
      forKey: VinscentWidgetConstants.recordingUploadAttemptKey
    ) + 1
    defaults.set(next, forKey: VinscentWidgetConstants.recordingUploadAttemptKey)
    return next
  }

  static func isOwnedRecordingDraft(_ fileURL: URL) -> Bool {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: VinscentWidgetConstants.appGroupId
    ) else {
      return false
    }
    let root = container
      .appendingPathComponent("widget_recordings", isDirectory: true)
      .standardizedFileURL.path
    let path = fileURL.standardizedFileURL.path
    return path.hasPrefix(root + "/")
  }

  private static func isValidRecordingDraft(_ fileURL: URL) -> Bool {
    guard isOwnedRecordingDraft(fileURL),
      let values = try? fileURL.resourceValues(
        forKeys: [.isRegularFileKey, .fileSizeKey]
      ),
      values.isRegularFile == true,
      let size = values.fileSize
    else {
      return false
    }
    return size > 0 && size <= VinscentWidgetConstants.maximumRecordingBytes
  }

  static func reloadCharacterWidget() {
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadTimelines(
        ofKind: VinscentWidgetConstants.characterKind
      )
    }
  }
}
