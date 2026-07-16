import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/theme/app_colors.dart';
import 'package:vinscent/features/recordings/application/recording_capture_controller.dart';
import 'package:vinscent/features/recordings/presentation/widgets/recording_control_button.dart';

void main() {
  testWidgets('녹음이 없으면 글자 없이 마이크 버튼 하나만 표시한다', (tester) async {
    var playbackCount = 0;
    var recordStartCount = 0;
    var recordEndCount = 0;

    await _pumpButton(
      tester,
      onPlaybackPressed: () => playbackCount += 1,
      onRecordStart: () => recordStartCount += 1,
      onRecordEnd: () => recordEndCount += 1,
    );

    expect(find.byKey(RecordingControlButton.buttonKey), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    expect(find.byType(Text), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byKey(RecordingControlButton.buttonKey));
    await tester.pump();
    expect(playbackCount, 0);

    await tester.longPress(find.byKey(RecordingControlButton.buttonKey));
    await tester.pump();
    expect(recordStartCount, 1);
    expect(recordEndCount, 1);
    expect(playbackCount, 0);
  });

  testWidgets('녹음이 있으면 짧게 눌러 재생하고 길게 눌러 재녹음한다', (tester) async {
    var playbackCount = 0;
    var recordStartCount = 0;
    var recordEndCount = 0;

    await _pumpButton(
      tester,
      hasRecording: true,
      onPlaybackPressed: () => playbackCount += 1,
      onRecordStart: () => recordStartCount += 1,
      onRecordEnd: () => recordEndCount += 1,
    );

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    await tester.tap(find.byKey(RecordingControlButton.buttonKey));
    await tester.pump();
    expect(playbackCount, 1);

    await tester.longPress(find.byKey(RecordingControlButton.buttonKey));
    await tester.pump();
    expect(recordStartCount, 1);
    expect(recordEndCount, 1);
    expect(playbackCount, 1);
  });

  testWidgets('재생 중에는 같은 버튼이 일시정지 아이콘으로 바뀐다', (tester) async {
    await _pumpButton(tester, hasRecording: true, isPlaying: true);

    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('녹음 중에는 버튼 색상과 원형 진행률만 상태를 표현한다', (tester) async {
    await _pumpButton(
      tester,
      capturePhase: RecordingCapturePhase.recording,
      recordingProgress: 0.5,
    );

    final surface = tester.widget<AnimatedContainer>(
      find.byKey(RecordingControlButton.surfaceKey),
    );
    final decoration = surface.decoration! as BoxDecoration;
    final progress = tester.widget<CircularProgressIndicator>(
      find.byKey(RecordingControlButton.progressKey),
    );

    expect(decoration.color, AppColors.recordingActive);
    expect(progress.value, 0.5);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('준비와 저장 중에는 부정형 진행 효과와 입력 차단을 사용한다', (tester) async {
    var playbackCount = 0;
    var recordStartCount = 0;
    var recordEndCount = 0;

    await _pumpButton(
      tester,
      capturePhase: RecordingCapturePhase.uploading,
      hasRecording: true,
      onPlaybackPressed: () => playbackCount += 1,
      onRecordStart: () => recordStartCount += 1,
      onRecordEnd: () => recordEndCount += 1,
    );

    final progress = tester.widget<CircularProgressIndicator>(
      find.byKey(RecordingControlButton.progressKey),
    );
    expect(progress.value, isNull);

    await tester.tap(find.byKey(RecordingControlButton.buttonKey));
    await tester.longPress(find.byKey(RecordingControlButton.buttonKey));
    await tester.pump();

    expect(playbackCount, 0);
    expect(recordStartCount, 0);
    expect(recordEndCount, 0);
    expect(find.byType(Text), findsNothing);
  });
}

Future<void> _pumpButton(
  WidgetTester tester, {
  RecordingCapturePhase capturePhase = RecordingCapturePhase.idle,
  double recordingProgress = 0,
  bool hasRecording = false,
  bool isPlaying = false,
  bool isPlaybackBusy = false,
  bool isLoading = false,
  bool canRecord = true,
  VoidCallback? onPlaybackPressed,
  VoidCallback? onRecordStart,
  VoidCallback? onRecordEnd,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: RecordingControlButton(
            capturePhase: capturePhase,
            recordingProgress: recordingProgress,
            hasRecording: hasRecording,
            isPlaying: isPlaying,
            isPlaybackBusy: isPlaybackBusy,
            isLoading: isLoading,
            canRecord: canRecord,
            onPlaybackPressed: onPlaybackPressed,
            onRecordStart: onRecordStart,
            onRecordEnd: onRecordEnd,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
