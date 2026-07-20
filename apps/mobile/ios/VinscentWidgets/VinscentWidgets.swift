import ActivityKit
import AppIntents
import SwiftUI
import UIKit
import WidgetKit

@main
struct VinscentWidgets: WidgetBundle {
  var body: some Widget {
    VinscentCharacterWidget()
    VinscentCardWidget()
    VinscentRecordingLiveActivity()
  }
}

private struct VinscentCharacterEntry: TimelineEntry {
  let date: Date
  let snapshot: VinscentWidgetSnapshot
}

private struct VinscentCharacterProvider: TimelineProvider {
  func placeholder(in context: Context) -> VinscentCharacterEntry {
    VinscentCharacterEntry(date: Date(), snapshot: .load())
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (VinscentCharacterEntry) -> Void
  ) {
    completion(VinscentCharacterEntry(date: Date(), snapshot: .load()))
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<VinscentCharacterEntry>) -> Void
  ) {
    let entry = VinscentCharacterEntry(date: Date(), snapshot: .load())
    completion(
      Timeline(
        entries: [entry],
        policy: .after(Date(timeIntervalSinceNow: 15 * 60))
      )
    )
  }
}

private struct VinscentCharacterWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: VinscentWidgetConstants.characterKind,
      provider: VinscentCharacterProvider()
    ) { entry in
      VinscentCharacterWidgetView(entry: entry)
        .containerBackground(.clear, for: .widget)
    }
    .configurationDisplayName("Vinscent Character")
    .description("Play or record your shared couple message.")
    .supportedFamilies([.systemSmall])
    .contentMarginsDisabled()
  }
}

private struct VinscentCharacterWidgetView: View {
  let entry: VinscentCharacterEntry

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      characterInteraction
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      recordingControl
        .padding(10)
    }
  }

  @ViewBuilder
  private var characterInteraction: some View {
    switch entry.snapshot.recordingPhase {
    case .recording, .uploading:
      animatedCharacter
    case .idle:
      if entry.snapshot.recordingAudioPath != nil {
        Button(intent: ToggleVinscentWidgetPlaybackIntent()) {
          animatedCharacter
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play recording")
      } else if canRecordFromWidget {
        Button(intent: ToggleVinscentWidgetRecordingIntent()) {
          animatedCharacter
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start recording")
      } else {
        Link(destination: VinscentWidgetConstants.recordURL) {
          animatedCharacter
        }
        .accessibilityLabel("Open microphone permission")
      }
    }
  }

  @ViewBuilder
  private var animatedCharacter: some View {
    if entry.snapshot.isCharacterPlaying {
      TimelineView(.periodic(from: entry.date, by: 0.32)) { context in
        characterImage
          .offset(y: bounceOffset(at: context.date))
      }
    } else {
      characterImage
    }
  }

  @ViewBuilder
  private var characterImage: some View {
    if let path = entry.snapshot.characterImagePath,
      let image = UIImage(contentsOfFile: path)
    {
      Image(uiImage: image)
        .resizable()
        .scaledToFit()
        .padding(6)
    } else {
      Image(systemName: "person.crop.square")
        .resizable()
        .scaledToFit()
        .foregroundStyle(.black.opacity(0.7))
        .padding(30)
    }
  }

  @ViewBuilder
  private var recordingControl: some View {
    switch entry.snapshot.recordingPhase {
    case .uploading:
      recordingButtonSurface {
        ProgressView()
          .controlSize(.small)
          .tint(.black)
      }
      .accessibilityLabel("Saving recording")
    case .recording:
      Button(intent: ToggleVinscentWidgetRecordingIntent()) {
        recordingButtonSurface {
          Image(systemName: "stop.fill")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
        }
        .overlay {
          recordingCountdownRing
        }
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Stop recording")
    case .idle:
      if canRecordFromWidget {
        Button(intent: ToggleVinscentWidgetRecordingIntent()) {
          idleRecordingButton
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start recording")
      } else {
        Link(destination: VinscentWidgetConstants.recordURL) {
          idleRecordingButton
        }
        .accessibilityLabel("Open microphone permission")
      }
    }
  }

  private var idleRecordingButton: some View {
    recordingButtonSurface {
      Image(systemName: "mic.fill")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(.black)
    }
  }

  private var canRecordFromWidget: Bool {
    entry.snapshot.microphonePermissionGranted &&
      ActivityAuthorizationInfo().areActivitiesEnabled
  }

  private var recordingCountdownRing: some View {
    TimelineView(.periodic(from: entry.date, by: 0.1)) { context in
      let startedAt = entry.snapshot.recordingStartedAt ?? entry.date
      let elapsed = min(
        max(context.date.timeIntervalSince(startedAt), 0),
        VinscentWidgetConstants.maximumRecordingDuration
      )
      let progress = elapsed /
        VinscentWidgetConstants.maximumRecordingDuration
      Circle()
        .trim(from: progress, to: 1)
        .stroke(
          Color.red,
          style: StrokeStyle(lineWidth: 4, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .padding(2)
    }
  }

  private func recordingButtonSurface<Content: View>(
    @ViewBuilder content: () -> Content
  ) -> some View {
    ZStack {
      Circle()
        .fill(
          entry.snapshot.recordingPhase == .recording
            ? Color.red
            : Color.white.opacity(0.96)
        )
        .shadow(color: .black.opacity(0.14), radius: 3, y: 1)
      content()
    }
    .frame(width: 48, height: 48)
  }

  private func bounceOffset(at date: Date) -> CGFloat {
    let startedAt = entry.snapshot.characterPlayingStartedAt ?? entry.date
    let frame = Int(max(date.timeIntervalSince(startedAt), 0) / 0.32)
    return frame.isMultiple(of: 2) ? -8 : 0
  }
}

enum VinscentCardTilt: String, AppEnum {
  case leftFive
  case leftTwoPointFive
  case none
  case rightTwoPointFive
  case rightFive

  static var typeDisplayRepresentation = TypeDisplayRepresentation(
    name: "Card tilt"
  )
  static var caseDisplayRepresentations: [VinscentCardTilt: DisplayRepresentation] = [
    .leftFive: "Left 5 degrees",
    .leftTwoPointFive: "Left 2.5 degrees",
    .none: "Straight",
    .rightTwoPointFive: "Right 2.5 degrees",
    .rightFive: "Right 5 degrees",
  ]

  var degrees: Double {
    switch self {
    case .leftFive: -5
    case .leftTwoPointFive: -2.5
    case .none: 0
    case .rightTwoPointFive: 2.5
    case .rightFive: 5
    }
  }
}

struct VinscentCardConfigurationIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "Card appearance"
  static var description = IntentDescription(
    "Choose whether the card is straight or lightly tilted."
  )

  @Parameter(title: "Tilt", default: VinscentCardTilt.none)
  var tilt: VinscentCardTilt
}

private struct VinscentCardEntry: TimelineEntry {
  let date: Date
  let imagePath: String?
  let tilt: VinscentCardTilt
}

private struct VinscentCardProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> VinscentCardEntry {
    VinscentCardEntry(date: Date(), imagePath: nil, tilt: .none)
  }

  func snapshot(
    for configuration: VinscentCardConfigurationIntent,
    in context: Context
  ) async -> VinscentCardEntry {
    makeEntry(configuration: configuration)
  }

  func timeline(
    for configuration: VinscentCardConfigurationIntent,
    in context: Context
  ) async -> Timeline<VinscentCardEntry> {
    Timeline(
      entries: [makeEntry(configuration: configuration)],
      policy: .after(Date(timeIntervalSinceNow: 15 * 60))
    )
  }

  private func makeEntry(
    configuration: VinscentCardConfigurationIntent
  ) -> VinscentCardEntry {
    VinscentCardEntry(
      date: Date(),
      imagePath: VinscentWidgetSnapshot.load().partnerCardImagePath,
      tilt: configuration.tilt
    )
  }
}

private struct VinscentCardWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: VinscentWidgetConstants.cardKind,
      intent: VinscentCardConfigurationIntent.self,
      provider: VinscentCardProvider()
    ) { entry in
      VinscentCardWidgetView(entry: entry)
        .containerBackground(.clear, for: .widget)
    }
    .configurationDisplayName("Vinscent Card")
    .description("Show your partner's latest card.")
    .supportedFamilies([.systemSmall])
    .contentMarginsDisabled()
  }
}

private struct VinscentCardWidgetView: View {
  let entry: VinscentCardEntry

  var body: some View {
    Link(destination: VinscentWidgetConstants.cardURL) {
      cardImage
        .rotationEffect(.degrees(entry.tilt.degrees))
        .padding(entry.tilt == .none ? 6 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
    .accessibilityLabel("Open latest card")
  }

  @ViewBuilder
  private var cardImage: some View {
    if let path = entry.imagePath, let image = UIImage(contentsOfFile: path) {
      Image(uiImage: image)
        .resizable()
        .scaledToFit()
    } else {
      Image(systemName: "rectangle.portrait")
        .resizable()
        .scaledToFit()
        .foregroundStyle(.black.opacity(0.45))
        .padding(34)
    }
  }
}

private struct VinscentRecordingLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: VinscentRecordingAttributes.self) { context in
      HStack(spacing: 12) {
        Image(systemName: "waveform")
          .foregroundStyle(.red)
        Text(
          timerInterval: min(Date(), context.state.endDate)...context.state.endDate,
          countsDown: true
        )
        .monospacedDigit()
        Spacer()
        Button(intent: ToggleVinscentWidgetRecordingIntent()) {
          Image(systemName: "stop.fill")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop recording")
      }
      .padding()
      .activityBackgroundTint(.black)
      .activitySystemActionForegroundColor(.white)
      .foregroundStyle(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "waveform")
            .foregroundStyle(.red)
        }
        DynamicIslandExpandedRegion(.center) {
          Text(
            timerInterval: min(Date(), context.state.endDate)...context.state.endDate,
            countsDown: true
          )
          .monospacedDigit()
        }
        DynamicIslandExpandedRegion(.trailing) {
          Button(intent: ToggleVinscentWidgetRecordingIntent()) {
            Image(systemName: "stop.fill")
          }
          .buttonStyle(.plain)
        }
      } compactLeading: {
        Image(systemName: "waveform")
          .foregroundStyle(.red)
      } compactTrailing: {
        Text(
          timerInterval: min(Date(), context.state.endDate)...context.state.endDate,
          countsDown: true
        )
        .monospacedDigit()
        .frame(width: 42)
      } minimal: {
        Image(systemName: "mic.fill")
          .foregroundStyle(.red)
      }
      .keylineTint(.red)
    }
  }
}
