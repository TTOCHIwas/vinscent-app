import ActivityKit
import AppIntents
import SwiftUI
import UIKit
import WidgetKit

private enum VinscentWidgetPalette {
  static let brandAction = Color(
    red: 220.0 / 255.0,
    green: 105.0 / 255.0,
    blue: 87.0 / 255.0
  )
  static let onBrandAction = Color(
    red: 255.0 / 255.0,
    green: 255.0 / 255.0,
    blue: 255.0 / 255.0
  )
}

private enum VinscentWidgetLayout {
  static let contentInset: CGFloat = 6
  static let recordingControlInset: CGFloat = 10
  static let cardAspectRatio: CGFloat = 4.0 / 5.0

  static func cardSurfaceSize(in containerSize: CGSize) -> CGSize {
    let availableWidth = max(containerSize.width - contentInset * 2, 0)
    let availableHeight = max(containerSize.height - contentInset * 2, 0)
    let width = min(availableWidth, availableHeight * cardAspectRatio)
    return CGSize(width: width, height: width / cardAspectRatio)
  }
}

private struct VinscentCardSizedWidgetSurface<Content: View>: View {
  private let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    GeometryReader { proxy in
      let surfaceSize = VinscentWidgetLayout.cardSurfaceSize(
        in: proxy.size
      )
      content
        .frame(width: surfaceSize.width, height: surfaceSize.height)
        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
    }
  }
}

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
    .configurationDisplayName("단짠 캐릭터")
    .description("둘이 나눈 녹음을 재생하거나 새로 녹음해요")
    .supportedFamilies([.systemSmall])
    .contentMarginsDisabled()
  }
}

private struct VinscentCharacterWidgetView: View {
  let entry: VinscentCharacterEntry

  var body: some View {
    VinscentCardSizedWidgetSurface {
      ZStack(alignment: .bottomTrailing) {
        Color.white
        VStack(spacing: 0) {
          calendarEventSummary
          characterInteraction
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        recordingControl
          .padding(VinscentWidgetLayout.recordingControlInset)
      }
    }
  }

  @ViewBuilder
  private var calendarEventSummary: some View {
    if let title = entry.snapshot.calendarEventTitle {
      HStack(spacing: 4) {
        if let path = entry.snapshot.calendarEventArtworkPath,
          let image = UIImage(contentsOfFile: path)
        {
          Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: 26, height: 26)
        }
        Text(title)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.black.opacity(0.9))
          .lineLimit(1)
          .minimumScaleFactor(0.75)
          .frame(maxWidth: .infinity, alignment: .leading)
        if entry.snapshot.calendarEventAdditionalCount > 0 {
          Text("+\(entry.snapshot.calendarEventAdditionalCount)")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.black.opacity(0.58))
            .lineLimit(1)
        }
      }
      .frame(height: 32)
      .padding(.horizontal, 8)
      .accessibilityElement(children: .combine)
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
        .accessibilityLabel("녹음 재생")
      } else if canRecordFromWidget {
        Button(intent: ToggleVinscentWidgetRecordingIntent()) {
          animatedCharacter
        }
        .buttonStyle(.plain)
        .accessibilityLabel("녹음 시작")
      } else {
        Link(destination: VinscentWidgetConstants.recordURL) {
          animatedCharacter
        }
        .accessibilityLabel("마이크 권한 설정 열기")
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
          .tint(VinscentWidgetPalette.onBrandAction)
      }
      .accessibilityLabel("녹음 저장 중")
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
      .accessibilityLabel("녹음 종료")
    case .idle:
      if canRecordFromWidget {
        Button(intent: ToggleVinscentWidgetRecordingIntent()) {
          idleRecordingButton
        }
        .buttonStyle(.plain)
        .accessibilityLabel("녹음 시작")
      } else {
        Link(destination: VinscentWidgetConstants.recordURL) {
          idleRecordingButton
        }
        .accessibilityLabel("마이크 권한 설정 열기")
      }
    }
  }

  private var idleRecordingButton: some View {
    recordingButtonSurface {
      Image(systemName: "mic.fill")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(VinscentWidgetPalette.onBrandAction)
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
            : VinscentWidgetPalette.brandAction
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
    name: "카드 기울기"
  )
  static var caseDisplayRepresentations: [VinscentCardTilt: DisplayRepresentation] = [
    .leftFive: "왼쪽으로 5도",
    .leftTwoPointFive: "왼쪽으로 2.5도",
    .none: "기울이지 않음",
    .rightTwoPointFive: "오른쪽으로 2.5도",
    .rightFive: "오른쪽으로 5도",
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
  static var title: LocalizedStringResource = "카드 모양"
  static var description = IntentDescription(
    "카드를 그대로 두거나 살짝 기울여 표시해요"
  )

  @Parameter(title: "기울기", default: VinscentCardTilt.none)
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
    .configurationDisplayName("단짠 카드")
    .description("상대방이 남긴 최신 카드를 보여줘요")
    .supportedFamilies([.systemSmall])
    .contentMarginsDisabled()
  }
}

private struct VinscentCardWidgetView: View {
  let entry: VinscentCardEntry

  var body: some View {
    VinscentCardSizedWidgetSurface {
      Link(destination: VinscentWidgetConstants.cardURL) {
        cardImage
          .rotationEffect(.degrees(entry.tilt.degrees))
          .padding(entry.tilt == .none ? 0 : 6)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .contentShape(Rectangle())
      }
      .accessibilityLabel("최신 카드 열기")
    }
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
        .accessibilityLabel("녹음 종료")
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
