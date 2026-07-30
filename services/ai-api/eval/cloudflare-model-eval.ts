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
  type DirectQuestionContext,
  type ProactiveSuggestionContext,
} from '../src/domain/learning-contract.ts';
import {
  CloudflareWorkersAiStructuredGenerationClient,
} from '../src/infrastructure/cloudflare-workers-ai-structured-generation-client.ts';
import {
  serializeEvaluationReport,
  writeEvaluationReport,
} from './cloudflare-evaluation-report.ts';
import {
  createCompletedEvaluationContext,
  createFoundationEvaluationContext,
  createProfileExfiltrationEvaluationContext,
  createPromptInjectionEvaluationContext,
  createSensitiveDiagnosisEvaluationContext,
  evaluateDirectQuestionSafetyPolicy,
  runEvaluationCase,
  validateExpectedMemoryCoverage,
  validatePromptInjectionMemoryOutput,
  validateSafetyRefusal,
} from './cloudflare-model-eval-support.ts';

const defaultModels = [
  '@cf/meta/llama-3.1-8b-instruct-fast',
  '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
];
const maximumRuns = 3;
const completedContext = createCompletedEvaluationContext();
const anonymizedContext = anonymizeCompletedQuestionContext(completedContext);
const foundationContext = anonymizeCompletedQuestionContext(
  createFoundationEvaluationContext(),
);
const foundationCandidates = foundationContext.remainingFoundationQuestions;
const promptInjectionContext = createPromptInjectionEvaluationContext();
const anonymizedPromptInjectionContext =
  anonymizeCompletedQuestionContext(promptInjectionContext);
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
const profileExfiltrationContext =
  createProfileExfiltrationEvaluationContext();
const sensitiveDiagnosisContext = createSensitiveDiagnosisEvaluationContext();
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

const evaluationCases: EvaluationCase[] = [
  {
    name: 'foundation_ranking',
    run: (model) => model.rankFoundationQuestions(
      foundationContext,
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
      validateExpectedMemoryCoverage(completedContext, memories);
      for (const memory of memories) {
        requireKoreanText(memory.statement, 'memory statement');
      }
    },
  },
  {
    name: 'memory_prompt_injection',
    run: (model) => model.extractMemoryCandidates(
      anonymizedPromptInjectionContext,
    ),
    validate: (value) => {
      const memories = value as Awaited<
        ReturnType<StructuredLearningModel['extractMemoryCandidates']>
      >['value'];
      validatePromptInjectionMemoryOutput(promptInjectionContext, memories);
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
    name: 'profile_exfiltration_refusal',
    run: async () => evaluateDirectQuestionSafetyPolicy(
      profileExfiltrationContext,
    ),
    validate: (value) => {
      const answer = value as Awaited<
        ReturnType<StructuredLearningModel['answerDirectQuestion']>
      >['value'];
      validateSafetyRefusal(profileExfiltrationContext, answer);
    },
  },
  {
    name: 'sensitive_diagnosis_refusal',
    run: async () => evaluateDirectQuestionSafetyPolicy(
      sensitiveDiagnosisContext,
    ),
    validate: (value) => {
      const answer = value as Awaited<
        ReturnType<StructuredLearningModel['answerDirectQuestion']>
      >['value'];
      validateSafetyRefusal(sensitiveDiagnosisContext, answer);
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
    const results = [];
    for (const evaluationCase of evaluationCases) {
      const result = await runEvaluationCase({
        name: evaluationCase.name,
        execute: () => evaluationCase.run(model),
        validate: evaluationCase.validate,
      });
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

const evaluationReport = {
  generatedAt: new Date().toISOString(),
  syntheticDataOnly: true,
  report,
};
const outputPath = readOptionalEnvironment(
  'CLOUDFLARE_WORKERS_AI_EVAL_OUTPUT',
);
if (outputPath !== null) {
  await writeEvaluationReport(outputPath, evaluationReport);
}
process.stdout.write(serializeEvaluationReport(evaluationReport));

if (hasFailure) {
  process.exitCode = 1;
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

function readOptionalEnvironment(name: string): string | null {
  const value = process.env[name]?.trim();
  return value === undefined || value.length === 0 ? null : value;
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
