import {
  StructuredLearningModel,
} from '../src/application/structured-learning-model.ts';
import type {
  LearningModelResult,
} from '../src/application/learning-model-port.ts';
import {
  anonymizeCompletedQuestionContext,
  resolveMemoryCandidates,
  validateCoupleFeedback,
  validateDirectQuestionAnswer,
  validateDirectQuestionFollowUp,
  validatePersonalizedQuestion,
  validateProactiveSuggestion,
  validateQuestionRecommendation,
  type CompletedQuestionContext,
  type DirectQuestionContext,
  type ProactiveSuggestionContext,
} from '../src/domain/learning-contract.ts';
import {
  CloudflareWorkersAiStructuredGenerationClient,
} from '../src/infrastructure/cloudflare-workers-ai-structured-generation-client.ts';

const defaultModels = [
  '@cf/meta/llama-3.1-8b-instruct-fast',
  '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
];
const maximumRuns = 3;
const completedContext = createCompletedContext();
const anonymizedContext = anonymizeCompletedQuestionContext(completedContext);
const foundationCandidates = anonymizedContext.remainingFoundationQuestions;
const answerableDirectQuestionContext: DirectQuestionContext = {
  questionText: '상대방은 쉬는 날에 어떤 시간을 좋아해?',
  confirmedMemories: [
    {
      subject: 'partner',
      kind: 'rest_preference',
      domain: 'daily_life',
      statement: '쉬는 날에는 새로운 동네를 천천히 걷는 걸 좋아해',
      confidence: 0.95,
    },
  ],
  recentCompletedQuestions: [
    {
      questionText: '쉬는 날 가장 편안한 순간은 언제야?',
      answers: [
        { subject: 'me', text: '집에서 음악을 들을 때' },
        { subject: 'partner', text: '새로운 동네를 천천히 걸을 때' },
      ],
    },
  ],
  recentSharedQuestionTexts: [],
};
const insufficientDirectQuestionContext: DirectQuestionContext = {
  questionText: '상대방은 국내여행과 해외여행 중 어느 쪽을 더 좋아해?',
  confirmedMemories: [],
  recentCompletedQuestions: [],
  recentSharedQuestionTexts: [
    '둘이 여행을 간다면 꼭 챙기고 싶은 건 뭐야?',
  ],
};
const proactiveContext: ProactiveSuggestionContext = {
  localDate: '2026-07-30',
  localHour: 19,
  hasCardToday: false,
  confirmedMemories: [
    {
      subject: 'couple',
      kind: 'shared_activity',
      domain: 'daily_life',
      statement: '둘 다 함께 천천히 걷는 시간을 좋아해',
      confidence: 0.92,
    },
  ],
  recentCompletedQuestions: [],
  weather: {
    condition: 'clear',
    apparentTemperatureC: 24,
    precipitationPossible: false,
    nearSunset: true,
    sunsetLocalTime: '19:42',
  },
};

interface EvaluationCase {
  name: string;
  run(
    model: StructuredLearningModel,
  ): Promise<LearningModelResult<unknown>>;
  validate(value: unknown): void;
}

interface EvaluationCaseResult {
  name: string;
  status: 'passed' | 'failed';
  inputTokenCount: number | null;
  outputTokenCount: number | null;
  latencyMs: number;
  output: unknown;
  error: {
    name: string;
    code: string | null;
  } | null;
}

const evaluationCases: EvaluationCase[] = [
  {
    name: 'foundation_ranking',
    run: (model) => model.rankFoundationQuestions(
      anonymizedContext,
      foundationCandidates,
    ),
    validate: (value) => {
      const recommendation = value as {
        questionKey: string;
        rationale: string;
      };
      validateQuestionRecommendation(
        foundationCandidates,
        recommendation.questionKey,
      );
    },
  },
  {
    name: 'memory_extraction',
    run: (model) => model.extractMemoryCandidates(anonymizedContext),
    validate: (value) => {
      const memories = value as Awaited<
        ReturnType<StructuredLearningModel['extractMemoryCandidates']>
      >['value'];
      resolveMemoryCandidates(completedContext, memories);
      for (const memory of memories) {
        requireKoreanText(memory.statement, 'memory statement');
      }
    },
  },
  {
    name: 'couple_feedback',
    run: (model) => model.generateCoupleFeedback(anonymizedContext),
    validate: (value) => {
      const feedback = value as Awaited<
        ReturnType<StructuredLearningModel['generateCoupleFeedback']>
      >['value'];
      validateCoupleFeedback(feedback);
      requireKoreanText(feedback.text, 'couple feedback');
    },
  },
  {
    name: 'personalized_question',
    run: (model) => model.generatePersonalizedQuestion(anonymizedContext),
    validate: (value) => {
      const question = value as Awaited<
        ReturnType<StructuredLearningModel['generatePersonalizedQuestion']>
      >['value'];
      validatePersonalizedQuestion(question);
      requireKoreanText(question.text, 'personalized question');
    },
  },
  {
    name: 'direct_answer',
    run: (model) => model.answerDirectQuestion(
      answerableDirectQuestionContext,
    ),
    validate: (value) => {
      const answer = value as Awaited<
        ReturnType<StructuredLearningModel['answerDirectQuestion']>
      >['value'];
      validateDirectQuestionAnswer(answerableDirectQuestionContext, answer);
      if (answer.status !== 'answered') {
        throw new Error('answerable direct question returned insufficient');
      }
      requireKoreanText(answer.text, 'direct answer');
    },
  },
  {
    name: 'insufficient_answer',
    run: (model) => model.answerDirectQuestion(
      insufficientDirectQuestionContext,
    ),
    validate: (value) => {
      const answer = value as Awaited<
        ReturnType<StructuredLearningModel['answerDirectQuestion']>
      >['value'];
      validateDirectQuestionAnswer(insufficientDirectQuestionContext, answer);
      if (answer.status !== 'insufficient') {
        throw new Error('unknown preference was answered without evidence');
      }
      requireKoreanText(answer.text, 'insufficient answer');
    },
  },
  {
    name: 'direct_question_follow_up',
    run: (model) => model.generateDirectQuestionFollowUp(
      insufficientDirectQuestionContext,
    ),
    validate: (value) => {
      const question = value as Awaited<
        ReturnType<StructuredLearningModel['generateDirectQuestionFollowUp']>
      >['value'];
      validateDirectQuestionFollowUp(
        insufficientDirectQuestionContext,
        question,
      );
      requireKoreanText(question.text, 'direct question follow-up');
    },
  },
  {
    name: 'proactive_suggestion',
    run: (model) => model.generateProactiveSuggestion(proactiveContext),
    validate: (value) => {
      const suggestion = value as Awaited<
        ReturnType<StructuredLearningModel['generateProactiveSuggestion']>
      >['value'];
      validateProactiveSuggestion(proactiveContext, suggestion);
      requireKoreanText(suggestion.text, 'proactive suggestion');
    },
  },
];

const accountId = requireEnvironment('CLOUDFLARE_ACCOUNT_ID');
const apiToken = requireEnvironment('CLOUDFLARE_WORKERS_AI_API_TOKEN');
const models = readModels();
const runs = readRuns();
const report = [];
let hasFailure = false;

for (const modelName of models) {
  for (let run = 1; run <= runs; run += 1) {
    const model = new StructuredLearningModel(
      new CloudflareWorkersAiStructuredGenerationClient({
        accountId,
        apiToken,
        model: modelName,
      }),
    );
    const results: EvaluationCaseResult[] = [];
    for (const evaluationCase of evaluationCases) {
      const result = await runEvaluationCase(model, evaluationCase);
      results.push(result);
      hasFailure ||= result.status === 'failed';
    }
    report.push({
      model: modelName,
      run,
      passed: results.filter((result) => result.status === 'passed').length,
      total: results.length,
      inputTokenCount: sumKnownTokens(
        results.map((result) => result.inputTokenCount),
      ),
      outputTokenCount: sumKnownTokens(
        results.map((result) => result.outputTokenCount),
      ),
      latencyMs: results.reduce(
        (total, result) => total + result.latencyMs,
        0,
      ),
      results,
    });
  }
}

console.log(JSON.stringify({
  generatedAt: new Date().toISOString(),
  syntheticDataOnly: true,
  report,
}, null, 2));

if (hasFailure) {
  process.exitCode = 1;
}

async function runEvaluationCase(
  model: StructuredLearningModel,
  evaluationCase: EvaluationCase,
): Promise<EvaluationCaseResult> {
  try {
    const result = await evaluationCase.run(model);
    evaluationCase.validate(result.value);
    return {
      name: evaluationCase.name,
      status: 'passed',
      inputTokenCount: result.usage.inputTokenCount,
      outputTokenCount: result.usage.outputTokenCount,
      latencyMs: result.usage.latencyMs,
      output: result.value,
      error: null,
    };
  } catch (error) {
    return {
      name: evaluationCase.name,
      status: 'failed',
      inputTokenCount: null,
      outputTokenCount: null,
      latencyMs: 0,
      output: null,
      error: {
        name: error instanceof Error ? error.name : 'UnknownError',
        code: readErrorCode(error),
      },
    };
  }
}

function readErrorCode(error: unknown): string | null {
  if (typeof error !== 'object' || error === null) {
    return null;
  }
  const code = (error as { code?: unknown }).code;
  return typeof code === 'string' ? code : null;
}

function requireKoreanText(value: string, label: string): void {
  if (!/[\uac00-\ud7a3]/u.test(value)) {
    throw new Error(`${label} does not contain Korean text`);
  }
}

function requireEnvironment(name: string): string {
  const value = process.env[name]?.trim();
  if (value === undefined || value.length === 0) {
    throw new Error(`${name} is required`);
  }
  return value;
}

function readModels(): string[] {
  const configured = process.env.CLOUDFLARE_WORKERS_AI_EVAL_MODELS;
  const values = configured === undefined
    ? defaultModels
    : configured.split(',').map((value) => value.trim());
  const unique = [...new Set(values.filter((value) => value.length > 0))];
  if (unique.length === 0) {
    throw new Error('At least one Cloudflare evaluation model is required');
  }
  return unique;
}

function readRuns(): number {
  const raw = process.env.CLOUDFLARE_WORKERS_AI_EVAL_RUNS?.trim() ?? '1';
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 1 || value > maximumRuns) {
    throw new Error(
      `CLOUDFLARE_WORKERS_AI_EVAL_RUNS must be between 1 and ${maximumRuns}`,
    );
  }
  return value;
}

function sumKnownTokens(values: Array<number | null>): number | null {
  let total = 0;
  for (const value of values) {
    if (value === null) {
      return null;
    }
    total += value;
  }
  return total;
}

function createCompletedContext(): CompletedQuestionContext {
  return {
    coupleId: 'eval-couple',
    question: {
      dailyQuestionId: 'eval-daily-question',
      questionId: 'eval-question',
      text: '쉬는 날 가장 편안한 순간은 언제야?',
      domain: 'daily_life',
      depth: 'exploratory',
      promptAngle: 'lived_experience',
    },
    answers: [
      {
        answerId: 'eval-answer-a',
        userId: 'eval-user-a',
        text: '집에서 좋아하는 음악을 들으며 쉬는 시간이 좋아',
      },
      {
        answerId: 'eval-answer-b',
        userId: 'eval-user-b',
        text: '새로운 동네를 함께 천천히 걸을 때 마음이 편해져',
      },
    ],
    foundationProgress: {
      completedCount: 24,
      totalCount: 24,
      personalizationEnabled: true,
      domainProgress: {
        personal_values: { completedCount: 4, totalCount: 4 },
        emotional_support: { completedCount: 4, totalCount: 4 },
        communication_repair: { completedCount: 4, totalCount: 4 },
        daily_life: { completedCount: 4, totalCount: 4 },
        relationship_strength: { completedCount: 4, totalCount: 4 },
        future_boundaries: { completedCount: 4, totalCount: 4 },
      },
    },
    confirmedMemories: [
      {
        memoryKey: 'eval-couple-walk',
        scope: 'couple',
        subjectUserId: null,
        kind: 'shared_activity',
        domain: 'daily_life',
        evidenceType: 'repeated_pattern',
        statement: '둘 다 함께 천천히 걷는 시간을 좋아해',
        confidence: 0.92,
      },
    ],
    memoryCandidates: [],
    recentFoundationQuestions: [
      {
        questionKey: 'foundation_v1_daily_life_03',
        domain: 'daily_life',
        depth: 'exploratory',
        promptAngle: 'lived_experience',
      },
    ],
    recentCompletedQuestions: [
      {
        question: {
          dailyQuestionId: 'eval-recent-question',
          text: '함께 있을 때 시간이 빨리 가는 순간은 언제야?',
          domain: 'relationship_strength',
        },
        answers: [
          {
            answerId: 'eval-recent-answer-a',
            userId: 'eval-user-a',
            text: '별것 아닌 이야기를 오래 나눌 때',
          },
          {
            answerId: 'eval-recent-answer-b',
            userId: 'eval-user-b',
            text: '같이 걷다가 새로운 곳을 발견할 때',
          },
        ],
      },
    ],
    remainingFoundationQuestions: [
      {
        questionKey: 'foundation_v1_emotional_support_04',
        text: '힘든 날 서로에게 어떤 방식으로 곁이 되어주면 좋겠어?',
        domain: 'emotional_support',
        depth: 'deep',
        promptAngle: 'current_need',
      },
      {
        questionKey: 'foundation_v1_future_boundaries_04',
        text: '앞으로 둘이 함께 지키고 싶은 작은 약속은 뭐야?',
        domain: 'future_boundaries',
        depth: 'deep',
        promptAngle: 'scenario',
      },
    ],
  };
}
