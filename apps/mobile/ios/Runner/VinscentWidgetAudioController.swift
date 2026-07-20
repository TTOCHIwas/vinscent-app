import ActivityKit
import AVFoundation
import Foundation
import UIKit

enum VinscentWidgetMicrophonePermission {
  static var isGranted: Bool {
    if #available(iOS 17.0, *) {
      return AVAudioApplication.shared.recordPermission == .granted
    }
    return AVAudioSession.sharedInstance().recordPermission == .granted
  }

  static func synchronize() {
    VinscentWidgetStateStore.setMicrophonePermissionGranted(isGranted)
  }
}

private enum VinscentWidgetAudioError: Error {
  case microphonePermissionRequired
  case liveActivitiesDisabled
  case recordingDirectoryUnavailable
  case recordingStartFailed
  case playbackStartFailed
}

@available(iOS 18.0, *)
@MainActor
final class VinscentWidgetAudioController: NSObject {
  static let shared = VinscentWidgetAudioController()

  private var recorder: AVAudioRecorder?
  private var player: AVAudioPlayer?
  private var recordingId: String?
  private var recordingFileURL: URL?
  private var recordingStartedAt: Date?
  private var recordingDeadlineTask: Task<Void, Never>?
  private var recordingActivity: Activity<VinscentRecordingAttributes>?
  private var isUploading = false
  private var backgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid

  func toggleRecording() async throws {
    switch VinscentWidgetStateStore.recordingPhase {
    case .uploading:
      return
    case .recording:
      guard recorder?.isRecording == true else {
        await normalizeInterruptedRecording()
        Task { @MainActor in
          _ = await self.resumePendingUpload()
        }
        return
      }
      await finishRecording()
    case .idle:
      try await startRecording()
    }
  }

  func togglePlayback() async throws {
    if player?.isPlaying == true {
      stopPlayback()
      return
    }
    guard VinscentWidgetStateStore.recordingPhase == .idle,
      let path = VinscentWidgetSnapshot.load().recordingAudioPath
    else {
      return
    }

    let session = AVAudioSession.sharedInstance()
    try session.setCategory(
      .playback,
      mode: .spokenAudio,
      options: [.duckOthers]
    )
    try session.setActive(true)
    let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
    player.delegate = self
    player.prepareToPlay()
    guard player.play() else {
      try? session.setActive(false, options: .notifyOthersOnDeactivation)
      throw VinscentWidgetAudioError.playbackStartFailed
    }
    self.player = player
    VinscentWidgetStateStore.markCharacterPlaying(true)
  }

  func resumePendingUpload() async -> Bool {
    if VinscentWidgetStateStore.recordingPhase == .recording {
      await normalizeInterruptedRecording()
    }
    guard let pending = VinscentWidgetStateStore.pendingUpload() else {
      if VinscentWidgetStateStore.recordingPhase == .uploading {
        VinscentWidgetStateStore.markIdle(deleteDraft: true)
      }
      return true
    }
    guard !isUploading else {
      return false
    }

    let attempt = VinscentWidgetStateStore.incrementUploadAttempt()
    guard attempt <= VinscentWidgetConstants.maximumUploadAttempts else {
      VinscentWidgetStateStore.markIdle(deleteDraft: true)
      return true
    }

    isUploading = true
    beginBackgroundTime()
    let outcome = await VinscentWidgetRecordingUploadBridge().upload(
      recordingId: pending.recordingId,
      fileURL: pending.fileURL,
      durationMilliseconds: pending.durationMilliseconds
    )
    isUploading = false
    endBackgroundTime()

    if outcome.success {
      VinscentWidgetStateStore.markIdle(deleteDraft: true)
      return true
    }
    if outcome.retryable &&
      attempt < VinscentWidgetConstants.maximumUploadAttempts
    {
      VinscentWidgetBackgroundTask.schedule()
      return false
    }
    VinscentWidgetStateStore.markIdle(deleteDraft: true)
    return true
  }

  private func startRecording() async throws {
    VinscentWidgetMicrophonePermission.synchronize()
    guard VinscentWidgetMicrophonePermission.isGranted else {
      throw VinscentWidgetAudioError.microphonePermissionRequired
    }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      throw VinscentWidgetAudioError.liveActivitiesDisabled
    }

    stopPlayback()
    await endRecordingActivities()
    let id = UUID().uuidString
    let fileURL = try makeRecordingFileURL(recordingId: id)
    let startedAt = Date()
    let endDate = startedAt.addingTimeInterval(
      VinscentWidgetConstants.maximumRecordingDuration
    )

    let session = AVAudioSession.sharedInstance()
    var activity: Activity<VinscentRecordingAttributes>?
    do {
      try session.setCategory(
        .record,
        mode: .spokenAudio,
        options: [.duckOthers]
      )
      try session.setActive(true)

      let recorder = try AVAudioRecorder(
        url: fileURL,
        settings: [
          AVFormatIDKey: kAudioFormatMPEG4AAC,
          AVSampleRateKey: 44_100,
          AVNumberOfChannelsKey: 1,
          AVEncoderBitRateKey: 96_000,
          AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
      )
      recorder.delegate = self
      recorder.prepareToRecord()

      let attributes = VinscentRecordingAttributes(recordingId: id)
      let content = ActivityContent(
        state: VinscentRecordingAttributes.ContentState(endDate: endDate),
        staleDate: endDate
      )
      activity = try Activity.request(
        attributes: attributes,
        content: content,
        pushType: nil
      )

      guard recorder.record(
        forDuration: VinscentWidgetConstants.maximumRecordingDuration
      ) else {
        throw VinscentWidgetAudioError.recordingStartFailed
      }

      self.recorder = recorder
      recordingId = id
      recordingFileURL = fileURL
      recordingStartedAt = startedAt
      recordingActivity = activity
      VinscentWidgetStateStore.markRecording(
        recordingId: id,
        fileURL: fileURL,
        startedAt: startedAt
      )
      scheduleRecordingDeadline()
    } catch {
      if let activity {
        let finalContent = ActivityContent(
          state: VinscentRecordingAttributes.ContentState(endDate: Date()),
          staleDate: Date()
        )
        await activity.end(finalContent, dismissalPolicy: .immediate)
      }
      try? session.setActive(false, options: .notifyOthersOnDeactivation)
      try? FileManager.default.removeItem(at: fileURL)
      throw error
    }
  }

  private func finishRecording() async {
    guard let recorder,
      recordingId != nil,
      let recordingFileURL,
      let recordingStartedAt
    else {
      return
    }

    self.recorder = nil
    self.recordingId = nil
    self.recordingFileURL = nil
    self.recordingStartedAt = nil
    recordingDeadlineTask?.cancel()
    recordingDeadlineTask = nil
    recorder.stop()

    let elapsed = Int(Date().timeIntervalSince(recordingStartedAt) * 1000)
    let duration = min(
      max(elapsed, 1),
      VinscentWidgetConstants.maximumRecordingDurationMilliseconds
    )
    await endRecordingActivities()
    try? AVAudioSession.sharedInstance().setActive(
      false,
      options: .notifyOthersOnDeactivation
    )

    guard isValidRecording(fileURL: recordingFileURL) else {
      VinscentWidgetStateStore.markIdle(deleteDraft: true)
      return
    }
    VinscentWidgetStateStore.markUploading(
      fileURL: recordingFileURL,
      durationMilliseconds: duration
    )
    VinscentWidgetBackgroundTask.schedule()
    _ = await resumePendingUpload()
  }

  private func normalizeInterruptedRecording() async {
    await endRecordingActivities()
    try? AVAudioSession.sharedInstance().setActive(
      false,
      options: .notifyOthersOnDeactivation
    )
    guard let interrupted = VinscentWidgetStateStore.interruptedRecording()
    else {
      VinscentWidgetStateStore.markIdle(deleteDraft: true)
      return
    }
    VinscentWidgetStateStore.markUploading(
      fileURL: interrupted.fileURL,
      durationMilliseconds: interrupted.durationMilliseconds
    )
    VinscentWidgetBackgroundTask.schedule()
  }

  private func scheduleRecordingDeadline() {
    recordingDeadlineTask?.cancel()
    recordingDeadlineTask = Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: 15_250_000_000)
      guard !Task.isCancelled else {
        return
      }
      await self?.finishRecording()
    }
  }

  private func makeRecordingFileURL(recordingId: String) throws -> URL {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: VinscentWidgetConstants.appGroupId
    ) else {
      throw VinscentWidgetAudioError.recordingDirectoryUnavailable
    }
    let directory = container.appendingPathComponent(
      "widget_recordings",
      isDirectory: true
    )
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    return directory.appendingPathComponent("\(recordingId).m4a")
  }

  private func isValidRecording(fileURL: URL) -> Bool {
    guard VinscentWidgetStateStore.isOwnedRecordingDraft(fileURL),
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

  private func stopPlayback() {
    guard player != nil || VinscentWidgetSnapshot.load().isCharacterPlaying
    else {
      return
    }
    player?.stop()
    player = nil
    VinscentWidgetStateStore.markCharacterPlaying(false)
    try? AVAudioSession.sharedInstance().setActive(
      false,
      options: .notifyOthersOnDeactivation
    )
  }

  private func endRecordingActivities() async {
    let finalContent = ActivityContent(
      state: VinscentRecordingAttributes.ContentState(endDate: Date()),
      staleDate: Date()
    )
    if let recordingActivity {
      await recordingActivity.end(finalContent, dismissalPolicy: .immediate)
      self.recordingActivity = nil
    }
    for activity in Activity<VinscentRecordingAttributes>.activities {
      await activity.end(finalContent, dismissalPolicy: .immediate)
    }
  }

  private func beginBackgroundTime() {
    guard backgroundTaskIdentifier == .invalid else {
      return
    }
    backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(
      withName: "Vinscent widget recording upload"
    ) { [weak self] in
      Task { @MainActor in
        self?.endBackgroundTime()
      }
    }
  }

  private func endBackgroundTime() {
    guard backgroundTaskIdentifier != .invalid else {
      return
    }
    UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
    backgroundTaskIdentifier = .invalid
  }
}

@available(iOS 18.0, *)
extension VinscentWidgetAudioController: AVAudioRecorderDelegate {
  nonisolated func audioRecorderDidFinishRecording(
    _ recorder: AVAudioRecorder,
    successfully flag: Bool
  ) {
    Task { @MainActor [weak self] in
      guard let self, self.recorder === recorder else {
        return
      }
      if flag {
        await self.finishRecording()
      } else {
        self.recorder = nil
        self.recordingId = nil
        self.recordingFileURL = nil
        self.recordingStartedAt = nil
        self.recordingDeadlineTask?.cancel()
        self.recordingDeadlineTask = nil
        await self.endRecordingActivities()
        try? AVAudioSession.sharedInstance().setActive(
          false,
          options: .notifyOthersOnDeactivation
        )
        VinscentWidgetStateStore.markIdle(deleteDraft: true)
      }
    }
  }
}

@available(iOS 18.0, *)
extension VinscentWidgetAudioController: AVAudioPlayerDelegate {
  nonisolated func audioPlayerDidFinishPlaying(
    _ player: AVAudioPlayer,
    successfully flag: Bool
  ) {
    Task { @MainActor [weak self] in
      guard let self, self.player === player else {
        return
      }
      self.stopPlayback()
    }
  }
}
