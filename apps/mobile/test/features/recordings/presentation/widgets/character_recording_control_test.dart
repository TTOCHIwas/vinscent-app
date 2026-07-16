import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/theme/app_colors.dart';
import 'package:vinscent/features/recordings/application/recording_capture_controller.dart';
import 'package:vinscent/features/recordings/presentation/widgets/character_recording_control.dart';

void main() {
  testWidgets('녹음이 없으면 캐릭터만 표시하고 길게 누르기만 처리한다', (tester) async {
    var playbackCount = 0;
    var recordStartCount = 0;
    var recordEndCount = 0;

    await _pumpControl(
      tester,
      onPlaybackPressed: () => playbackCount += 1,
      onRecordStart: () => recordStartCount += 1,
      onRecordEnd: () => recordEndCount += 1,
    );

    expect(find.byKey(CharacterRecordingControl.controlKey), findsOneWidget);
    expect(find.byKey(_characterKey), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
    expect(find.byType(Text), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byKey(CharacterRecordingControl.controlKey));
    await tester.pump();
    expect(playbackCount, 0);

    await tester.longPress(find.byKey(CharacterRecordingControl.controlKey));
    await tester.pump();
    expect(recordStartCount, 1);
    expect(recordEndCount, 1);
    expect(playbackCount, 0);
  });

  testWidgets('녹음이 있으면 짧게 눌러 재생하고 길게 눌러 재녹음한다', (tester) async {
    var playbackCount = 0;
    var recordStartCount = 0;
    var recordEndCount = 0;

    await _pumpControl(
      tester,
      recordingKey: 'recording-1',
      onPlaybackPressed: () => playbackCount += 1,
      onRecordStart: () => recordStartCount += 1,
      onRecordEnd: () => recordEndCount += 1,
    );

    await tester.tap(find.byKey(CharacterRecordingControl.controlKey));
    await tester.pump();
    expect(playbackCount, 1);

    await tester.longPress(find.byKey(CharacterRecordingControl.controlKey));
    await tester.pump();
    expect(recordStartCount, 1);
    expect(recordEndCount, 1);
    expect(playbackCount, 1);
  });

  testWidgets('재생 중에는 아이콘 없이 캐릭터 맥박 효과만 반복한다', (tester) async {
    await _pumpControl(tester, recordingKey: 'recording-1', isPlaying: true);

    final before = _pulseScale(tester);
    await tester.pump(const Duration(milliseconds: 350));
    final after = _pulseScale(tester);

    expect(find.byType(Icon), findsNothing);
    expect(find.byType(Text), findsNothing);
    expect(after, greaterThan(before));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('새 녹음을 확인하는 맥박 효과는 제한된 횟수 뒤 종료된다', (tester) async {
    await _pumpControl(tester, recordingKey: 'recording-1');

    await tester.pump(const Duration(milliseconds: 250));
    expect(_pulseScale(tester), greaterThan(1));

    final pumpCount = await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
    );
    expect(pumpCount, lessThan(30));
    expect(_pulseScale(tester), 1);
  });

  testWidgets('녹음 중에는 캐릭터 외곽에 빨간 원형 진행률을 표시한다', (tester) async {
    await _pumpControl(
      tester,
      capturePhase: RecordingCapturePhase.recording,
      recordingProgress: 0.5,
    );

    final progress = tester.widget<CircularProgressIndicator>(
      find.byKey(CharacterRecordingControl.progressKey),
    );

    expect(progress.value, 0.5);
    expect(progress.color, AppColors.recordingActive);
    expect(find.byKey(_characterKey), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('준비와 저장 중에는 부정형 진행 효과와 입력 차단을 사용한다', (tester) async {
    var playbackCount = 0;
    var recordStartCount = 0;
    var recordEndCount = 0;

    await _pumpControl(
      tester,
      capturePhase: RecordingCapturePhase.uploading,
      recordingKey: 'recording-1',
      onPlaybackPressed: () => playbackCount += 1,
      onRecordStart: () => recordStartCount += 1,
      onRecordEnd: () => recordEndCount += 1,
    );

    final progress = tester.widget<CircularProgressIndicator>(
      find.byKey(CharacterRecordingControl.progressKey),
    );
    expect(progress.value, isNull);

    await tester.tap(find.byKey(CharacterRecordingControl.controlKey));
    await tester.longPress(find.byKey(CharacterRecordingControl.controlKey));
    await tester.pump();

    expect(playbackCount, 0);
    expect(recordStartCount, 0);
    expect(recordEndCount, 0);
  });
}

const _characterKey = ValueKey<String>('test-character');

Future<void> _pumpControl(
  WidgetTester tester, {
  RecordingCapturePhase capturePhase = RecordingCapturePhase.idle,
  double recordingProgress = 0,
  String? recordingKey,
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
          child: CharacterRecordingControl(
            capturePhase: capturePhase,
            recordingProgress: recordingProgress,
            recordingKey: recordingKey,
            isPlaying: isPlaying,
            isPlaybackBusy: isPlaybackBusy,
            isLoading: isLoading,
            canRecord: canRecord,
            onPlaybackPressed: onPlaybackPressed,
            onRecordStart: onRecordStart,
            onRecordEnd: onRecordEnd,
            child: const SizedBox.square(key: _characterKey, dimension: 160),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

double _pulseScale(WidgetTester tester) {
  return tester
      .widget<ScaleTransition>(find.byKey(CharacterRecordingControl.pulseKey))
      .scale
      .value;
}
