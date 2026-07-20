import Flutter
import Foundation

struct VinscentWidgetRecordingUploadOutcome {
  let success: Bool
  let retryable: Bool
}

private enum VinscentWidgetRecordingBridgeError: Error {
  case engineStartFailed
  case readyTimeout
  case uploadTimeout
}

@available(iOS 18.0, *)
@MainActor
final class VinscentWidgetRecordingUploadBridge {
  private static let channelName =
    "com.vinscent.vinscent/widget_recording_upload"
  private static let dartEntrypoint = "widgetRecordingUploadMain"
  private static let readyTimeout: TimeInterval = 30
  private static let uploadTimeout: TimeInterval = 90

  private var engine: FlutterEngine?
  private var channel: FlutterMethodChannel?
  private var isReady = false
  private var readyContinuation: CheckedContinuation<Void, Error>?
  private var uploadContinuation:
    CheckedContinuation<VinscentWidgetRecordingUploadOutcome, Error>?

  func upload(
    recordingId: String,
    fileURL: URL,
    durationMilliseconds: Int
  ) async -> VinscentWidgetRecordingUploadOutcome {
    do {
      return try await performUpload(
        recordingId: recordingId,
        fileURL: fileURL,
        durationMilliseconds: durationMilliseconds
      )
    } catch {
      return VinscentWidgetRecordingUploadOutcome(
        success: false,
        retryable: true
      )
    }
  }

  private func performUpload(
    recordingId: String,
    fileURL: URL,
    durationMilliseconds: Int
  ) async throws -> VinscentWidgetRecordingUploadOutcome {
    let engine = FlutterEngine(
      name: "vinscent_widget_recording_upload",
      project: nil,
      allowHeadlessExecution: true
    )
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: engine.binaryMessenger
    )
    self.engine = engine
    self.channel = channel
    configureReadyHandler(channel)

    guard engine.run(withEntrypoint: Self.dartEntrypoint) else {
      cleanup()
      throw VinscentWidgetRecordingBridgeError.engineStartFailed
    }
    GeneratedPluginRegistrant.register(with: engine)

    defer {
      cleanup()
    }
    try await waitUntilReady()
    return try await invokeUpload(
      recordingId: recordingId,
      fileURL: fileURL,
      durationMilliseconds: durationMilliseconds
    )
  }

  private func configureReadyHandler(_ channel: FlutterMethodChannel) {
    channel.setMethodCallHandler { [weak self] call, result in
      Task { @MainActor in
        guard let self else {
          result(nil)
          return
        }
        guard call.method == "ready" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self.isReady = true
        self.readyContinuation?.resume()
        self.readyContinuation = nil
        result(nil)
      }
    }
  }

  private func waitUntilReady() async throws {
    if isReady {
      return
    }
    try await withCheckedThrowingContinuation { continuation in
      readyContinuation = continuation
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.readyTimeout) {
        Task { @MainActor [weak self] in
          guard let self, let continuation = self.readyContinuation else {
            return
          }
          self.readyContinuation = nil
          continuation.resume(
            throwing: VinscentWidgetRecordingBridgeError.readyTimeout
          )
        }
      }
    }
  }

  private func invokeUpload(
    recordingId: String,
    fileURL: URL,
    durationMilliseconds: Int
  ) async throws -> VinscentWidgetRecordingUploadOutcome {
    guard let channel else {
      throw VinscentWidgetRecordingBridgeError.engineStartFailed
    }
    return try await withCheckedThrowingContinuation { continuation in
      uploadContinuation = continuation
      channel.invokeMethod(
        "upload",
        arguments: [
          "recordingId": recordingId,
          "filePath": fileURL.path,
          "durationMs": durationMilliseconds,
        ]
      ) { [weak self] response in
        Task { @MainActor in
          guard let self, let continuation = self.uploadContinuation else {
            return
          }
          self.uploadContinuation = nil
          if let error = response as? FlutterError {
            continuation.resume(
              returning: VinscentWidgetRecordingUploadOutcome(
                success: false,
                retryable: error.code != "not_implemented"
              )
            )
            return
          }
          let values = response as? [AnyHashable: Any]
          continuation.resume(
            returning: VinscentWidgetRecordingUploadOutcome(
              success: values?["success"] as? Bool == true,
              retryable: values?["retryable"] as? Bool == true
            )
          )
        }
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.uploadTimeout) {
        Task { @MainActor [weak self] in
          guard let self, let continuation = self.uploadContinuation else {
            return
          }
          self.uploadContinuation = nil
          continuation.resume(
            throwing: VinscentWidgetRecordingBridgeError.uploadTimeout
          )
        }
      }
    }
  }

  private func cleanup() {
    channel?.setMethodCallHandler(nil)
    readyContinuation?.resume(
      throwing: VinscentWidgetRecordingBridgeError.engineStartFailed
    )
    uploadContinuation?.resume(
      throwing: VinscentWidgetRecordingBridgeError.engineStartFailed
    )
    readyContinuation = nil
    uploadContinuation = nil
    channel = nil
    engine?.destroyContext()
    engine = nil
    isReady = false
  }
}
