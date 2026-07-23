import assert from 'node:assert/strict';
import test from 'node:test';

import {
  anonymizeCompletedQuestionContext,
  deriveLearningStage,
  resolveMemoryCandidates,
  validateCoupleFeedback,
  validateMemoryCandidates,
  validateQuestionRecommendation,
  type CompletedQuestionContext,
} from '../src/domain/learning-contract.ts';

const context: CompletedQuestionContext = {
  coupleId: 'couple-1',
  question: {
    dailyQuestionId: 'daily-question-1',
    questionId: 'question-1',
    text: '힘든 날에는 상대가 어떻게 곁에 있어주면 가장 힘이 돼?',
    domain: 'emotional_support',
    depth: 'exploratory',
    promptAngle: 'preference',
  },
  answers: [
    {
      answerId: 'answer-a',
      userId: 'user-a',
      text: '조언보다 먼저 조용히 들어주면 좋겠어.',
    },
    {
      answerId: 'answer-b',
      userId: 'user-b',
      text: '잠깐 혼자 정리할 시간을 준 뒤 말을 걸어주면 좋아.',
    },
  ],
  foundationProgress: {
    completedCount: 8,
    totalCount: 24,
    personalizationEnabled: false,
    domainProgress: {
      personal_values: { completedCount: 2, totalCount: 4 },
      emotional_support: { completedCount: 2, totalCount: 4 },
      communication_repair: { completedCount: 1, totalCount: 4 },
      daily_life: { completedCount: 1, totalCount: 4 },
      relationship_strength: { completedCount: 1, totalCount: 4 },
      future_boundaries: { completedCount: 1, totalCount: 4 },
    },
  },
  confirmedMemories: [],
  memoryCandidates: [],
  recentFoundationQuestions: [],
  recentCompletedQuestions: [],
  remainingFoundationQuestions: [
    {
      questionKey: 'foundation_v1_communication_01',
      text: '생각이 다를 때 어떤 대화를 하면 이해받았다고 느껴?',
      domain: 'communication_repair',
      depth: 'exploratory',
      promptAngle: 'preference',
    },
    {
      questionKey: 'foundation_v1_daily_life_01',
      text: '아무 일정도 없는 날을 함께 보낸다면 어떻게 보내고 싶어?',
      domain: 'daily_life',
      depth: 'light',
      promptAngle: 'preference',
    },
  ],
};

test('학습 단계 경계를 24개 커리큘럼 기준으로 계산한다', () => {
  assert.equal(deriveLearningStage(0, 24), 'collecting');
  assert.equal(deriveLearningStage(7, 24), 'collecting');
  assert.equal(deriveLearningStage(8, 24), 'exploring');
  assert.equal(deriveLearningStage(15, 24), 'exploring');
  assert.equal(deriveLearningStage(16, 24), 'refining');
  assert.equal(deriveLearningStage(23, 24), 'refining');
  assert.equal(deriveLearningStage(24, 24), 'ready');
  assert.equal(deriveLearningStage(30, 24), 'ready');
});

test('모델 문맥에서 실제 커플과 사용자 식별자를 제거한다', () => {
  const anonymized = anonymizeCompletedQuestionContext(context);
  const serialized = JSON.stringify(anonymized);

  assert.deepEqual(
    anonymized.answers.map((answer) => answer.participantKey),
    ['partner_a', 'partner_b'],
  );
  assert.equal(serialized.includes('couple-1'), false);
  assert.equal(serialized.includes('user-a'), false);
  assert.equal(serialized.includes('user-b'), false);
});

test('기억 후보는 입력 답변을 근거로 사용해야 한다', () => {
  assert.doesNotThrow(() => {
    validateMemoryCandidates(context, [
      {
        memoryKey: 'support_listening_first_user_a',
        scope: 'personal',
        subjectUserId: 'user-a',
        kind: 'support_preference',
        domain: 'emotional_support',
        evidenceType: 'explicit',
        sensitiveCategory: 'none',
        statement: '힘든 날에는 조언보다 먼저 이야기를 들어주면 좋아',
        confidence: 0.78,
        evidenceAnswerIds: ['answer-a'],
      },
    ]);
  });

  assert.throws(
    () => {
      validateMemoryCandidates(context, [
        {
          memoryKey: 'unsupported_memory',
          scope: 'couple',
          subjectUserId: null,
          kind: 'relationship_strength',
          domain: 'relationship_strength',
          evidenceType: 'repeated_pattern',
          sensitiveCategory: 'none',
          statement: '두 사람은 갈등을 항상 빠르게 해결한다.',
          confidence: 0.9,
          evidenceAnswerIds: ['unknown-answer'],
        },
      ]);
    },
    /unknown evidence answer/i,
  );
});

test('사용자에게 보이는 기억 문장에서 내부 역할명과 보고서 말투를 거부한다', () => {
  const candidate = {
    memoryKey: 'support_listening_first_user_a',
    scope: 'personal' as const,
    subjectUserId: 'user-a',
    kind: 'support_preference',
    domain: 'emotional_support' as const,
    evidenceType: 'explicit' as const,
    sensitiveCategory: 'none' as const,
    confidence: 0.78,
    evidenceAnswerIds: ['answer-a'],
  };

  assert.throws(
    () => validateMemoryCandidates(context, [
      {
        ...candidate,
        statement: '파트너 A는 이야기를 먼저 들어주는 것을 선호합니다.',
      },
    ]),
    /memory statement cannot expose an internal participant/i,
  );
  assert.throws(
    () => validateMemoryCandidates(context, [
      {
        ...candidate,
        statement: '이야기를 먼저 들어주는 것을 선호합니다',
      },
    ]),
    /memory statement must use casual speech/i,
  );
});

test('커플 기억은 두 사람의 현재 답변을 모두 근거로 사용해야 한다', () => {
  assert.throws(
    () => validateMemoryCandidates(context, [
      {
        memoryKey: 'shared_support_preference',
        scope: 'couple',
        subjectUserId: null,
        kind: 'shared_preference',
        domain: 'emotional_support',
        evidenceType: 'explicit',
        sensitiveCategory: 'none',
        statement: '힘든 날에는 먼저 마음을 정리할 시간이 중요해',
        confidence: 0.8,
        evidenceAnswerIds: ['answer-a'],
      },
    ]),
    /couple memory requires both participant answers/i,
  );
});

test('반복 패턴은 다른 질문에서 같은 기억이 관찰된 경우에만 허용한다', () => {
  const repeatedCandidate = {
    memoryKey: 'support_listening_first_user_a',
    scope: 'personal' as const,
    subjectUserId: 'user-a',
    kind: 'support_preference',
    domain: 'emotional_support' as const,
    evidenceType: 'repeated_pattern' as const,
    sensitiveCategory: 'none' as const,
    statement: '힘든 날에는 이야기를 먼저 들어주면 좋아',
    confidence: 0.86,
    evidenceAnswerIds: ['answer-a'],
  };

  assert.throws(
    () => validateMemoryCandidates(context, [repeatedCandidate]),
    /repeated memory requires prior question evidence/i,
  );

  assert.doesNotThrow(() => {
    validateMemoryCandidates(
      {
        ...context,
        memoryCandidates: [
          {
            memoryKey: repeatedCandidate.memoryKey,
            scope: repeatedCandidate.scope,
            subjectUserId: repeatedCandidate.subjectUserId,
            kind: repeatedCandidate.kind,
            domain: repeatedCandidate.domain,
            evidenceType: 'explicit',
            statement: '힘든 날에는 이야기를 먼저 들어주면 좋아',
            confidence: 0.78,
            state: 'pending',
            evidenceQuestionCount: 1,
          },
        ],
      },
      [repeatedCandidate],
    );
  });
});

test('한 질문에서 기억 후보를 세 개보다 많이 만들 수 없다', () => {
  const candidates = Array.from({ length: 4 }, (_, index) => ({
    memoryKey: `support_preference_${index}`,
    scope: 'personal' as const,
    subjectUserId: index.isEven ? 'user-a' : 'user-b',
    kind: 'support_preference',
    domain: 'emotional_support' as const,
    evidenceType: 'explicit' as const,
    sensitiveCategory: 'none' as const,
    statement: index.isEven
        ? '힘든 날에는 이야기를 먼저 들어주면 좋아'
        : '마음을 정리할 시간을 먼저 가지면 좋아',
    confidence: 0.8,
    evidenceAnswerIds: [index.isEven ? 'answer-a' : 'answer-b'],
  }));

  assert.throws(
    () => validateMemoryCandidates(context, candidates),
    /at most three memory candidates/i,
  );
});

test('개인 기억 대상은 답변 참여자 중 한 명이어야 한다', () => {
  assert.throws(
    () => {
      validateMemoryCandidates(context, [
        {
          memoryKey: 'foreign_subject',
          scope: 'personal',
          subjectUserId: 'other-user',
          kind: 'value',
          domain: 'personal_values',
          evidenceType: 'explicit',
          sensitiveCategory: 'none',
          statement: '확인되지 않은 사용자에 대한 기억이다.',
          confidence: 0.5,
          evidenceAnswerIds: ['answer-a'],
        },
      ]);
    },
    /unknown personal subject/i,
  );
});

test('모델의 익명 참여자 키는 서버 경계에서만 사용자 ID로 복원한다', () => {
  const [resolved] = resolveMemoryCandidates(context, [
    {
      memoryKey: 'anonymous_subject',
      scope: 'personal',
      subjectParticipantKey: 'partner_a',
      kind: 'support_preference',
      domain: 'emotional_support',
      evidenceType: 'explicit',
      sensitiveCategory: 'none',
      statement: '힘든 날에는 먼저 조용히 들어주는 것을 선호한다.',
      confidence: 0.75,
      evidenceAnswerIds: ['answer-a'],
    },
  ]);

  assert.equal(resolved?.subjectUserId, 'user-a');
  assert.equal(resolved?.domain, 'emotional_support');
  assert.equal(resolved?.evidenceType, 'explicit');
});

test('한 줄 피드백은 커플 공유 반응 형식을 지켜야 한다', () => {
  assert.doesNotThrow(() => {
    validateCoupleFeedback({ text: '소중한 걸 고르는 데도 시간이 조금 필요한가 봐!' });
  });
  assert.doesNotThrow(() => {
    validateCoupleFeedback({ text: '오늘은 둘의 하루가 평소보다 조금 무거운 날인가 봐...' });
  });
  assert.doesNotThrow(() => {
    validateCoupleFeedback({ text: '오늘 메뉴판은 둘 사이에서 꽤 바쁘겠네?' });
  });
  assert.doesNotThrow(() => {
    validateCoupleFeedback({ text: '오늘은 둘의 하루가 조금 무겁네' });
  });

  assert.throws(
    () => validateCoupleFeedback({ text: '가'.repeat(81) }),
    /1 to 80 characters/i,
  );
  assert.throws(
    () => validateCoupleFeedback({ text: '오늘 메뉴판은 둘 사이에서 꽤 바쁘겠네.' }),
    /allowed endings/i,
  );
  assert.throws(
    () => validateCoupleFeedback({ text: '오늘 메뉴판은 둘 사이에서 꽤 바쁘겠네!?' }),
    /allowed endings/i,
  );
  assert.throws(
    () => validateCoupleFeedback({ text: '오늘 메뉴판은 둘 사이에서 꽤 바쁘겠네?!' }),
    /allowed endings/i,
  );
  assert.throws(
    () => validateCoupleFeedback({ text: '오늘 메뉴판은 둘 사이에서 꽤 바쁘겠네!!' }),
    /allowed endings/i,
  );
  assert.throws(
    () => validateCoupleFeedback({ text: '오늘 메뉴판은 둘 사이에서 꽤 바쁘겠네??' }),
    /allowed endings/i,
  );
  assert.throws(
    () => validateCoupleFeedback({ text: '오늘은 둘의 하루가 조금 무겁네..' }),
    /allowed endings/i,
  );
  assert.throws(
    () => validateCoupleFeedback({
      text: '너는 시간을 소중하게 생각하는데 상대방은 아직 잘 모르겠나 봐',
    }),
    /answer owner/i,
  );
});

test('고정 질문 추천은 남은 커리큘럼 후보 안에서만 선택한다', () => {
  assert.doesNotThrow(() => {
    validateQuestionRecommendation(
      context.remainingFoundationQuestions,
      'foundation_v1_communication_01',
    );
  });

  assert.throws(
    () => {
      validateQuestionRecommendation(
        context.remainingFoundationQuestions,
        'foundation_v1_unknown_99',
      );
    },
    /question recommendation is not an allowed candidate/i,
  );
});
