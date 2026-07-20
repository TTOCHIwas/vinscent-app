import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct VinscentRecordingAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    let endDate: Date
  }

  let recordingId: String
}
