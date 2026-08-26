import assert from 'node:assert/strict';
import test from 'node:test';

import {
  anonymizeCompletedQuestionContext,
  CoupleFeedbackValidationError,
  deriveLearningStage,
  PersonalizedQuestionValidationError,
  ProactiveSuggestionValidationError,
  resolveMemoryCandidates,
  repairCoupleFeedbackPunctuation,
  validateCoupleFeedback,
  validateDirectQuestionAnswer,
  validateDirectQuestionFollowUp,
  validateMemoryCandidates,
  validatePersonalizedQuestion,
  validateProactiveSuggestion,
  validateQuestionRecommendation,
  type CompletedQuestionContext,
  type DirectQuestionContext,
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

const directQuestionContext: DirectQuestionContext = {
  questionText: '상대는 쉬는 날에 어떤 걸 하고 싶어할까?',
  confirmedMemories: [],
  recentCompletedQuestions: [],
  recentSharedQuestionTexts: [
    '요즘 함께 자주 하고 싶은 건 뭐야?',
  ],
};

test('direct answers reject internal participant labels and blocked topics', () => {
  assert.doesNotThrow(() =>
    validateDirectQuestionAnswer(directQuestionContext, {
      status: 'answered',
      text: '아직 확실히 알 만큼 기록이 충분하지 않아',
      followUpQuestion: null,
    })
  );
  assert.throws(() =>
    validateDirectQuestionAnswer(directQuestionContext, {
      status: 'answered',
      text: 'partner_a는 산책을 좋아해',
      followUpQuestion: null,
    })
  );
  assert.throws(() =>
    validateDirectQuestionAnswer(directQuestionContext, {
      status: 'answered',
      text: '정신건강 상태를 보면 이렇게 판단할 수 있어',
      followUpQuestion: null,
    })
  );
  assert.throws(() =>
    validateDirectQuestionAnswer(directQuestionContext, {
      status: 'answered',
      text: '연봉과 돈 관리 방식을 비교하면 이렇게 볼 수 있어',
      followUpQuestion: null,
    })
  );
  assert.throws(() =>
    validateDirectQuestionAnswer(directQuestionContext, {
      status: 'answered',
      text: '건강 상태와 병원 기록을 보면 이런 경향이 있어',
      followUpQuestion: null,
    })
  );
});

test('사용자에게 보이는 AI 문장은 다른 문자 체계를 섞지 않는다', () => {
  assert.throws(
    () =>
      validateDirectQuestionAnswer(directQuestionContext, {
        status: 'insufficient',
        text: 'まだ情報が不足してるよ. 아직 여행 취향은 모르겠어',
        followUpQuestion: null,
      }),
    /foreign script/i,
  );
  assert.throws(
    () =>
      validatePersonalizedQuestion({
        questionKey: 'personalized_daily_rest_ab12cd34',
        text: '함께 쉬는 시간을 어떻게 보낼지了解하고 싶어?',
        category: 'daily_life',
        mood: 'curious',
        rationale: '쉬는 날의 공통점을 더 확인하기 위해서야',
      }),
    /foreign script/i,
  );
});

test('사용자에게 보이는 AI 문장은 캐릭터의 반말을 사용한다', () => {
  assert.doesNotThrow(() =>
    validatePersonalizedQuestion({
      questionKey: 'personalized_daily_rest_ab12cd34',
      text: '함께 쉬는 날 가장 하고 싶은 건 뭐야?',
      category: 'daily_life',
      mood: 'curious',
      rationale: '쉬는 날의 공통점을 더 확인하기 위해서야',
    })
  );
  assert.throws(
    () =>
      validatePersonalizedQuestion({
        questionKey: 'personalized_daily_rest_ab12cd34',
        text: '함께 쉬는 날 가장 즐거운 활동은 무엇인가요?',
        category: 'daily_life',
        mood: 'curious',
        rationale: '쉬는 날의 공통점을 더 확인하기 위해서야',
      }),
    /casual speech/i,
  );
  assert.throws(
    () =>
      validateDirectQuestionAnswer(directQuestionContext, {
        status: 'answered',
        text: '상대방은 새로운 동네를 걷는 걸 좋아해요.',
        followUpQuestion: null,
      }),
    /casual speech/i,
  );
  assert.throws(
    () => validateCoupleFeedback({ text: '오늘은 음악이 잘 어울리네요!' }),
    /casual speech/i,
  );
});

test('근거가 부족할 때만 대칭적인 공용 질문 후보를 허용한다', () => {
  assert.doesNotThrow(() =>
    validateDirectQuestionAnswer(directQuestionContext, {
      status: 'insufficient',
      text: '아직은 확실히 알기 어려워',
      followUpQuestion: {
        questionKey: 'direct_follow_up_shared_rest_ab12cd34',
        text: '쉬는 날 함께 해보고 싶은 건 뭐야?',
        category: 'daily_life',
        mood: 'light',
        rationale: '쉬는 날의 선호를 확인할 근거가 아직 부족해',
      },
    })
  );

  assert.throws(
    () =>
      validateDirectQuestionAnswer(directQuestionContext, {
        status: 'answered',
        text: '조용히 쉬는 시간을 좋아한다고 했어',
        followUpQuestion: {
          questionKey: 'direct_follow_up_shared_rest_ab12cd34',
          text: '쉬는 날 함께 해보고 싶은 건 뭐야?',
          category: 'daily_life',
          mood: 'light',
          rationale: '쉬는 날의 선호를 확인할 근거가 아직 부족해',
        },
      }),
    /answered direct question cannot include a follow-up/i,
  );

  assert.throws(
    () =>
      validateDirectQuestionAnswer(directQuestionContext, {
        status: 'insufficient',
        text: '아직은 확실히 알기 어려워',
        followUpQuestion: {
          questionKey: 'direct_follow_up_partner_rest_ab12cd34',
          text: '상대방은 쉬는 날 뭘 하고 싶어 해?',
          category: 'daily_life',
          mood: null,
          rationale: '상대방의 쉬는 날 선호를 묻기 위해서야',
        },
      }),
    /symmetric/i,
  );

  assert.throws(
    () =>
      validateDirectQuestionAnswer(directQuestionContext, {
        status: 'insufficient',
        text: '아직은 확실히 알기 어려워',
        followUpQuestion: {
          questionKey: 'direct_follow_up_cooking_ab12cd34',
          text: '너가 가장 잘하는 요리는 뭐야?',
          category: 'daily_life',
          mood: null,
          rationale: '직접 만들기 좋아하는 요리를 확인하기 위해서야',
        },
      }),
    /symmetric/i,
  );

  assert.throws(
    () =>
      validateDirectQuestionAnswer(directQuestionContext, {
        status: 'insufficient',
        text: '아직은 확실히 알기 어려워',
        followUpQuestion: {
          questionKey: 'direct_follow_up_recent_topic_ab12cd34',
          text: '요즘 함께 자주 하고 싶은 건 뭐야?',
          category: 'daily_life',
          mood: null,
          rationale: '최근 선호를 다시 확인하기 위해서야',
        },
      }),
    /duplicate/i,
  );
});

test('공용 후속 질문은 한국어 표현만 바꾼 의미 중복을 거부한다', () => {
  const travelContext: DirectQuestionContext = {
    ...directQuestionContext,
    recentSharedQuestionTexts: [
      '여행지에서는 아침 일찍 움직이는 게 좋아, 느긋하게 쉬는 게 좋아?',
    ],
  };
  const candidate = (text: string) => ({
    questionKey: 'direct_follow_up_travel_ab12cd34',
    text,
    category: 'direct_follow_up',
    mood: null,
    rationale: '여행지에서 선호하는 생활 리듬을 확인하기 위해서야',
  });

  assert.throws(
    () => validateDirectQuestionAnswer(travelContext, {
      status: 'insufficient',
      text: '아직 확인된 내용이 없어서 잘 모르겠어',
      followUpQuestion: candidate(
        '여행지에서 아침 일찍 움직이는 게 좋거나 느긋하게 쉬는 게 좋을까?',
      ),
    }),
    /duplicate/i,
  );
  assert.throws(
    () => validateDirectQuestionAnswer(travelContext, {
      status: 'insufficient',
      text: '아직 확인된 내용이 없어서 잘 모르겠어',
      followUpQuestion: candidate(
        '여행지에서 아침형 인간으로 움직이는 거랑 느긋하게 쉬는 거 중 뭐가 더 취향이야?',
      ),
    }),
    /duplicate/i,
  );
  assert.doesNotThrow(() => validateDirectQuestionAnswer(travelContext, {
    status: 'insufficient',
    text: '아직 확인된 내용이 없어서 잘 모르겠어',
    followUpQuestion: candidate(
      '여행지에서 가장 기대하는 순간은 언제야?',
    ),
  }));

  assert.throws(
    () => validateDirectQuestionAnswer({
      ...directQuestionContext,
      questionText: '상대방은 해외여행을 선호할까, 국내여행을 선호할까?',
      recentSharedQuestionTexts: [],
    }, {
      status: 'insufficient',
      text: '아직 확인된 내용이 없어서 잘 모르겠어',
      followUpQuestion: candidate(
        '해외여행을 선호하는 쪽이 더 많아, 국내여행을 선호하는 쪽이 더 많아?',
      ),
    }),
    /unnatural_question/i,
  );

  const travelTypeContext: DirectQuestionContext = {
    ...directQuestionContext,
    questionText: '상대방은 해외여행을 선호할까, 국내여행을 선호할까?',
    recentSharedQuestionTexts: [],
  };
  assert.throws(
    () => validateDirectQuestionFollowUp(
      travelTypeContext,
      candidate('여행지에서 해외여행이 좋아, 국내여행이 좋아?'),
    ),
    /unnatural_question/i,
  );
  assert.doesNotThrow(() => validateDirectQuestionFollowUp(
    travelTypeContext,
    candidate('해외여행이 좋아, 국내여행이 좋아?'),
  ));
});

test('생성 질문은 실제 질문 형식으로 끝나야 한다', () => {
  const candidate = {
    questionKey: 'personalized_generated_ab12cd34',
    text: '다음에 편하게 말할 수 있는 일상 패턴 하나를 알려줘',
    category: 'daily_life',
    mood: null,
    rationale: '아직 확인하지 않은 일상 패턴을 알아보기 위해서야',
  };

  assert.throws(
    () => validatePersonalizedQuestion(candidate),
    /question mark/i,
  );
  assert.doesNotThrow(() => validatePersonalizedQuestion({
    ...candidate,
    text: '평소에 가장 편안한 일상은 어떤 모습이야?',
  }));
});

test('proactive suggestions enforce card, weather, and tone boundaries', () => {
  const proactiveContext = {
    localDate: '2026-07-24',
    localHour: 18,
    hasCardToday: false,
    confirmedMemories: [],
    recentCompletedQuestions: [],
    weather: {
      condition: 'clear' as const,
      apparentTemperatureC: 24,
      precipitationPossible: false,
      nearSunset: true,
      sunsetLocalTime: '19:42',
    },
  };

  assert.doesNotThrow(() =>
    validateProactiveSuggestion(proactiveContext, {
      text: '곧 노을 질 시간인데 하늘이 괜찮다면 사진을 카드로 남겨도 예쁘겠다',
      kind: 'sunset_card',
    })
  );
  assert.doesNotThrow(() =>
    validateProactiveSuggestion(proactiveContext, {
      text: '노을 질 시간에 천천히 걸으며 예쁜 하늘을 사진으로 남겨 카드로 만들어보는 건 어때?',
      kind: 'sunset_card',
    })
  );
  assert.throws(
    () => validateProactiveSuggestion(proactiveContext, {
      text: '곧 노을 질 시간이니 예쁜 하늘 사진을 한 장 찍어서 카드로 남겨!',
      kind: 'sunset_card',
    }),
    (error: unknown) =>
      error instanceof ProactiveSuggestionValidationError
      && error.code === 'commanding_expression',
  );
  assert.throws(
    () => validateProactiveSuggestion(proactiveContext, {
      text: '노을 질 시간이라 가볍게 밖으로 나가 천천히 걷고 사진도 남겨 보자',
      kind: 'sunset_card',
    }),
    (error: unknown) =>
      error instanceof ProactiveSuggestionValidationError
      && error.code === 'commanding_expression',
  );
  assert.throws(
    () => validateProactiveSuggestion(proactiveContext, {
      text: '밖에서 함께 걸으면서 둘만의 시간을 보내는 건 어때?',
      kind: 'date_idea',
    }),
    (error: unknown) =>
      error instanceof ProactiveSuggestionValidationError
      && error.code === 'sunset_card_required',
  );
  assert.throws(() =>
    validateProactiveSuggestion(
      { ...proactiveContext, hasCardToday: true },
      {
        text: '곧 노을 질 시간인데 사진을 카드로 남기면 좋겠다',
        kind: 'sunset_card',
      },
    )
  );
  assert.throws(() =>
    validateProactiveSuggestion(proactiveContext, {
      text: '비가 오니까 가까운 실내에 가봐!',
      kind: 'date_idea',
    })
  );
  assert.throws(() =>
    validateProactiveSuggestion(proactiveContext, {
      text: '둘의 오늘을 기억 한 조각으로 남기면 좋겠다',
      kind: 'card_idea',
    })
  );
  assert.throws(
    () => validateProactiveSuggestion(proactiveContext, {
      text: '노을이 막 뜨는 시간에 같이 사진을 찍어 카드로 남기는 건 어때?',
      kind: 'sunset_card',
    }),
    (error: unknown) =>
      error instanceof ProactiveSuggestionValidationError
      && error.code === 'unnatural_expression',
  );
  assert.throws(
    () => validateProactiveSuggestion(proactiveContext, {
      text: '19:42 무렵 노을을 보며 사진 한 장 남겨 두면 어때?',
      kind: 'sunset_card',
    }),
    (error: unknown) =>
      error instanceof ProactiveSuggestionValidationError
      && error.code === 'raw_context_value',
  );
  assert.throws(
    () => validateProactiveSuggestion(
      { ...proactiveContext, weather: null },
      {
        text: '밤공기가 선선해서 둘이 가까운 곳을 천천히 걸으면 좋겠다',
        kind: 'date_idea',
      },
    ),
    (error: unknown) =>
      error instanceof ProactiveSuggestionValidationError
      && error.code === 'weather_without_context',
  );
  assert.throws(
    () => validateProactiveSuggestion(
      {
        ...proactiveContext,
        weather: {
          ...proactiveContext.weather,
          condition: 'hot',
          apparentTemperatureC: 35,
          nearSunset: false,
        },
      },
      {
        text: '오늘 날씨가 많이 더우니까 가까운 실내에서 함께 쉬는 건 어때?',
        kind: 'date_idea',
      },
    ),
    (error: unknown) =>
      error instanceof ProactiveSuggestionValidationError
      && error.code === 'weather_overstatement',
  );
  assert.throws(
    () => validateProactiveSuggestion(
      {
        ...proactiveContext,
        weather: {
          ...proactiveContext.weather,
          condition: 'cold',
          apparentTemperatureC: -4,
          nearSunset: false,
        },
      },
      {
        text: '날씨가 많이 추워졌는데 가까운 실내에서 따뜻한 차를 마시는 건 어때?',
        kind: 'date_idea',
      },
    ),
    (error: unknown) =>
      error instanceof ProactiveSuggestionValidationError
      && error.code === 'weather_overstatement',
  );
  assert.doesNotThrow(() =>
    validateProactiveSuggestion(
      {
        ...proactiveContext,
        weather: {
          ...proactiveContext.weather,
          condition: 'hot',
          apparentTemperatureC: 35,
          nearSunset: false,
        },
      },
      {
        text: '오늘은 덥게 느껴질 수 있으니 가까운 실내에서 함께 쉬면 좋겠다',
        kind: 'date_idea',
      },
    )
  );
});

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
          statement: '갈등이 생기면 빠르게 풀어가는 편이야',
          confidence: 0.9,
          evidenceAnswerIds: ['answer-a', 'unknown-answer'],
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

test('서로 다른 답변을 하나의 커플 기억으로 합치지 않는다', () => {
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
        statement: '둘 다 편안해지는 방식을 중요하게 여겨',
        confidence: 0.8,
        evidenceAnswerIds: ['answer-a', 'answer-b'],
      },
    ]),
    /couple memory requires shared answer evidence/i,
  );
});

test('두 답변에 공통으로 드러난 구체적인 커플 기억은 허용한다', () => {
  assert.doesNotThrow(() => {
    validateMemoryCandidates(
      {
        ...context,
        question: {
          ...context.question,
          text: '쉬는 날 함께 하고 싶은 건 뭐야?',
        },
        answers: [
          {
            answerId: 'answer-a',
            userId: 'user-a',
            text: '같이 공원을 산책하면 좋아',
          },
          {
            answerId: 'answer-b',
            userId: 'user-b',
            text: '주말에는 둘이 공원 산책을 하고 싶어',
          },
        ],
      },
      [
        {
          memoryKey: 'shared_park_walk',
          scope: 'couple',
          subjectUserId: null,
          kind: 'shared_activity',
          domain: 'daily_life',
          evidenceType: 'explicit',
          sensitiveCategory: 'none',
          statement: '둘 다 공원 산책을 좋아해',
          confidence: 0.88,
          evidenceAnswerIds: ['answer-a', 'answer-b'],
        },
      ],
    );
  });
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

test('기존 기억 키를 다시 사용한 명시적 후보는 반복 패턴으로 승격한다', () => {
  const repeatedContext: CompletedQuestionContext = {
    ...context,
    memoryCandidates: [
      {
        memoryKey: 'support_listening_first_user_a',
        scope: 'personal',
        subjectUserId: 'user-a',
        kind: 'support_preference',
        domain: 'emotional_support',
        evidenceType: 'explicit',
        statement: '힘든 날에는 이야기를 먼저 들어주면 좋아',
        confidence: 0.78,
        state: 'pending',
        evidenceQuestionCount: 1,
      },
    ],
  };

  const resolved = resolveMemoryCandidates(repeatedContext, [
    {
      memoryKey: 'support_listening_first_user_a',
      scope: 'personal',
      subjectParticipantKey: 'partner_a',
      kind: 'support_preference',
      domain: 'emotional_support',
      evidenceType: 'explicit',
      sensitiveCategory: 'none',
      statement: '힘든 날에는 이야기를 먼저 들어주면 좋아',
      confidence: 0.84,
      evidenceAnswerIds: ['answer-a'],
    },
  ]);

  assert.equal(resolved[0]?.evidenceType, 'repeated_pattern');
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
          statement: '확인되지 않은 사용자에 대한 기억이야',
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
      statement: '힘든 날에는 먼저 조용히 들어주면 좋아',
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

  const mixedCertaintyContext = anonymizeCompletedQuestionContext({
    ...context,
    question: {
      ...context.question,
      text: '요즘 가장 소중하게 지키고 싶은 건 뭐야?',
    },
    answers: [
      { answerId: 'answer-a', userId: 'user-a', text: '몰라' },
      { answerId: 'answer-b', userId: 'user-b', text: '시간' },
    ],
  });
  assert.throws(
    () => validateCoupleFeedback({
      text: '둘 다 모르는 게 아니라 그냥 시간이 필요한 걸 말하는 분위기네!',
    }, mixedCertaintyContext),
    (error: unknown) =>
      error instanceof CoupleFeedbackValidationError
      && error.code === 'mixed_certainty_content',
  );
  assert.doesNotThrow(() => validateCoupleFeedback({
    text: '소중한 건 바로 이름 붙을 수도, 아직 빈칸일 수도 있나 봐...',
  }, mixedCertaintyContext));

  const movieContext = anonymizeCompletedQuestionContext({
    ...context,
    question: {
      ...context.question,
      text: '주말에 둘이 같이 영화 보러 갈 때 어떤 영화 장르를 좋아해?',
    },
    answers: [
      { answerId: 'answer-a', userId: 'user-a', text: '나는 존윅같은 거 진짜 개좋아' },
      { answerId: 'answer-b', userId: 'user-b', text: '범죄,액션,스릴러~' },
    ],
  });
  assert.throws(
    () => validateCoupleFeedback({
      text: '주말에 둘이 같이 영화 보러 갈 때 어떤 영화 장르를 좋아해?',
    }, movieContext),
    (error: unknown) =>
      error instanceof CoupleFeedbackValidationError
      && error.code === 'question_echo',
  );
  assert.throws(
    () => validateCoupleFeedback({
      text: '액션 영화 좋아하네, 둘이서도 즐길 만하겠어...',
    }, movieContext),
    (error: unknown) =>
      error instanceof CoupleFeedbackValidationError
      && error.code === 'answer_restatement',
  );
  assert.throws(
    () => validateCoupleFeedback({
      text: '이번 주말에도 액션 영화로 소파가 바빠지겠네!',
    }, movieContext),
    (error: unknown) =>
      error instanceof CoupleFeedbackValidationError
      && error.code === 'ungrounded_detail',
  );
  assert.throws(
    () => validateCoupleFeedback({
      text: '액션 영화로 소파가 바빠지겠네!',
    }, movieContext),
    (error: unknown) =>
      error instanceof CoupleFeedbackValidationError
      && error.code === 'ungrounded_detail',
  );
  assert.doesNotThrow(() => validateCoupleFeedback({
    text: '영화 고를 때만큼은 둘의 고민이 오래 걸리지 않겠네!',
  }, movieContext));

  const sofaContext = anonymizeCompletedQuestionContext({
    ...context,
    question: {
      ...context.question,
      text: '집에서 영화 볼 때 가장 편한 자리는 어디야?',
    },
    answers: [
      { answerId: 'answer-a', userId: 'user-a', text: '거실 소파' },
      { answerId: 'answer-b', userId: 'user-b', text: '나도 소파가 좋아' },
    ],
  });
  assert.doesNotThrow(() => validateCoupleFeedback({
    text: '영화 틀면 소파 자리부터 금방 차겠네!',
  }, sofaContext));

  const personalizedMovieContext = {
    ...movieContext,
    foundationProgress: {
      ...movieContext.foundationProgress,
      personalizationEnabled: true,
    },
    confirmedMemories: [
      {
        memoryKey: 'shared_movie_routine',
        scope: 'couple' as const,
        subjectParticipantKey: null,
        kind: 'shared_activity',
        domain: 'daily_life' as const,
        evidenceType: 'repeated_pattern' as const,
        statement: '주말마다 함께 영화를 고르면 이야기가 길어져',
        confidence: 0.9,
      },
    ],
  };
  assert.doesNotThrow(() => validateCoupleFeedback({
    text: '영화 이야기는 또 금방 길어지겠네!',
  }, personalizedMovieContext));

  assert.throws(
    () => validateCoupleFeedback({
      text: '이번 주말엔 존윅 같은 액션 영화를 같이 보자!',
    }, movieContext),
    (error: unknown) =>
      error instanceof CoupleFeedbackValidationError
      && error.code === 'advice_or_command',
  );

  const noPreferenceContext = anonymizeCompletedQuestionContext({
    ...context,
    question: {
      ...context.question,
      text: '요즘 둘이 새로 해보고 싶은 게 있어?',
    },
    answers: [
      { answerId: 'answer-a', userId: 'user-a', text: '딱히 없어' },
      { answerId: 'answer-b', userId: 'user-b', text: '잘 모르겠어' },
    ],
  });
  assert.throws(
    () => validateCoupleFeedback({
      text: '둘 다 바빠서 새로운 걸 생각할 여유가 없나 보네',
    }, noPreferenceContext),
    (error: unknown) =>
      error instanceof CoupleFeedbackValidationError
      && error.code === 'unsupported_inference',
  );

  assert.throws(
    () => validateCoupleFeedback({
      text: '좋은 문장이야 규칙에 맞게 잘 작성됐어',
    }, movieContext),
    (error: unknown) =>
      error instanceof CoupleFeedbackValidationError
      && error.code === 'instruction_leak',
  );

  const heavyDayContext = anonymizeCompletedQuestionContext({
    ...context,
    question: {
      ...context.question,
      text: '오늘 마음에 가장 오래 남은 일은 뭐야?',
    },
    answers: [
      { answerId: 'answer-a', userId: 'user-a', text: '회사에서 버티기 힘들었어' },
      { answerId: 'answer-b', userId: 'user-b', text: '오늘은 아무 말도 하기 싫었어' },
    ],
  });
  assert.throws(
    () => validateCoupleFeedback({
      text: '오늘은 둘 다 힘들었네',
    }, heavyDayContext),
    (error: unknown) =>
      error instanceof CoupleFeedbackValidationError
      && error.code === 'answer_restatement',
  );
});

test('한 줄 피드백은 내용 검증 전에 문장부호만 안전하게 복구할 수 있다', () => {
  const repaired = repairCoupleFeedbackPunctuation({
    text: '이야기도 한 장면 더 생겼네. 같이 웃으면 더 재밌겠어!',
  });

  assert.deepEqual(repaired, {
    text: '이야기도 한 장면 더 생겼네 같이 웃으면 더 재밌겠어!',
  });
  assert.doesNotThrow(() => validateCoupleFeedback(repaired!, context));
  assert.equal(repairCoupleFeedbackPunctuation({
    text: '이야기도 한 장면 더 생겼네!',
  }), null);
});

test('개인화 질문은 사용자에게 분석 과정을 요구하지 않는다', () => {
  assert.throws(
    () => validatePersonalizedQuestion({
      questionKey: 'personalized_generated_meta_ab12cd34',
      text: '다음 주말에 서로의 평소 패턴이 어떻게 맞는지 확인해보려면 어떤 방식이 좋을까?',
      category: 'daily_life',
      mood: null,
      rationale: '두 사람의 일상 패턴을 확인하기 위해',
    }),
    (error: unknown) =>
      error instanceof PersonalizedQuestionValidationError
      && error.code === 'meta_language',
  );

  assert.doesNotThrow(() => validatePersonalizedQuestion({
    questionKey: 'personalized_generated_weekend_ab12cd34',
    text: '둘이 함께 새로 해보고 싶은 건 뭐야?',
    category: 'daily_life',
    mood: null,
    rationale: '요즘 함께하고 싶은 일을 알아보기 위해',
  }));
});

test('개인화 질문은 대기 중 의미가 바뀌는 상대 시간 표현을 사용하지 않는다', () => {
  for (const text of [
    '오늘 둘이 같이 먹고 싶은 메뉴는 뭐야?',
    '다음 주말에 둘이 같이 가고 싶은 곳은 어디야?',
  ]) {
    assert.throws(
      () => validatePersonalizedQuestion({
        questionKey: 'personalized_generated_volatile_ab12cd34',
        text,
        category: 'daily_life',
        mood: null,
        rationale: '함께하고 싶은 일을 알아보기 위해',
      }),
      (error: unknown) =>
        error instanceof PersonalizedQuestionValidationError
        && error.code === 'volatile_time_reference',
    );
  }

  assert.doesNotThrow(() => validatePersonalizedQuestion({
    questionKey: 'personalized_generated_stable_ab12cd34',
    text: '주말에 둘이 같이 가고 싶은 곳은 어디야?',
    category: 'daily_life',
    mood: null,
    rationale: '함께 가고 싶은 곳을 알아보기 위해',
  }));
});

test('개인화 질문은 대상에 맞지 않는 포괄 동사를 사용하지 않는다', () => {
  assert.throws(
    () => validatePersonalizedQuestion({
      questionKey: 'personalized_generated_movie_ab12cd34',
      text: '둘이 같이 해보고 싶은 영화는 뭐야?',
      category: 'daily_life',
      mood: null,
      rationale: '함께 보고 싶은 영화를 알아보기 위해',
    }),
    (error: unknown) =>
      error instanceof PersonalizedQuestionValidationError
      && error.code === 'unnatural_question',
  );

  assert.doesNotThrow(() => validatePersonalizedQuestion({
    questionKey: 'personalized_generated_movie_cd34ef56',
    text: '둘이 같이 보고 싶은 영화는 뭐야?',
    category: 'daily_life',
    mood: null,
    rationale: '함께 보고 싶은 영화를 알아보기 위해',
  }));
});

test('개인화 질문은 현재 질문이나 최근 질문을 표현만 바꿔 반복하지 않는다', () => {
  const candidate = {
    questionKey: 'personalized_generated_movie_ab12cd34',
    text: '다음 주말에 둘이 같이 영화 보러 갈 때 어떤 영화 장르를 좋아해?',
    category: 'daily_life',
    mood: null,
    rationale: '함께 보고 싶은 영화 취향을 더 알아보기 위해',
  };
  const personalizedContext = {
    ...context,
    question: {
      ...context.question,
      text: '주말에 둘이 같이 영화 보러 갈 때 어떤 영화 장르를 좋아해?',
    },
    recentCompletedQuestions: [{
      question: {
        dailyQuestionId: 'daily-question-previous',
        text: '다음 주말에 둘이 같이 해보고 싶은 건 뭐야?',
        domain: 'daily_life' as const,
      },
      answers: [],
    }],
  };

  assert.throws(
    () => validatePersonalizedQuestion(candidate, personalizedContext),
    (error: unknown) =>
      error instanceof PersonalizedQuestionValidationError
      && error.code === 'duplicate_question',
  );
  assert.doesNotThrow(() => validatePersonalizedQuestion({
    ...candidate,
    text: '둘이 영화를 볼 때 극장이 좋아, 집이 좋아?',
  }, personalizedContext));
});

test('개인화 질문은 최근 노출 질문과 대기 후보의 주제를 되풀이하지 않는다', () => {
  const historyContext = {
    ...context,
    question: {
      ...context.question,
      text: '산이 좋아, 바다가 좋아?',
    },
    recentExposedQuestionTexts: [
      '주말에 둘이 같이 영화 보러 갈 때 어떤 영화 장르를 좋아해?',
    ],
    pendingQuestionTexts: [
      '기념일에 둘이 서로 주고 싶은 선물은 뭐야?',
    ],
  };

  for (const text of [
    '둘이 영화를 볼 때 극장이 좋아, 집이 좋아?',
    '둘이 받고 싶은 선물은 뭐야?',
  ]) {
    assert.throws(
      () => validatePersonalizedQuestion({
        questionKey: 'personalized_generated_topic_ab12cd34',
        text,
        category: 'daily_life',
        mood: null,
        rationale: '아직 모르는 선호를 알아보기 위해',
      }, historyContext),
      (error: unknown) =>
        error instanceof PersonalizedQuestionValidationError
        && error.code === 'repeated_topic',
    );
  }

  assert.doesNotThrow(() => validatePersonalizedQuestion({
    questionKey: 'personalized_generated_meal_cd34ef56',
    text: '앱 테스트를 끝내고 둘이 먹고 싶은 메뉴는 뭐야?',
    category: 'daily_life',
    mood: null,
    rationale: '직전 답변의 식사 단서를 이어가기 위해',
  }, historyContext));
});

test('개인화 질문 메타데이터에는 내부 판단 단계가 노출되지 않는다', () => {
  assert.throws(
    () => validatePersonalizedQuestion({
      questionKey: 'personalized_generated_strategy_ab12cd34',
      text: '앱 테스트를 끝내고 둘이 먹고 싶은 메뉴는 뭐야?',
      category: 'CONTINUE',
      mood: null,
      rationale: '직전 답변의 단서를 이어가기 위해',
    }),
    (error: unknown) =>
      error instanceof PersonalizedQuestionValidationError
      && error.code === 'strategy_leak',
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
