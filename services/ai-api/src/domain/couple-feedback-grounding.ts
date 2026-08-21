export interface CoupleFeedbackGroundingContext {
  question: { text: string };
  answers: Array<{ text: string }>;
  foundationProgress: { personalizationEnabled: boolean };
  confirmedMemories: Array<{ statement: string }>;
  recentCompletedQuestions: Array<{
    question: { text: string };
    answers: Array<{ text: string }>;
  }>;
}

const currentTimeTerms = [
  '오늘',
  '내일',
  '어제',
  '모레',
  '이번',
  '다음',
  '지난',
  '요즘',
  '지금',
  '방금',
  '최근',
];

const stableTimeTerms = [
  '주말',
  '평일',
  '아침',
  '점심',
  '저녁',
  '새벽',
  '밤',
];

const frequencyTerms = [
  '또',
  '다시',
  '계속',
  '매번',
  '매일',
  '매주',
  '매달',
  '매년',
  '항상',
  '자주',
  '여전히',
  '평소',
  '마다',
  '오늘도',
  '내일도',
  '이번에도',
  '다음에도',
  '주말에도',
  '평일에도',
  '아침에도',
  '점심에도',
  '저녁에도',
  '밤에도',
  '새벽에도',
];

const visibleSettingTerms = [
  '소파',
  '거실',
  '침대',
  '이불',
  '주방',
  '식탁',
  '안방',
  '집에서',
  '집 안',
  '카페',
  '공원',
  '바다',
  '영화관',
  '극장',
  '식당',
  '골목',
  '여행지',
  '사무실',
  '학교',
  '차 안',
];

export function hasUngroundedCoupleFeedbackDetail(
  context: CoupleFeedbackGroundingContext,
  feedbackText: string,
): boolean {
  const currentSource = normalizeGroundingText([
    context.question.text,
    ...context.answers.map(({ text }) => text),
  ].join(' '));
  const confirmedSource = context.foundationProgress.personalizationEnabled
    ? normalizeGroundingText(
      context.confirmedMemories.map(({ statement }) => statement).join(' '),
    )
    : '';
  const stableSource = `${currentSource} ${confirmedSource}`;
  const recentSource = context.foundationProgress.personalizationEnabled
    ? normalizeGroundingText(
      context.recentCompletedQuestions.flatMap(({ question, answers }) => [
        question.text,
        ...answers.map(({ text }) => text),
      ]).join(' '),
    )
    : '';
  const visibleSource = `${stableSource} ${recentSource}`;
  const normalizedFeedback = normalizeGroundingText(feedbackText);

  const exactGroundingChecks: Array<{
    terms: readonly string[];
    source: string;
  }> = [
    { terms: currentTimeTerms, source: currentSource },
    { terms: stableTimeTerms, source: stableSource },
    { terms: visibleSettingTerms, source: visibleSource },
  ];
  const hasUngroundedExactDetail = exactGroundingChecks.some(
    ({ terms, source }) => terms.some((term) =>
      normalizedFeedback.includes(term) && !source.includes(term)
    ),
  );
  const hasUngroundedFrequency = containsAnyTerm(
    normalizedFeedback,
    frequencyTerms,
  ) && !containsAnyTerm(stableSource, frequencyTerms);

  return hasUngroundedExactDetail || hasUngroundedFrequency;
}

function containsAnyTerm(value: string, terms: readonly string[]): boolean {
  return terms.some((term) => value.includes(term));
}

function normalizeGroundingText(value: string): string {
  return value
    .normalize('NFC')
    .toLowerCase()
    .replace(/쇼파/gu, '소파')
    .replace(/\s+/gu, ' ')
    .trim();
}
