import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/home/application/home_guide.dart';

void main() {
  test('orders the available first-use guides by the intended journey', () {
    final guides = selectEligibleHomeGuides(
      canCreateCard: true,
      canRecord: true,
      hasCurrentRecording: false,
      hasSavedRecordingSlot: false,
      needsAiConsent: true,
    );

    expect(guides, [HomeGuide.card, HomeGuide.recording, HomeGuide.aiConsent]);
  });

  test('offers the recording library only after a recording exists', () {
    final guides = selectEligibleHomeGuides(
      canCreateCard: false,
      canRecord: true,
      hasCurrentRecording: true,
      hasSavedRecordingSlot: false,
      needsAiConsent: false,
    );

    expect(guides, [HomeGuide.recordingLibrary]);
  });

  test('skips guides for features that are already in use', () {
    final guides = selectEligibleHomeGuides(
      canCreateCard: false,
      canRecord: true,
      hasCurrentRecording: true,
      hasSavedRecordingSlot: true,
      needsAiConsent: false,
    );

    expect(guides, isEmpty);
  });

  test('keeps the AI consent invitation concise and conversational', () {
    expect(HomeGuide.aiConsent.message, '둘을 더 잘 알아갈 수 있게, 답변을 기억해도 될까?');
    expect(HomeGuide.aiConsent.action, HomeGuideAction.openAi);
  });
}
