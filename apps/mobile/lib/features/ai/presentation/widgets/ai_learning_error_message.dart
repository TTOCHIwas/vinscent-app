import '../../data/ai_learning_failure.dart';

String aiLearningErrorMessage(Object error) {
  if (error is AiLearningRepositoryException) {
    return switch (error.reason) {
      AiLearningFailureReason.authRequired => '다시 로그인해 주세요.',
      AiLearningFailureReason.activeCoupleRequired => '커플 연결을 확인해 주세요.',
      AiLearningFailureReason.consentRequired => '두 사람의 AI 학습 동의가 필요합니다.',
      AiLearningFailureReason.memoryNotFound => '확인할 기억을 찾지 못했어요.',
      AiLearningFailureReason.memoryConfirmationForbidden =>
        '이 기억은 본인만 확인할 수 있어요.',
      AiLearningFailureReason.memoryReviewNotReady =>
        '기억을 확인할 준비가 아직 끝나지 않았어요.',
      AiLearningFailureReason.memoryAlreadyReviewed => '이미 확인한 기억이에요.',
      AiLearningFailureReason.personalizationNotReady =>
        '두 사람의 기억 확인이 아직 끝나지 않았어요.',
      AiLearningFailureReason.curriculumUnavailable => 'AI 학습 질문을 준비하고 있어요.',
      AiLearningFailureReason.focusedQuestionsLocked => '먼저 집중 질문을 잠금 해제해 주세요.',
      AiLearningFailureReason.answerRequired => '답변을 입력해 주세요.',
      AiLearningFailureReason.answerTooLong => '답변은 500자까지 입력할 수 있어요.',
      AiLearningFailureReason.questionNotReady => '질문 상태가 바뀌었어요. 다시 확인해 주세요.',
      AiLearningFailureReason.invalidQuestion => '질문 정보를 확인하지 못했어요.',
      AiLearningFailureReason.configMissing => 'AI 연결 설정을 확인해 주세요.',
      AiLearningFailureReason.requestTimeout => '요청 시간이 초과됐어요. 다시 시도해 주세요.',
      AiLearningFailureReason.invalidResponse ||
      AiLearningFailureReason.unknown => 'AI 정보를 불러오지 못했어요.',
    };
  }

  return 'AI 정보를 불러오지 못했어요.';
}
