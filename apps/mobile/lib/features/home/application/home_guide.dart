enum HomeGuideAction { none, openStoryEditor, openRecordingLibrary, openAi }

enum HomeGuide {
  card(
    message: '줄에 걸린 +를 눌러 오늘의 카드를 남겨봐!',
    action: HomeGuideAction.openStoryEditor,
  ),
  recording(message: '나를 꾹 눌러 상대방에게 목소리를 남겨봐!', action: HomeGuideAction.none),
  recordingLibrary(
    message: '위에 있는 테이프를 눌러 마음에 드는 녹음을 보관해봐!',
    action: HomeGuideAction.openRecordingLibrary,
  ),
  aiConsent(
    message: '둘을 더 잘 알아갈 수 있게, 답변을 기억해도 될까?',
    action: HomeGuideAction.openAi,
  );

  const HomeGuide({required this.message, required this.action});

  final String message;
  final HomeGuideAction action;
}

List<HomeGuide> selectEligibleHomeGuides({
  required bool canCreateCard,
  required bool canRecord,
  required bool hasCurrentRecording,
  required bool hasSavedRecordingSlot,
  required bool needsAiConsent,
}) {
  return [
    if (canCreateCard) HomeGuide.card,
    if (canRecord && !hasCurrentRecording) HomeGuide.recording,
    if (canRecord && hasCurrentRecording && !hasSavedRecordingSlot)
      HomeGuide.recordingLibrary,
    if (needsAiConsent) HomeGuide.aiConsent,
  ];
}
