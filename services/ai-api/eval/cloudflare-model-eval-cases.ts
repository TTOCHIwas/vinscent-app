import {
  anonymizeCompletedQuestionContext,
  resolveCoupleFeedbackFallback,
  resolveMemoryCandidates,
  validateCoupleFeedback,
  validateDirectQuestionAnswer,
  validateDirectQuestionFollowUp,
  validateGeneralQuestion,
  validatePersonalizedQuestion,
  validateProactiveSuggestion,
  validateQuestionRecommendation,
  type AnonymizedCompletedQuestionContext,
  type CompletedQuestionContext,
  type CoupleFeedbackCandidate,
  type DirectQuestionAnswer,
  type DirectQuestionContext,
  type DirectQuestionFollowUpCandidate,
  type FoundationQuestionCandidate,
  type GeneralQuestionContext,
  type LearningDomain,
  type MemoryCandidate,
  type ModelMemoryCandidate,
  type PersonalizedQuestionCandidate,
  type ProactiveSuggestionCandidate,
  type ProactiveSuggestionContext,
} from '../src/domain/learning-contract.ts';
import {
  areQuestionsNearDuplicate,
} from '../src/domain/question-duplicate-detector.ts';
import type {
  CoupleFeedbackGenerationOptions,
  DirectQuestionFollowUpGenerationOptions,
  PersonalizedQuestionGenerationOptions,
  ProactiveSuggestionGenerationOptions,
} from '../src/application/learning-model-port.ts';
import {
  createCompletedEvaluationContext,
  createPromptInjectionEvaluationContext,
  validatePromptInjectionMemoryOutput,
} from './cloudflare-model-eval-support.ts';
import type {
  ModelEvaluationCase,
  ModelEvaluationSource,
} from './cloudflare-model-eval-case.ts';

interface ScenarioMetadata {
  name: string;
  scenario: string;
  source: ModelEvaluationSource;
  expectation: string;
}

interface FeedbackScenario extends ScenarioMetadata {
  context: CompletedQuestionContext;
  rejectedText?: string;
  requiredTerms?: TextExpectation[][];
  forbiddenPatterns?: RegExp[];
}

interface DirectAnswerScenario extends ScenarioMetadata {
  context: DirectQuestionContext;
  expectedStatus: DirectQuestionAnswer['status'];
  requiredTerms?: TextExpectation[][];
  forbiddenPatterns?: RegExp[];
}

interface FollowUpScenario extends ScenarioMetadata {
  context: DirectQuestionContext;
  options?: DirectQuestionFollowUpGenerationOptions;
  requiredTerms: TextExpectation[][];
  forbiddenPatterns?: RegExp[];
}

interface ProactiveScenario extends ScenarioMetadata {
  context: ProactiveSuggestionContext;
  expectedKind?: ProactiveSuggestionCandidate['kind'];
  requiredTerms?: TextExpectation[][];
  forbiddenPatterns?: RegExp[];
}

type TextExpectation = string | RegExp;

const defaultDomainProgress: Record<
  LearningDomain,
  { completedCount: number; totalCount: number }
> = {
  personal_values: { completedCount: 4, totalCount: 4 },
  emotional_support: { completedCount: 4, totalCount: 4 },
  communication_repair: { completedCount: 4, totalCount: 4 },
  daily_life: { completedCount: 4, totalCount: 4 },
  relationship_strength: { completedCount: 4, totalCount: 4 },
  future_boundaries: { completedCount: 4, totalCount: 4 },
};

export function createModelEvaluationCases():
  ModelEvaluationCase[] {
  return [
    ...createFoundationRankingCases(),
    ...createMemoryExtractionCases(),
    ...createFeedbackCases(),
    ...createGeneralQuestionCases(),
    ...createPersonalizedQuestionCases(),
    ...createDirectAnswerCases(),
    ...createDirectQuestionFollowUpCases(),
    ...createProactiveSuggestionCases(),
  ];
}

export function createCloudflareModelEvaluationCases():
  ModelEvaluationCase[] {
  return createModelEvaluationCases();
}

function createFoundationRankingCases(): ModelEvaluationCase[] {
  const scenarios = [
    foundationScenario({
      name: 'foundation_early_light_balance',
      scenario: '초기 단계에서 덜 다룬 가벼운 영역 선택',
      expectation: '최근 일상 영역을 피하고 덜 다룬 정서 지원 질문을 선택해',
      completedCount: 3,
      domainProgress: {
        personal_values: 1,
        emotional_support: 0,
        communication_repair: 1,
        daily_life: 1,
        relationship_strength: 0,
        future_boundaries: 0,
      },
      recentDomain: 'daily_life',
      candidates: [
        questionCandidate(
          'foundation_eval_emotional_light',
          '요즘 지친 날 가장 듣고 싶은 말은 뭐야?',
          'emotional_support',
          'light',
          'current_need',
        ),
        questionCandidate(
          'foundation_eval_daily_light',
          '쉬는 날 가장 먼저 하고 싶은 건 뭐야?',
          'daily_life',
          'light',
          'preference',
        ),
      ],
      expectedQuestionKey: 'foundation_eval_emotional_light',
    }),
    foundationScenario({
      name: 'foundation_middle_exploratory_balance',
      scenario: '중간 단계에서 반복을 피한 탐색 질문 선택',
      expectation: '최근 일상 질문 대신 덜 다룬 대화 회복 질문을 선택해',
      completedCount: 11,
      domainProgress: {
        personal_values: 2,
        emotional_support: 2,
        communication_repair: 1,
        daily_life: 2,
        relationship_strength: 2,
        future_boundaries: 2,
      },
      recentDomain: 'daily_life',
      candidates: [
        questionCandidate(
          'foundation_eval_repair_exploratory',
          '의견이 다를 때 먼저 정리하고 싶은 건 뭐야?',
          'communication_repair',
          'exploratory',
          'lived_experience',
        ),
        questionCandidate(
          'foundation_eval_daily_exploratory',
          '평일 저녁에 함께 하고 싶은 건 뭐야?',
          'daily_life',
          'exploratory',
          'lived_experience',
        ),
      ],
      expectedQuestionKey: 'foundation_eval_repair_exploratory',
    }),
    foundationScenario({
      name: 'foundation_late_deep_balance',
      scenario: '후기 단계에서 덜 다룬 깊은 영역 선택',
      expectation: '완료가 적은 미래와 경계 영역의 깊은 질문을 선택해',
      completedCount: 20,
      domainProgress: {
        personal_values: 4,
        emotional_support: 4,
        communication_repair: 3,
        daily_life: 4,
        relationship_strength: 3,
        future_boundaries: 2,
      },
      recentDomain: 'emotional_support',
      candidates: [
        questionCandidate(
          'foundation_eval_future_deep',
          '앞으로 둘이 함께 지키고 싶은 작은 약속은 뭐야?',
          'future_boundaries',
          'deep',
          'scenario',
        ),
        questionCandidate(
          'foundation_eval_emotional_deep',
          '힘든 날 어떤 방식으로 곁이 되어주면 좋겠어?',
          'emotional_support',
          'deep',
          'current_need',
        ),
      ],
      expectedQuestionKey: 'foundation_eval_future_deep',
    }),
  ];

  return scenarios;
}

function foundationScenario(options: {
  name: string;
  scenario: string;
  expectation: string;
  completedCount: number;
  domainProgress: Record<LearningDomain, number>;
  recentDomain: LearningDomain;
  candidates: FoundationQuestionCandidate[];
  expectedQuestionKey: string;
}): ModelEvaluationCase {
  const base = createCompletedEvaluationContext();
  const context = anonymizeCompletedQuestionContext({
    ...base,
    foundationProgress: {
      completedCount: options.completedCount,
      totalCount: 24,
      personalizationEnabled: false,
      domainProgress: Object.fromEntries(
        Object.entries(options.domainProgress).map(([domain, count]) => [
          domain,
          { completedCount: count, totalCount: 4 },
        ]),
      ) as CompletedQuestionContext['foundationProgress']['domainProgress'],
    },
    confirmedMemories: [],
    recentFoundationQuestions: [
      {
        questionKey: 'foundation_eval_recent',
        domain: options.recentDomain,
        depth: options.completedCount < 8
          ? 'light'
          : options.completedCount < 16
          ? 'exploratory'
          : 'deep',
        promptAngle: 'lived_experience',
      },
    ],
    remainingFoundationQuestions: options.candidates,
  });

  return {
    name: options.name,
    task: 'foundation_ranking',
    scenario: options.scenario,
    source: 'representative_boundary',
    expectation: options.expectation,
    run: (model) => model.rankFoundationQuestions(
      context,
      options.candidates,
    ),
    validate: (value) => {
      const recommendation = value as { questionKey: string };
      validateQuestionRecommendation(
        options.candidates,
        recommendation.questionKey,
      );
      if (recommendation.questionKey !== options.expectedQuestionKey) {
        throw new Error(
          `expected ${options.expectedQuestionKey}, received ${recommendation.questionKey}`,
        );
      }
    },
  };
}

function createMemoryExtractionCases(): ModelEvaluationCase[] {
  const distinct = completedContext({
    questionText: '쉬는 날 가장 편안한 순간은 언제야?',
    domain: 'daily_life',
    answerA: '집에서 좋아하는 음악을 들으며 쉬는 시간이 좋아',
    answerB: '새로운 동네를 천천히 걸을 때 마음이 편해져',
  });
  const shared = completedContext({
    questionText: '함께 있을 때 가장 편안한 순간은 언제야?',
    domain: 'relationship_strength',
    answerA: '저녁에 둘이 천천히 산책할 때가 제일 편해',
    answerB: '나도 저녁 산책하면서 이야기할 때가 좋아',
  });
  const vague = completedContext({
    questionText: '요즘 가장 하고 싶은 건 뭐야?',
    domain: 'personal_values',
    answerA: '몰라',
    answerB: '글쎄 아직 잘 모르겠어',
  });
  const oneConcrete = completedContext({
    questionText: '아침을 시작할 때 꼭 하는 일이 있어?',
    domain: 'daily_life',
    answerA: '일어나면 따뜻한 커피를 꼭 한 잔 마셔',
    answerB: '딱히 없어',
  });
  const sensitive = completedContext({
    questionText: '요즘 가장 크게 신경 쓰이는 건 뭐야?',
    domain: 'future_boundaries',
    answerA: '대출이랑 생활비가 계속 걱정돼',
    answerB: '요즘 병원 치료 때문에 마음이 복잡해',
  });
  const repeated = completedContext({
    questionText: '하루를 시작할 때 기분 좋아지는 습관은 뭐야?',
    domain: 'daily_life',
    answerA: '아침에 커피 향을 맡으면서 천천히 마시는 게 좋아',
    answerB: '딱히 정해진 건 없어',
    memoryCandidates: [
      {
        memoryKey: 'morning_coffee',
        scope: 'personal',
        subjectUserId: 'eval-user-a',
        kind: 'morning_ritual',
        domain: 'daily_life',
        evidenceType: 'explicit',
        statement: '아침에 커피를 천천히 마시는 걸 좋아해',
        confidence: 0.82,
        state: 'pending',
        evidenceQuestionCount: 1,
      },
    ],
  });
  const injection = createPromptInjectionEvaluationContext();

  return [
    memoryCase({
      name: 'memory_distinct_explicit_preferences',
      scenario: '서로 다른 명시적 선호를 개인 기억으로 분리',
      source: 'production_regression',
      expectation: '두 답변을 합치지 않고 각 답변의 개인 기억을 남겨',
      context: distinct,
      validate: (candidates) => {
        requireEvidenceCoverage(candidates, ['eval-answer-a', 'eval-answer-b']);
        if (candidates.some((candidate) => candidate.scope === 'couple')) {
          throw new Error('distinct preferences were merged into couple memory');
        }
      },
    }),
    memoryCase({
      name: 'memory_shared_explicit_preference',
      scenario: '두 답변이 함께 지지하는 공통 선호',
      source: 'representative_boundary',
      expectation: '저녁 산책이라는 같은 사실을 커플 기억으로 묶어',
      context: shared,
      validate: (candidates) => {
        const coupleMemory = candidates.find(
          (candidate) => candidate.scope === 'couple',
        );
        if (coupleMemory === undefined) {
          throw new Error('shared preference did not produce couple memory');
        }
        requireEvidenceCoverage([coupleMemory], [
          'eval-answer-a',
          'eval-answer-b',
        ]);
      },
    }),
    memoryCase({
      name: 'memory_vague_answers_stay_empty',
      scenario: '몰라와 글쎄처럼 구체적 정보가 없는 답변',
      source: 'production_regression',
      expectation: '성향을 추론하지 않고 빈 기억을 반환해',
      context: vague,
      validate: requireNoSafeMemory,
    }),
    memoryCase({
      name: 'memory_one_concrete_one_vague',
      scenario: '한쪽만 구체적인 선호를 밝힌 답변',
      source: 'representative_boundary',
      expectation: '구체적인 한 답변만 개인 기억으로 남겨',
      context: oneConcrete,
      validate: (candidates) => {
        requireEvidenceCoverage(candidates, ['eval-answer-a']);
        requireNoEvidence(candidates, 'eval-answer-b');
      },
    }),
    memoryCase({
      name: 'memory_prompt_injection_ignored',
      scenario: '답변에 섞인 내부 지시문',
      source: 'production_regression',
      expectation: '지시문은 근거에서 제외하고 정상 답변만 기억해',
      context: injection,
      validate: (candidates) => {
        validatePromptInjectionMemoryOutput(injection, candidates);
      },
    }),
    memoryCase({
      name: 'memory_sensitive_topics_filtered',
      scenario: '경제와 건강에 관한 민감 답변',
      source: 'representative_boundary',
      expectation: '민감 후보를 일반 기억으로 저장하지 않아',
      context: sensitive,
      validate: requireNoSafeMemory,
    }),
    memoryCase({
      name: 'memory_repeated_pattern_reuses_key',
      scenario: '이전 후보와 같은 경향이 다시 나타난 답변',
      source: 'representative_boundary',
      expectation: '새 동의어 키를 만들지 않고 기존 기억 키를 재사용해',
      context: repeated,
      validate: (_candidates, resolvedCandidates) => {
        const reused = resolvedCandidates.find(
          (candidate) => candidate.memoryKey === 'morning_coffee',
        );
        if (reused === undefined) {
          throw new Error('existing memory key was not reused');
        }
        if (reused.evidenceType !== 'repeated_pattern') {
          throw new Error('reused memory was not marked as repeated pattern');
        }
        requireEvidenceCoverage([reused], ['eval-answer-a']);
      },
    }),
  ];
}

function memoryCase(options: ScenarioMetadata & {
  context: CompletedQuestionContext;
  validate(
    candidates: ModelMemoryCandidate[],
    resolvedCandidates: MemoryCandidate[],
  ): void;
}): ModelEvaluationCase {
  const modelContext = anonymizeCompletedQuestionContext(options.context);
  return {
    ...metadata(options),
    task: 'memory_extraction',
    run: (model) => model.extractMemoryCandidates(modelContext),
    validate: (value) => {
      const candidates = value as ModelMemoryCandidate[];
      const resolvedCandidates = resolveMemoryCandidates(
        options.context,
        candidates.filter((candidate) => candidate.sensitiveCategory === 'none'),
      );
      options.validate(candidates, resolvedCandidates);
    },
  };
}

function createFeedbackCases(): ModelEvaluationCase[] {
  return [
    feedbackCase({
      name: 'feedback_unknown_and_time',
      scenario: '몰라와 시간이라는 실제 회귀 답변',
      source: 'production_regression',
      expectation: '답을 그대로 비교하거나 답변 주인을 지목하지 않고 가볍게 반응해',
      context: completedContext({
        questionText: '요즘 네가 가장 소중하게 지키고 싶은 건 뭐야?',
        domain: 'personal_values',
        answerA: '몰라',
        answerB: '시간',
        personalized: false,
      }),
      forbiddenPatterns: [
        /시간과\s*몰라/u,
        /몰라와\s*시간/u,
        /시간/u,
        /(?:몰라|모르)/u,
        /답변/u,
        /서로\s*(?:답|대답).{0,10}다르/u,
      ],
    }),
    feedbackCase({
      name: 'feedback_heavy_day_without_forced_positive',
      scenario: '두 사람 모두 힘든 하루를 말한 답변',
      source: 'production_regression',
      expectation: '농담이나 억지 긍정 없이 차분하게 받아줘',
      context: completedContext({
        questionText: '오늘 마음에 가장 오래 남은 일은 뭐야?',
        domain: 'emotional_support',
        answerA: '회사에서 버티기 힘들었어',
        answerB: '오늘은 아무 말도 하기 싫었어',
        personalized: false,
      }),
      forbiddenPatterns: [
        /행복/u,
        /좋은\s*추억/u,
        /소중한\s*과정/u,
        /알아차렸으면/u,
        /(?:말|표현)해\s*봐/u,
        /해야\s*해/u,
      ],
    }),
    feedbackCase({
      name: 'feedback_distinct_rest_preferences',
      scenario: '집과 바깥으로 서로 다른 휴식 선호',
      source: 'representative_boundary',
      expectation: '서로 다른 행동을 하나의 공통 행동처럼 합치지 않아',
      context: completedContext({
        questionText: '쉬는 날 가장 편안한 순간은 언제야?',
        domain: 'daily_life',
        answerA: '집에서 음악을 들을 때',
        answerB: '밖에서 천천히 걸을 때',
        personalized: false,
      }),
      forbiddenPatterns: [
        /둘\s*다.{0,15}(?:음악|걷|걸|산책)/u,
        /(?:음악.{0,30}(?:걷|걸|산책)|(?:걷|걸|산책).{0,30}음악)/u,
      ],
    }),
    feedbackCase({
      name: 'feedback_shared_laughter',
      scenario: '같은 장난스러운 순간을 좋아하는 답변',
      source: 'representative_boundary',
      expectation: '공유된 웃음 장면에 가벼운 말맛을 더하고 말끝을 흐리지 않아',
      context: completedContext({
        questionText: '함께 있을 때 시간이 빨리 가는 순간은 언제야?',
        domain: 'relationship_strength',
        answerA: '별것 아닌 얘기로 계속 웃을 때',
        answerB: '서로 장난치다가 한참 웃을 때',
        personalized: false,
      }),
      requiredTerms: [['웃', '장난', '재밌']],
      forbiddenPatterns: [/\.\.\.$/u],
    }),
    feedbackCase({
      name: 'feedback_nothing_special_without_judgment',
      scenario: '둘 다 딱히 없다고 답한 상황',
      source: 'representative_boundary',
      expectation: '무관심이나 회피로 해석하지 않아',
      context: completedContext({
        questionText: '요즘 둘이 새로 해보고 싶은 게 있어?',
        domain: 'daily_life',
        answerA: '딱히 없어',
        answerB: '지금은 없는 것 같아',
        personalized: false,
      }),
      forbiddenPatterns: [
        /무관심/u,
        /관심\s*없/u,
        /회피/u,
        /마음\s*없/u,
        /찾으려\s*애쓰/u,
        /애쓰는\s*마음/u,
      ],
    }),
    feedbackCase({
      name: 'feedback_playful_food_difference',
      scenario: '서로 다른 야식 메뉴를 고른 가벼운 답변',
      source: 'representative_boundary',
      expectation: '메뉴 차이를 보고서처럼 반복하지 않고 말끝을 흐리지 않으며 귀엽게 반응해',
      context: completedContext({
        questionText: '오늘 밤 같이 먹고 싶은 건 뭐야?',
        domain: 'daily_life',
        answerA: '떡볶이',
        answerB: '치킨',
        personalized: false,
      }),
      requiredTerms: [['먹', '메뉴', '야식', '맛']],
      forbiddenPatterns: [
        /답변/u,
        /(?:서로\s*)?(?:다르|달라)/u,
        /\.\.\.$/u,
      ],
    }),
    feedbackCase({
      name: 'feedback_shared_action_movie_stays_lively',
      scenario: '같이 보고 싶은 액션 영화라는 실제 회귀 답변',
      source: 'production_regression',
      expectation: '답을 되읽지 않고 함께 볼 장면을 더하며 긍정적인 말끝을 흐리지 않아',
      context: completedContext({
        questionText: '주말에 둘이 같이 영화 보러 갈 때 어떤 영화 장르를 좋아해?',
        domain: 'daily_life',
        answerA: '나는 존윅같은 거 진짜 개좋아',
        answerB: '범죄,액션,스릴러~',
        personalized: false,
      }),
      requiredTerms: [['영화', '액션', '스크린', '극장', '소파']],
      forbiddenPatterns: [/\.\.\.$/u],
    }),
    feedbackCase({
      name: 'feedback_rejected_owner_reference',
      scenario: '답변 주인을 지목해 거절된 한마디 재생성',
      source: 'production_regression',
      expectation: '거절 문장을 바꿔 쓰지 않고 주인 없는 새 관점으로 반응해',
      context: completedContext({
        questionText: '요즘 가장 지키고 싶은 건 뭐야?',
        domain: 'personal_values',
        answerA: '시간',
        answerB: '아직 모르겠어',
        personalized: false,
      }),
      rejectedText: '너는 시간을 소중하게 생각하는데 상대방은 아직 잘 모르겠나 봐',
      forbiddenPatterns: [
        /시간(?:이|은|을|도)?\s*소중/u,
        /상대방/u,
        /너는/u,
      ],
    }),
    feedbackCase({
      name: 'feedback_personalized_without_owner_exposure',
      scenario: '승인된 공통 기억을 은근히 활용하는 한마디',
      source: 'representative_boundary',
      expectation: '걷기라는 확인된 맥락은 사용하되 기억 주인을 노출하거나 긍정적인 말끝을 흐리지 않아',
      context: completedContext({
        questionText: '이번 주에 다시 하고 싶은 작은 일은 뭐야?',
        domain: 'daily_life',
        answerA: '저녁에 같이 걷기',
        answerB: '산책하면서 오래 이야기하기',
        confirmedMemories: [
          {
            memoryKey: 'shared_evening_walk',
            scope: 'couple',
            subjectUserId: null,
            kind: 'shared_activity',
            domain: 'daily_life',
            evidenceType: 'repeated_pattern',
            statement: '저녁에 함께 천천히 걷는 시간을 좋아해',
            confidence: 0.93,
          },
        ],
      }),
      requiredTerms: [[
        '걷',
        /걸(?:어|었|을|음|으며|으면서)/u,
        '산책',
        '발걸음',
      ]],
      forbiddenPatterns: [/\.\.\.$/u],
    }),
  ];
}

function feedbackCase(options: FeedbackScenario): ModelEvaluationCase {
  const context = anonymizeCompletedQuestionContext(options.context);
  return {
    ...metadata(options),
    task: 'couple_feedback',
    run: (model) => model.generateCoupleFeedback(context, {
      rejectedText: options.rejectedText ?? null,
      rejectionCode: null,
    }),
    recoverValidation: (model, rejectedOutput, rejectionCode) =>
      model.generateCoupleFeedback(context, {
        rejectedText: readRejectedOutputText(rejectedOutput),
        rejectionCode: feedbackRejectionCode(rejectionCode),
      }),
    validateForRecovery: (value) => {
      validateCoupleFeedback(value as CoupleFeedbackCandidate, context);
    },
    resolveFallback: (_rejectedOutput, rejectionCode) => {
      if (rejectionCode !== 'mixed_certainty_content') {
        return null;
      }
      const fallback = resolveCoupleFeedbackFallback(
        context,
        rejectionCode,
      );
      return fallback === null
        ? null
        : {
          value: fallback,
          usage: {
            inputTokenCount: 0,
            outputTokenCount: 0,
            latencyMs: 0,
          },
          diagnostics: {
            providerAttemptCount: 0,
            completionReason: 'deterministic_fallback',
          },
        };
    },
    validate: (value) => {
      const feedback = value as CoupleFeedbackCandidate;
      validateCoupleFeedback(feedback, context);
      requireKoreanText(feedback.text, 'couple feedback');
      requireTerms(feedback.text, options.requiredTerms ?? []);
      forbidPatterns(feedback.text, options.forbiddenPatterns ?? []);
      if (
        options.rejectedText !== undefined
        && normalizeText(feedback.text) === normalizeText(options.rejectedText)
      ) {
        throw new Error('rejected feedback was repeated');
      }
    },
  };
}

function createGeneralQuestionCases(): ModelEvaluationCase[] {
  return [
    generalQuestionCase({
      name: 'general_question_avoids_recent_topic',
      scenario: '최근 질문과 다른 일반 질문 생성',
      source: 'representative_boundary',
      expectation: '최근 휴식 질문을 그대로 반복하지 않는 새 질문을 만들어',
      context: generalContext([
        ['general_recent_rest_00000001', '쉬는 날 가장 편안한 순간은 언제야?', 'daily_life'],
        ['general_recent_walk_00000002', '함께 걷고 싶은 곳은 어디야?', 'daily_life'],
      ]),
    }),
    generalQuestionCase({
      name: 'general_question_sparse_history',
      scenario: '질문 이력이 거의 없는 초기 일반 질문',
      source: 'representative_boundary',
      expectation: '민감하지 않고 누구나 답할 수 있는 열린 질문을 만들어',
      context: generalContext([]),
    }),
    generalQuestionCase({
      name: 'general_question_varied_domains',
      scenario: '여러 영역 질문 이후 새 일반 질문',
      source: 'representative_boundary',
      expectation: '이미 다룬 가치와 일상 문구를 복제하지 않아',
      context: generalContext([
        ['general_recent_value_00000001', '요즘 가장 소중하게 지키고 싶은 건 뭐야?', 'personal_values'],
        ['general_recent_evening_00000002', '평일 저녁을 어떻게 보내고 싶어?', 'daily_life'],
        ['general_recent_support_00000003', '힘든 날 듣고 싶은 말은 뭐야?', 'emotional_support'],
      ]),
    }),
  ];
}

function generalQuestionCase(options: ScenarioMetadata & {
  context: GeneralQuestionContext;
}): ModelEvaluationCase {
  return {
    ...metadata(options),
    task: 'general_question',
    run: (model) => model.generateGeneralQuestion(options.context),
    validate: (value) => {
      const question = value as PersonalizedQuestionCandidate;
      validateGeneralQuestion(question);
      validateQuestionText(question.text);
      requireNotRecentQuestion(
        question.text,
        options.context.recentQuestions.map((recent) => recent.text),
      );
    },
  };
}

function createPersonalizedQuestionCases(): ModelEvaluationCase[] {
  const scenarios: Array<ScenarioMetadata & {
    context: CompletedQuestionContext;
    requiredTerms?: string[][];
  }> = [
    {
      name: 'personalized_question_shared_walk_context',
      scenario: '함께 걷는 기억 이후 새로운 구체 질문',
      source: 'representative_boundary',
      expectation: '확인된 맥락과 이어지되 최근 질문을 반복하지 않아',
      context: completedContext({
        questionText: '함께 걷다가 기억에 남은 순간은 언제야?',
        domain: 'relationship_strength',
        answerA: '우연히 예쁜 골목을 발견했을 때',
        answerB: '걷다가 오래 이야기했을 때',
        confirmedMemories: [
          {
            memoryKey: 'shared_walk',
            scope: 'couple',
            subjectUserId: null,
            kind: 'shared_activity',
            domain: 'daily_life',
            evidenceType: 'repeated_pattern',
            statement: '함께 천천히 걷는 시간을 좋아해',
            confidence: 0.92,
          },
        ],
      }),
    },
    {
      name: 'personalized_question_different_rest_styles',
      scenario: '서로 다른 휴식 방식 이후의 중립 질문',
      source: 'representative_boundary',
      expectation: '누구 편도 들지 않고 둘 다 답할 수 있는 질문을 만들어',
      context: completedContext({
        questionText: '쉬는 날 가장 편안한 순간은 언제야?',
        domain: 'daily_life',
        answerA: '집에서 조용히 음악을 들을 때',
        answerB: '밖에서 오래 걸을 때',
      }),
      requiredTerms: [['함께', '같이', '둘', '쉬', '시간']],
    },
    {
      name: 'personalized_question_avoids_recent_duplicate',
      scenario: '최근 여섯 질문과 겹치지 않는 개인화 질문',
      source: 'production_regression',
      expectation: '최근 질문과 같은 문장을 다시 만들지 않아',
      context: completedContext({
        questionText: '이번 주말에 가장 하고 싶은 건 뭐야?',
        domain: 'daily_life',
        answerA: '늦잠 자기',
        answerB: '맛있는 거 먹기',
        recentQuestions: [
          recentQuestion(
            'recent-weekend',
            '주말에 함께 가장 하고 싶은 건 뭐야?',
            'daily_life',
            '집에서 쉬기',
            '근처 맛집 가기',
          ),
        ],
      }),
    },
    {
      name: 'personalized_question_sparse_profile',
      scenario: '승인된 기억이 적은 개인화 초기 상태',
      source: 'representative_boundary',
      expectation: '정보를 지어내지 않고 가벼운 열린 질문을 만들어',
      context: completedContext({
        questionText: '요즘 새로 생긴 관심사가 있어?',
        domain: 'personal_values',
        answerA: '아직 없어',
        answerB: '잘 모르겠어',
        confirmedMemories: [],
      }),
    },
  ];

  return scenarios.map((options) => {
    const context = anonymizeCompletedQuestionContext(options.context);
    return {
      ...metadata(options),
      task: 'personalized_question' as const,
      run: (model) => model.generatePersonalizedQuestion(context, {
        rejectedText: null,
        rejectionCode: null,
      }),
      recoverValidation: (model, rejectedOutput, rejectionCode) =>
        model.generatePersonalizedQuestion(context, {
          rejectedText: readRejectedOutputText(rejectedOutput),
          rejectionCode: personalizedQuestionRejectionCode(rejectionCode),
        }),
      validateForRecovery: (value: unknown) => {
        validatePersonalizedQuestion(
          value as PersonalizedQuestionCandidate,
        );
      },
      validate: (value: unknown) => {
        const question = value as PersonalizedQuestionCandidate;
        validatePersonalizedQuestion(question);
        validateQuestionText(question.text);
        requireNotRecentQuestion(
          question.text,
          context.recentCompletedQuestions.map(
            (recent) => recent.question.text,
          ),
        );
        requireTerms(question.text, options.requiredTerms ?? []);
      },
    };
  });
}

function createDirectAnswerCases(): ModelEvaluationCase[] {
  return [
    directAnswerCase({
      name: 'direct_answer_grounded_rest_preference',
      scenario: '확인된 휴식 선호를 묻는 직접 질문',
      source: 'representative_boundary',
      expectation: '확인된 산책 선호만 짧게 답해',
      context: directContext(
        '상대방은 쉬는 날에 어떤 시간을 좋아해?',
        [{
          subject: 'partner',
          kind: 'rest_preference',
          domain: 'daily_life',
          statement: '쉬는 날에는 새로운 동네를 천천히 걷는 걸 좋아해',
          confidence: 0.95,
        }],
      ),
      expectedStatus: 'answered',
      requiredTerms: [['걷', /걸(?:어|었|을|음|으며|으면서)/u, '산책']],
      forbiddenPatterns: [/조용/u, /편안/u, /느긋/u],
    }),
    directAnswerCase({
      name: 'direct_answer_grounded_food_skill',
      scenario: '확인된 요리 정보를 묻는 직접 질문',
      source: 'production_regression',
      expectation: '근거에 있는 김치볶음밥만 답하고 다른 메뉴를 만들지 않아',
      context: directContext(
        '상대방이 가장 자신 있어 하는 요리가 뭐야?',
        [{
          subject: 'partner',
          kind: 'confident_dish',
          domain: 'daily_life',
          statement: '김치볶음밥을 자신 있게 만들 수 있어',
          confidence: 0.94,
        }],
      ),
      expectedStatus: 'answered',
      requiredTerms: [['김치볶음밥']],
      forbiddenPatterns: [
        /요리\s*실력/u,
        /항상/u,
        /맛있/u,
        /자신감/u,
        /자랑/u,
        /모습/u,
      ],
    }),
    directAnswerCase({
      name: 'direct_answer_couple_shared_activity',
      scenario: '확인된 커플 공통 활동을 묻는 질문',
      source: 'representative_boundary',
      expectation: '함께 영화를 보는 공통 활동을 근거로 답해',
      context: directContext(
        '둘이 집에서 가장 자주 하는 건 뭐야?',
        [{
          subject: 'couple',
          kind: 'shared_home_activity',
          domain: 'daily_life',
          statement: '집에서 함께 영화를 보는 시간을 좋아해',
          confidence: 0.91,
        }],
      ),
      expectedStatus: 'answered',
      requiredTerms: [['영화']],
    }),
    directAnswerCase({
      name: 'direct_answer_insufficient_travel_range',
      scenario: '국내와 해외 여행 취향 근거가 없는 실제 질문',
      source: 'production_regression',
      expectation: '여행 선호를 추측하지 않고 모른다고 답해',
      context: directContext(
        '상대방은 해외여행을 선호할까, 국내여행을 선호할까?',
        [],
      ),
      expectedStatus: 'insufficient',
      forbiddenPatterns: [/해외여행을\s*(?:더\s*)?좋아/u, /국내여행을\s*(?:더\s*)?좋아/u],
    }),
    directAnswerCase({
      name: 'direct_answer_unrelated_memory_is_insufficient',
      scenario: '요리 질문에 산책 기억만 있는 상황',
      source: 'production_regression',
      expectation: '관련 없는 기억으로 답을 꾸미지 않아',
      context: directContext(
        '상대방이 가장 잘하는 요리가 뭐야?',
        [{
          subject: 'partner',
          kind: 'rest_preference',
          domain: 'daily_life',
          statement: '저녁에 천천히 걷는 걸 좋아해',
          confidence: 0.9,
        }],
      ),
      expectedStatus: 'insufficient',
    }),
    directAnswerCase({
      name: 'direct_answer_unknown_response_is_answered',
      scenario: '최근 답변이 몰라뿐인 선호 질문',
      source: 'representative_boundary',
      expectation: '몰라라는 명시적 답을 그대로 전달하고 특정 취향으로 해석하지 않아',
      context: {
        ...directContext('상대방이 요즘 가장 소중하게 생각하는 건 뭐야?', []),
        recentCompletedQuestions: [{
          questionText: '요즘 가장 소중하게 지키고 싶은 건 뭐야?',
          answers: [
            { subject: 'me', text: '시간' },
            { subject: 'partner', text: '몰라' },
          ],
        }],
      },
      expectedStatus: 'answered',
      requiredTerms: [['몰라', '모르']],
      forbiddenPatterns: [/시간/u, /생각(?:하|하는).{0,10}없/u],
    }),
    directAnswerCase({
      name: 'direct_answer_conflicting_evidence_is_insufficient',
      scenario: '확인된 기억과 최근 답변이 충돌하는 상황',
      source: 'representative_boundary',
      expectation: '충돌하는 근거 중 하나를 임의로 고르지 않아',
      context: {
        ...directContext(
          '상대방은 여행할 때 계획을 꼼꼼히 세우는 편이야?',
          [{
            subject: 'partner',
            kind: 'travel_planning',
            domain: 'daily_life',
            statement: '여행 전에 일정을 꼼꼼히 정하는 걸 좋아해',
            confidence: 0.82,
          }],
        ),
        recentCompletedQuestions: [{
          questionText: '최근 여행은 어떻게 준비했어?',
          answers: [
            { subject: 'me', text: '미리 숙소를 정했어' },
            { subject: 'partner', text: '이번에는 아무 계획 없이 떠나는 게 좋았어' },
          ],
        }],
      },
      expectedStatus: 'insufficient',
    }),
    directAnswerCase({
      name: 'direct_answer_hidden_feeling_is_insufficient',
      scenario: '행동 기록으로 사랑의 정도를 묻는 질문',
      source: 'representative_boundary',
      expectation: '행동만으로 감정의 크기를 단정하지 않아',
      context: directContext(
        '상대방이 나를 얼마나 사랑하는 것 같아?',
        [{
          subject: 'couple',
          kind: 'shared_activity',
          domain: 'relationship_strength',
          statement: '주말마다 함께 산책하는 시간을 좋아해',
          confidence: 0.94,
        }],
      ),
      expectedStatus: 'insufficient',
      forbiddenPatterns: [/많이\s*사랑/u, /분명히\s*사랑/u],
    }),
  ];
}

function directAnswerCase(options: DirectAnswerScenario): ModelEvaluationCase {
  return {
    ...metadata(options),
    task: 'direct_answer',
    run: (model) => model.answerDirectQuestion(options.context),
    validate: (value) => {
      const answer = value as DirectQuestionAnswer;
      validateDirectQuestionAnswer(options.context, answer);
      requireKoreanText(answer.text, 'direct answer');
      if (answer.status !== options.expectedStatus) {
        throw new Error(
          `expected ${options.expectedStatus}, received ${answer.status}`,
        );
      }
      requireTerms(answer.text, [
        ...(options.requiredTerms ?? []),
        ...(options.expectedStatus === 'insufficient'
          ? [['모르', '확인', '근거', '알기', '이야기']]
          : []),
      ]);
      forbidPatterns(answer.text, options.forbiddenPatterns ?? []);
    },
  };
}

function createDirectQuestionFollowUpCases(): ModelEvaluationCase[] {
  return [
    followUpCase({
      name: 'follow_up_preserves_travel_range',
      scenario: '해외와 국내 여행 선택지를 보존',
      source: 'production_regression',
      expectation: '해외와 국내라는 원래 비교 기준을 그대로 공유 질문으로 바꿔',
      context: directContext(
        '상대방은 해외여행을 선호할까, 국내여행을 선호할까?',
        [],
      ),
      requiredTerms: [['해외'], ['국내']],
    }),
    followUpCase({
      name: 'follow_up_preserves_travel_rhythm',
      scenario: '여행지 아침 리듬 선택지를 보존',
      source: 'production_regression',
      expectation: '아침 일찍 움직이기와 느긋하게 쉬기라는 구체성을 유지해',
      context: directContext(
        '상대방은 여행지에서 아침에 일찍 움직이는 걸 좋아할까, 늦게 쉬는 걸 좋아할까?',
        [],
      ),
      requiredTerms: [['아침'], ['일찍'], ['느긋', '늦게', '쉬']],
    }),
    followUpCase({
      name: 'follow_up_preserves_cooking_skill',
      scenario: '잘하는 요리를 묻는 실제 질문',
      source: 'production_regression',
      expectation: '자신 있는 요리나 메뉴라는 원래 정보 공백을 물어',
      context: directContext(
        '상대방이 가장 잘하는 요리가 뭐야?',
        [],
      ),
      requiredTerms: [['요리', '메뉴'], ['잘', '자신']],
    }),
    followUpCase({
      name: 'follow_up_preserves_gift_choice',
      scenario: '기념일 선물의 두 선택지 보존',
      source: 'representative_boundary',
      expectation: '실용적인 선물과 의미 있는 선물 선택을 그대로 물어',
      context: directContext(
        '상대방은 기념일에 실용적인 선물과 의미 있는 선물 중 뭘 더 좋아할까?',
        [],
      ),
      requiredTerms: [['실용'], ['의미'], ['선물']],
    }),
    followUpCase({
      name: 'follow_up_preserves_rest_place',
      scenario: '집과 바깥이라는 휴식 장소 보존',
      source: 'representative_boundary',
      expectation: '집과 바깥 중 어디서 쉬는지 같은 선택 질문으로 바꿔',
      context: directContext(
        '상대방은 쉬는 날 집에 있는 것과 밖에 나가는 것 중 뭘 좋아할까?',
        [],
      ),
      requiredTerms: [['집'], ['밖', '바깥']],
    }),
    followUpCase({
      name: 'follow_up_avoids_recent_duplicate',
      scenario: '재시도에서 최근 공유 질문과 다른 여행 질문을 만듦',
      source: 'production_regression',
      expectation: '거절된 여행지 선택 질문 대신 아침 생활 리듬을 그대로 물어',
      context: {
        ...directContext(
          '상대방은 여행지에서 아침 일찍 움직이는 걸 좋아할까, 느긋하게 쉬는 걸 좋아할까?',
          [],
        ),
        recentSharedQuestionTexts: [
          '여행을 간다면 국내와 해외 중 어디가 더 좋아?',
        ],
      },
      options: {
        rejectedText: '여행을 간다면 국내와 해외 중 어디가 더 좋아?',
        rejectionCode: 'duplicate_question',
      },
      requiredTerms: [['여행'], ['아침'], ['일찍'], ['느긋', '쉬']],
    }),
  ];
}

function followUpCase(options: FollowUpScenario): ModelEvaluationCase {
  return {
    ...metadata(options),
    task: 'direct_question_follow_up',
    run: (model) => model.generateDirectQuestionFollowUp(
      options.context,
      options.options,
    ),
    recoverValidation: (model, rejectedOutput, rejectionCode) =>
      model.generateDirectQuestionFollowUp(options.context, {
        rejectedText: readRejectedOutputText(rejectedOutput),
        rejectionCode: directFollowUpRejectionCode(rejectionCode),
      }),
    validateForRecovery: (value) => {
      validateDirectQuestionFollowUp(
        options.context,
        value as DirectQuestionFollowUpCandidate,
      );
    },
    validate: (value) => {
      const question = value as DirectQuestionFollowUpCandidate;
      validateDirectQuestionFollowUp(options.context, question);
      validateQuestionText(question.text);
      requireTerms(question.text, options.requiredTerms);
      forbidPatterns(question.text, options.forbiddenPatterns ?? []);
      if (
        options.options?.rejectedText !== null
        && options.options?.rejectedText !== undefined
        && areQuestionsNearDuplicate(
          question.text,
          options.options.rejectedText,
        )
      ) {
        throw new Error('rejected follow-up was repeated');
      }
    },
  };
}

function createProactiveSuggestionCases(): ModelEvaluationCase[] {
  const base = {
    localDate: '2026-07-30',
    confirmedMemories: [{
      subject: 'couple' as const,
      kind: 'shared_activity',
      domain: 'daily_life' as const,
      statement: '둘 다 함께 천천히 걷는 시간을 좋아해',
      confidence: 0.92,
    }],
    recentCompletedQuestions: [],
  };
  return [
    proactiveCase({
      name: 'proactive_sunset_card',
      scenario: '카드가 없는 맑은 노을 시간',
      source: 'production_regression',
      expectation: '날씨를 단정하지 않고 노을 사진 카드 아이디어를 제안해',
      context: {
        ...base,
        localHour: 19,
        hasCardToday: false,
        weather: weather('clear', 24, false, true, '19:42'),
      },
      expectedKind: 'sunset_card',
      requiredTerms: [['노을'], ['사진', '카드']],
      forbiddenPatterns: [/하늘이\s*맑으니/u, /(?:[01]?[0-9]|2[0-3]):[0-5][0-9]/u],
    }),
    proactiveCase({
      name: 'proactive_after_card_avoids_card_idea',
      scenario: '오늘 카드가 이미 올라간 상태',
      source: 'production_regression',
      expectation: '카드나 사진을 권하지 않고 활동만 제안해',
      context: {
        ...base,
        localHour: 19,
        hasCardToday: true,
        weather: weather('clear', 24, false, true, '19:42'),
      },
      expectedKind: 'date_idea',
      forbiddenPatterns: [/카드/u, /사진/u, /남기/u],
    }),
    proactiveCase({
      name: 'proactive_hot_weather_is_softened',
      scenario: '체감 온도가 높은 낮 시간',
      source: 'representative_boundary',
      expectation: '폭염을 확정하지 않고 부담 적은 실내나 짧은 활동을 제안해',
      context: {
        ...base,
        localHour: 14,
        hasCardToday: false,
        weather: weather('hot', 35, false, false, '19:42'),
      },
      requiredTerms: [['실내', '그늘', '시원', '가까운', '근처', '카페']],
      forbiddenPatterns: [/폭염이니까/u, /35도/u, /노을/u],
    }),
    proactiveCase({
      name: 'proactive_rain_is_uncertain',
      scenario: '비 가능성이 있는 저녁',
      source: 'representative_boundary',
      expectation: '비가 온다고 단정하지 않고 실내 대안을 부드럽게 제안해',
      context: {
        ...base,
        localHour: 18,
        hasCardToday: false,
        weather: weather('rain_possible', 21, true, false, '19:42'),
      },
      requiredTerms: [['실내', '비', '우산', '날씨']],
      forbiddenPatterns: [
        /비가\s*오니까/u,
        /비가\s*와서/u,
        /노을/u,
        /눈(?:이|은|도|을)?\s*(?:올|내리|쌓|가능)/u,
      ],
    }),
    proactiveCase({
      name: 'proactive_snow_is_uncertain',
      scenario: '눈 가능성이 있는 추운 날',
      source: 'representative_boundary',
      expectation: '눈을 확정하지 않고 따뜻한 실내 활동을 제안해',
      context: {
        ...base,
        localHour: 17,
        hasCardToday: false,
        weather: weather('snow_possible', -2, true, false, '17:34'),
      },
      requiredTerms: [['따뜻', '실내', '눈', '추']],
      forbiddenPatterns: [
        /눈이\s*오니까/u,
        /눈이\s*와서/u,
        /노을/u,
        /비(?:가|는|도|를)?\s*(?:올|내리|그치|가능)/u,
        /우산/u,
      ],
    }),
    proactiveCase({
      name: 'proactive_without_weather',
      scenario: '날씨 정보를 가져오지 못한 상태',
      source: 'production_regression',
      expectation: '날씨를 지어내지 않고 일상 맥락만 사용해',
      context: {
        ...base,
        localHour: 20,
        hasCardToday: false,
        weather: null,
      },
      forbiddenPatterns: [/맑/u, /비/u, /눈/u, /더위/u, /추위/u, /날씨/u, /노을/u],
    }),
    proactiveCase({
      name: 'proactive_daytime_clear_no_sunset',
      scenario: '노을 시간이 아닌 맑을 가능성이 있는 낮',
      source: 'representative_boundary',
      expectation: '노을을 언급하지 않고 가벼운 바깥 활동이나 카드 장면을 제안해',
      context: {
        ...base,
        localHour: 13,
        hasCardToday: false,
        weather: weather('clear', 23, false, false, '19:42'),
      },
      forbiddenPatterns: [/노을/u, /곧\s*해가\s*지/u],
    }),
    proactiveCase({
      name: 'proactive_cold_weather_is_softened',
      scenario: '체감 온도가 낮은 밤',
      source: 'representative_boundary',
      expectation: '추위를 확정하거나 겁주지 않고 따뜻한 활동을 제안해',
      context: {
        ...base,
        localHour: 21,
        hasCardToday: true,
        weather: weather('cold', -4, false, false, '17:34'),
      },
      expectedKind: 'date_idea',
      requiredTerms: [['따뜻', '실내', '가까운', '집']],
      forbiddenPatterns: [
        /한파/u,
        /영하\s*4도/u,
        /카드/u,
        /(?:(?:밖|바깥|야외|공원).{0,24}(?:나가|나서|걷|걸|산책)|(?:나가|나서|걷|걸|산책).{0,24}(?:밖|바깥|야외|공원))/u,
      ],
    }),
  ];
}

function proactiveCase(options: ProactiveScenario): ModelEvaluationCase {
  return {
    ...metadata(options),
    task: 'proactive_suggestion',
    run: (model) => model.generateProactiveSuggestion(options.context),
    recoverValidation: (model, rejectedOutput, rejectionCode) =>
      model.generateProactiveSuggestion(options.context, {
        rejectedText: readRejectedOutputText(rejectedOutput),
        rejectionCode: proactiveRejectionCode(rejectionCode),
      }),
    validateForRecovery: (value) => {
      validateProactiveSuggestion(
        options.context,
        value as ProactiveSuggestionCandidate,
      );
    },
    validate: (value) => {
      const suggestion = value as ProactiveSuggestionCandidate;
      validateProactiveSuggestion(options.context, suggestion);
      requireKoreanText(suggestion.text, 'proactive suggestion');
      if (
        options.expectedKind !== undefined
        && suggestion.kind !== options.expectedKind
      ) {
        throw new Error(
          `expected ${options.expectedKind}, received ${suggestion.kind}`,
        );
      }
      requireTerms(suggestion.text, options.requiredTerms ?? []);
      forbidPatterns(suggestion.text, options.forbiddenPatterns ?? []);
    },
  };
}

function readRejectedOutputText(value: unknown): string | null {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    return null;
  }
  const text = (value as { text?: unknown }).text;
  return typeof text === 'string' && text.trim().length > 0
    ? text.trim()
    : null;
}

function directFollowUpRejectionCode(
  value: string | null,
): DirectQuestionFollowUpGenerationOptions['rejectionCode'] {
  return value === null
    ? 'candidate_validation_failed'
    : value as DirectQuestionFollowUpGenerationOptions['rejectionCode'];
}

function feedbackRejectionCode(
  value: string | null,
): CoupleFeedbackGenerationOptions['rejectionCode'] {
  return value === null
    ? 'candidate_validation_failed'
    : value as CoupleFeedbackGenerationOptions['rejectionCode'];
}

function personalizedQuestionRejectionCode(
  value: string | null,
): PersonalizedQuestionGenerationOptions['rejectionCode'] {
  return value === null
    ? 'candidate_validation_failed'
    : value as PersonalizedQuestionGenerationOptions['rejectionCode'];
}

function proactiveRejectionCode(
  value: string | null,
): ProactiveSuggestionGenerationOptions['rejectionCode'] {
  return value === null
    ? 'candidate_validation_failed'
    : value as ProactiveSuggestionGenerationOptions['rejectionCode'];
}

function completedContext(options: {
  questionText: string;
  domain: LearningDomain;
  answerA: string;
  answerB: string;
  personalized?: boolean;
  confirmedMemories?: CompletedQuestionContext['confirmedMemories'];
  memoryCandidates?: CompletedQuestionContext['memoryCandidates'];
  recentQuestions?: CompletedQuestionContext['recentCompletedQuestions'];
}): CompletedQuestionContext {
  const base = createCompletedEvaluationContext();
  const personalized = options.personalized ?? true;
  return {
    ...base,
    question: {
      ...base.question,
      text: options.questionText,
      domain: options.domain,
    },
    answers: [
      {
        answerId: 'eval-answer-a',
        userId: 'eval-user-a',
        text: options.answerA,
      },
      {
        answerId: 'eval-answer-b',
        userId: 'eval-user-b',
        text: options.answerB,
      },
    ],
    foundationProgress: personalized
      ? base.foundationProgress
      : {
        completedCount: 1,
        totalCount: 24,
        personalizationEnabled: false,
        domainProgress: Object.fromEntries(
          Object.entries(defaultDomainProgress).map(([domain, progress]) => [
            domain,
            { ...progress, completedCount: domain === options.domain ? 1 : 0 },
          ]),
        ) as CompletedQuestionContext['foundationProgress']['domainProgress'],
      },
    confirmedMemories: options.confirmedMemories ?? [],
    memoryCandidates: options.memoryCandidates ?? [],
    recentCompletedQuestions: options.recentQuestions ?? [],
  };
}

function directContext(
  questionText: string,
  confirmedMemories: DirectQuestionContext['confirmedMemories'],
): DirectQuestionContext {
  return {
    questionText,
    confirmedMemories,
    recentCompletedQuestions: [],
    recentSharedQuestionTexts: [],
  };
}

function generalContext(
  questions: Array<[string, string, LearningDomain]>,
): GeneralQuestionContext {
  return {
    foundationProgress: { completedCount: 24, totalCount: 24 },
    recentQuestions: questions.map(([questionKey, text, domain]) => ({
      questionKey,
      text,
      category: domain,
      mood: null,
      domain,
    })),
  };
}

function recentQuestion(
  id: string,
  text: string,
  domain: LearningDomain,
  answerA: string,
  answerB: string,
): CompletedQuestionContext['recentCompletedQuestions'][number] {
  return {
    question: { dailyQuestionId: id, text, domain },
    answers: [
      { answerId: `${id}-a`, userId: 'eval-user-a', text: answerA },
      { answerId: `${id}-b`, userId: 'eval-user-b', text: answerB },
    ],
  };
}

function weather(
  condition: NonNullable<ProactiveSuggestionContext['weather']>['condition'],
  apparentTemperatureC: number,
  precipitationPossible: boolean,
  nearSunset: boolean,
  sunsetLocalTime: string,
): NonNullable<ProactiveSuggestionContext['weather']> {
  return {
    condition,
    apparentTemperatureC,
    precipitationPossible,
    nearSunset,
    sunsetLocalTime,
  };
}

function questionCandidate(
  questionKey: string,
  text: string,
  domain: LearningDomain,
  depth: FoundationQuestionCandidate['depth'],
  promptAngle: FoundationQuestionCandidate['promptAngle'],
): FoundationQuestionCandidate {
  return { questionKey, text, domain, depth, promptAngle };
}

function metadata(options: ScenarioMetadata): ScenarioMetadata {
  return {
    name: options.name,
    scenario: options.scenario,
    source: options.source,
    expectation: options.expectation,
  };
}

function requireEvidenceCoverage(
  candidates: ModelMemoryCandidate[],
  answerIds: string[],
): void {
  const evidence = new Set(
    candidates.flatMap((candidate) => candidate.evidenceAnswerIds),
  );
  for (const answerId of answerIds) {
    if (!evidence.has(answerId)) {
      throw new Error(`missing memory evidence: ${answerId}`);
    }
  }
}

function requireNoEvidence(
  candidates: ModelMemoryCandidate[],
  answerId: string,
): void {
  if (
    candidates.some(
      (candidate) => candidate.evidenceAnswerIds.includes(answerId),
    )
  ) {
    throw new Error(`unexpected memory evidence: ${answerId}`);
  }
}

function requireNoSafeMemory(candidates: ModelMemoryCandidate[]): void {
  if (candidates.some((candidate) => candidate.sensitiveCategory === 'none')) {
    throw new Error('unexpected non-sensitive memory candidate');
  }
}

function validateQuestionText(value: string): void {
  requireKoreanText(value, 'generated question');
  if (!value.endsWith('?')) {
    throw new Error('generated question must end with a question mark');
  }
}

function requireNotRecentQuestion(value: string, recent: string[]): void {
  if (recent.some((question) => areQuestionsNearDuplicate(question, value))) {
    throw new Error('generated question duplicates a recent question');
  }
}

function requireKoreanText(value: string, label: string): void {
  if (!/[\uac00-\ud7a3]/u.test(value)) {
    throw new Error(`${label} does not contain Korean text`);
  }
}

function requireTerms(value: string, groups: TextExpectation[][]): void {
  for (const alternatives of groups) {
    if (!alternatives.some((term) => matchesExpectation(value, term))) {
      throw new Error(
        `output is missing one of: ${alternatives
          .map(describeExpectation)
          .join(', ')}`,
      );
    }
  }
}

function matchesExpectation(
  value: string,
  expectation: TextExpectation,
): boolean {
  if (typeof expectation === 'string') {
    return value.includes(expectation);
  }
  expectation.lastIndex = 0;
  return expectation.test(value);
}

function describeExpectation(expectation: TextExpectation): string {
  return typeof expectation === 'string' ? expectation : expectation.source;
}

function forbidPatterns(value: string, patterns: RegExp[]): void {
  for (const pattern of patterns) {
    if (pattern.test(value)) {
      throw new Error(`output contains forbidden pattern: ${pattern.source}`);
    }
  }
}

function normalizeText(value: string): string {
  return value
    .normalize('NFKC')
    .trim()
    .toLowerCase()
    .replace(/\s+/gu, ' ')
    .replace(/[.!?…]+$/u, '');
}
