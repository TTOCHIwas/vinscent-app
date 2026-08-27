import { hasUngroundedCoupleFeedbackDetail } from './couple-feedback-grounding.ts';
import { classifyDirectQuestionResponse } from './direct-question-evidence.ts';
import { hasSharedMemoryEvidence } from './memory-evidence.ts';
import {
  findKoreanQuestionNaturalnessIssue,
} from './korean-question-naturalness.ts';
import {
  areQuestionsAboutSameTopic,
  areQuestionsNearDuplicate,
} from './question-duplicate-detector.ts';
import {
  hasUnsupportedPastEventPresupposition,
} from './personalized-question-grounding.ts';
import { preservesQuestionScope } from './question-scope-preservation.ts';
import {
  KoreanOutputPolicyError,
  normalizeAndValidateKoreanOutput,
  type KoreanOutputPolicyErrorCode,
} from './korean-output-policy.ts';

export type LearningStage =
  | 'collecting'
  | 'exploring'
  | 'refining'
  | 'ready';

export type LearningDomain =
  | 'personal_values'
  | 'emotional_support'
  | 'communication_repair'
  | 'daily_life'
  | 'relationship_strength'
  | 'future_boundaries';

export type QuestionDepth = 'light' | 'exploratory' | 'deep';

export type PromptAngle =
  | 'preference'
  | 'lived_experience'
  | 'scenario'
  | 'current_need';

export type MemoryEvidenceType = 'explicit' | 'repeated_pattern';

export type SensitiveCategory =
  | 'none'
  | 'sexual_health'
  | 'pregnancy_fertility'
  | 'finance_debt'
  | 'health_mental_health'
  | 'trauma'
  | 'religion_politics'
  | 'family_conflict';

export type MemoryCandidateState =
  | 'pending'
  | 'active'
  | 'rejected'
  | 'superseded';

export type ParticipantKey = 'partner_a' | 'partner_b';

export interface CompletedQuestionAnswer {
  answerId: string;
  userId: string;
  text: string;
}

export interface ConfirmedMemoryContext {
  memoryKey: string;
  scope: 'personal' | 'couple';
  subjectUserId: string | null;
  kind: string;
  domain: LearningDomain;
  evidenceType: MemoryEvidenceType;
  statement: string;
  confidence: number;
}

export interface FoundationQuestionCandidate {
  questionKey: string;
  text: string;
  domain: LearningDomain;
  depth: QuestionDepth;
  promptAngle: PromptAngle;
}

export interface FoundationProgressContext {
  completedCount: number;
  totalCount: number;
  personalizationEnabled: boolean;
  domainProgress: Record<
    LearningDomain,
    { completedCount: number; totalCount: number }
  >;
}

export interface MemoryCandidateContext {
  memoryKey: string;
  scope: 'personal' | 'couple';
  subjectUserId: string | null;
  kind: string;
  domain: LearningDomain;
  evidenceType: MemoryEvidenceType;
  statement: string | null;
  confidence: number;
  state: MemoryCandidateState;
  evidenceQuestionCount: number;
}

export interface RecentFoundationQuestionContext {
  questionKey: string;
  domain: LearningDomain;
  depth: QuestionDepth;
  promptAngle: PromptAngle;
}

export interface RecentCompletedQuestionContext {
  question: {
    dailyQuestionId: string;
    text: string;
    domain: LearningDomain | null;
  };
  answers: CompletedQuestionAnswer[];
}

export interface CompletedQuestionContext {
  coupleId: string;
  question: {
    dailyQuestionId: string;
    questionId: string;
    text: string;
    domain: LearningDomain | null;
    depth: QuestionDepth | null;
    promptAngle: PromptAngle | null;
  };
  answers: CompletedQuestionAnswer[];
  foundationProgress: FoundationProgressContext;
  confirmedMemories: ConfirmedMemoryContext[];
  memoryCandidates: MemoryCandidateContext[];
  recentFoundationQuestions: RecentFoundationQuestionContext[];
  recentCompletedQuestions: RecentCompletedQuestionContext[];
  recentExposedQuestionTexts?: string[];
  pendingQuestionTexts?: string[];
  remainingFoundationQuestions: FoundationQuestionCandidate[];
}

export interface AnonymizedCompletedQuestionContext {
  question: CompletedQuestionContext['question'];
  answers: Array<{
    answerId: string;
    participantKey: ParticipantKey;
    text: string;
  }>;
  confirmedMemories: Array<{
    memoryKey: string;
    scope: 'personal' | 'couple';
    subjectParticipantKey: ParticipantKey | null;
    kind: string;
    domain: LearningDomain;
    evidenceType: MemoryEvidenceType;
    statement: string;
    confidence: number;
  }>;
  foundationProgress: FoundationProgressContext;
  memoryCandidates: Array<{
    memoryKey: string;
    scope: 'personal' | 'couple';
    subjectParticipantKey: ParticipantKey | null;
    kind: string;
    domain: LearningDomain;
    evidenceType: MemoryEvidenceType;
    statement: string | null;
    confidence: number;
    state: MemoryCandidateState;
    evidenceQuestionCount: number;
  }>;
  recentFoundationQuestions: RecentFoundationQuestionContext[];
  recentCompletedQuestions: Array<{
    question: RecentCompletedQuestionContext['question'];
    answers: Array<{
      answerId: string;
      participantKey: ParticipantKey;
      text: string;
    }>;
  }>;
  recentExposedQuestionTexts?: string[];
  pendingQuestionTexts?: string[];
  remainingFoundationQuestions: FoundationQuestionCandidate[];
}

export interface MemoryCandidate {
  memoryKey: string;
  scope: 'personal' | 'couple';
  subjectUserId: string | null;
  kind: string;
  domain: LearningDomain;
  evidenceType: MemoryEvidenceType;
  sensitiveCategory: SensitiveCategory;
  statement: string;
  confidence: number;
  evidenceAnswerIds: string[];
}

export interface ModelMemoryCandidate {
  memoryKey: string;
  scope: 'personal' | 'couple';
  subjectParticipantKey: ParticipantKey | null;
  kind: string;
  domain: LearningDomain;
  evidenceType: MemoryEvidenceType;
  sensitiveCategory: SensitiveCategory;
  statement: string;
  confidence: number;
  evidenceAnswerIds: string[];
}

export interface CoupleFeedbackCandidate {
  text: string;
}

export type CoupleFeedbackValidationCode =
  | 'invalid_punctuation'
  | 'answer_owner'
  | 'blocked_topic'
  | 'instruction_leak'
  | 'advice_or_command'
  | 'unsupported_inference'
  | 'ungrounded_detail'
  | 'mixed_certainty_content'
  | 'question_echo'
  | 'answer_restatement';

export class CoupleFeedbackValidationError extends Error {
  readonly code: CoupleFeedbackValidationCode;

  constructor(code: CoupleFeedbackValidationCode, message: string) {
    super(message);
    this.name = 'CoupleFeedbackValidationError';
    this.code = code;
  }
}

export interface PersonalizedQuestionCandidate {
  questionKey: string;
  text: string;
  category: string;
  mood: string | null;
  rationale: string;
}

export type PersonalizedQuestionValidationCode =
  | 'meta_language'
  | 'strategy_leak'
  | 'duplicate_question'
  | 'repeated_topic'
  | 'volatile_time_reference'
  | 'unsupported_presupposition'
  | 'unnatural_question';

export class PersonalizedQuestionValidationError extends Error {
  readonly code: PersonalizedQuestionValidationCode;

  constructor(code: PersonalizedQuestionValidationCode) {
    super(code);
    this.name = 'PersonalizedQuestionValidationError';
    this.code = code;
  }
}

export interface GeneralQuestionContext {
  foundationProgress: {
    completedCount: number;
    totalCount: number;
  };
  recentQuestions: Array<{
    questionKey: string;
    text: string;
    category: string;
    mood: string | null;
    domain: LearningDomain | null;
  }>;
}

export type PersonalizationSubject = 'me' | 'partner' | 'couple';

export interface PersonalizationMemoryContext {
  subject: PersonalizationSubject;
  kind: string;
  domain: LearningDomain;
  statement: string;
  confidence: number;
}

export interface PersonalizationRecentQuestionContext {
  questionText: string;
  answers: Array<{
    subject: 'me' | 'partner';
    text: string;
  }>;
}

export interface DirectQuestionContext {
  questionText: string;
  confirmedMemories: PersonalizationMemoryContext[];
  recentCompletedQuestions: PersonalizationRecentQuestionContext[];
  recentSharedQuestionTexts: string[];
}

export type DirectQuestionAnswerStatus = 'answered' | 'insufficient';

export type DirectQuestionFollowUpCandidate = PersonalizedQuestionCandidate;

export interface DirectQuestionAnswer {
  status: DirectQuestionAnswerStatus;
  text: string;
  followUpQuestion: DirectQuestionFollowUpCandidate | null;
}

export type DirectQuestionFollowUpValidationCode =
  | 'invalid_key'
  | 'invalid_question'
  | 'invalid_metadata'
  | 'blocked_topic'
  | 'asymmetric_question'
  | 'unnatural_question'
  | 'scope_drift'
  | 'duplicate_question'
  | KoreanOutputPolicyErrorCode;

export class DirectQuestionFollowUpValidationError extends Error {
  readonly code: DirectQuestionFollowUpValidationCode;

  constructor(code: DirectQuestionFollowUpValidationCode) {
    super(code);
    this.name = 'DirectQuestionFollowUpValidationError';
    this.code = code;
  }
}

export type ProactiveSuggestionKind =
  | 'date_idea'
  | 'card_idea'
  | 'sunset_card';

export type ProactiveWeatherCondition =
  | 'clear'
  | 'partly_cloudy'
  | 'cloudy'
  | 'rain_possible'
  | 'snow_possible'
  | 'hot'
  | 'cold'
  | 'unknown';

export interface ProactiveWeatherContext {
  condition: ProactiveWeatherCondition;
  apparentTemperatureC: number | null;
  precipitationPossible: boolean;
  nearSunset: boolean;
  sunsetLocalTime: string | null;
}

export interface ProactiveSuggestionContext {
  localDate: string;
  localHour: number;
  hasCardToday: boolean;
  confirmedMemories: PersonalizationMemoryContext[];
  recentCompletedQuestions: PersonalizationRecentQuestionContext[];
  weather: ProactiveWeatherContext | null;
}

export interface ProactiveSuggestionCandidate {
  text: string;
  kind: ProactiveSuggestionKind;
}

export type ProactiveSuggestionValidationCode =
  | 'invalid_text'
  | 'too_short'
  | 'invalid_sunset_context'
  | 'sunset_card_required'
  | 'card_after_upload'
  | 'period'
  | 'excessive_punctuation'
  | 'commanding_expression'
  | 'forced_abstract_expression'
  | 'unnatural_expression'
  | 'raw_context_value'
  | 'weather_without_context'
  | 'weather_overstatement'
  | 'blocked_topic'
  | KoreanOutputPolicyErrorCode;

export class ProactiveSuggestionValidationError extends Error {
  readonly code: ProactiveSuggestionValidationCode;

  constructor(code: ProactiveSuggestionValidationCode, message: string) {
    super(message);
    this.name = 'ProactiveSuggestionValidationError';
    this.code = code;
  }
}

function requireNonBlank(value: string, field: string, maximum: number): void {
  const length = value.trim().length;
  if (length === 0 || length > maximum) {
    throw new RangeError(`${field} must contain 1 to ${maximum} characters`);
  }
}

function validateContextAnswers(
  context: CompletedQuestionContext,
): Map<string, CompletedQuestionAnswer> {
  if (context.answers.length !== 2) {
    throw new RangeError('completed question context must contain two answers');
  }

  const answersById = new Map<string, CompletedQuestionAnswer>();
  const participantIds = new Set<string>();

  for (const answer of context.answers) {
    requireNonBlank(answer.answerId, 'answer id', 160);
    requireNonBlank(answer.userId, 'answer user id', 160);
    requireNonBlank(answer.text, 'answer text', 4000);

    if (answersById.has(answer.answerId)) {
      throw new Error('duplicate answer id');
    }
    if (participantIds.has(answer.userId)) {
      throw new Error('completed question answers must belong to two participants');
    }

    answersById.set(answer.answerId, answer);
    participantIds.add(answer.userId);
  }

  return answersById;
}

function participantKeyMap(
  context: CompletedQuestionContext,
): Map<string, ParticipantKey> {
  validateContextAnswers(context);
  return new Map<string, ParticipantKey>([
    [context.answers[0]!.userId, 'partner_a'],
    [context.answers[1]!.userId, 'partner_b'],
  ]);
}

export function deriveLearningStage(
  completedCount: number,
  foundationQuestionCount: number,
): LearningStage {
  if (
    !Number.isInteger(completedCount)
    || completedCount < 0
    || !Number.isInteger(foundationQuestionCount)
    || foundationQuestionCount <= 0
  ) {
    throw new RangeError('learning progress counts must be valid integers');
  }

  if (completedCount >= foundationQuestionCount) {
    return 'ready';
  }

  const exploringStart = Math.ceil(foundationQuestionCount / 3);
  const refiningStart = Math.ceil((foundationQuestionCount * 2) / 3);

  if (completedCount < exploringStart) {
    return 'collecting';
  }
  if (completedCount < refiningStart) {
    return 'exploring';
  }
  return 'refining';
}

export function anonymizeCompletedQuestionContext(
  context: CompletedQuestionContext,
): AnonymizedCompletedQuestionContext {
  requireNonBlank(context.coupleId, 'couple id', 160);
  const participants = participantKeyMap(context);

  const resolveSubject = (
    scope: 'personal' | 'couple',
    subjectUserId: string | null,
    label: string,
  ): ParticipantKey | null => {
    const subjectParticipantKey = subjectUserId === null
      ? null
      : participants.get(subjectUserId);

    if (scope === 'personal' && subjectParticipantKey === undefined) {
      throw new Error(`${label} has an unknown personal subject`);
    }
    if (scope === 'couple' && subjectUserId !== null) {
      throw new Error(`${label} cannot have a personal subject`);
    }
    return subjectParticipantKey ?? null;
  };

  return {
    question: { ...context.question },
    answers: context.answers.map((answer) => ({
      answerId: answer.answerId,
      participantKey: participants.get(answer.userId)!,
      text: answer.text,
    })),
    confirmedMemories: context.confirmedMemories.map((memory) => {
      return {
        memoryKey: memory.memoryKey,
        scope: memory.scope,
        subjectParticipantKey: resolveSubject(
          memory.scope,
          memory.subjectUserId,
          'confirmed memory',
        ),
        kind: memory.kind,
        domain: memory.domain,
        evidenceType: memory.evidenceType,
        statement: memory.statement,
        confidence: memory.confidence,
      };
    }),
    foundationProgress: {
      ...context.foundationProgress,
      domainProgress: { ...context.foundationProgress.domainProgress },
    },
    memoryCandidates: context.memoryCandidates.map((memory) => ({
      memoryKey: memory.memoryKey,
      scope: memory.scope,
      subjectParticipantKey: resolveSubject(
        memory.scope,
        memory.subjectUserId,
        'memory candidate',
      ),
      kind: memory.kind,
      domain: memory.domain,
      evidenceType: memory.evidenceType,
      statement: memory.statement,
      confidence: memory.confidence,
      state: memory.state,
      evidenceQuestionCount: memory.evidenceQuestionCount,
    })),
    recentFoundationQuestions: context.recentFoundationQuestions.map(
      (question) => ({ ...question }),
    ),
    recentCompletedQuestions: context.recentCompletedQuestions.map(
      (recent) => {
        if (recent.answers.length !== 2) {
          throw new RangeError('recent completed question requires two answers');
        }
        return {
          question: { ...recent.question },
          answers: recent.answers.map((answer) => {
            const participantKey = participants.get(answer.userId);
            if (participantKey === undefined) {
              throw new Error('recent answer has an unknown participant');
            }
            return {
              answerId: answer.answerId,
              participantKey,
              text: answer.text,
            };
          }),
        };
      },
    ),
    recentExposedQuestionTexts: [
      ...(context.recentExposedQuestionTexts ?? []),
    ],
    pendingQuestionTexts: [...(context.pendingQuestionTexts ?? [])],
    remainingFoundationQuestions: context.remainingFoundationQuestions.map(
      (question) => ({ ...question }),
    ),
  };
}

export function validateMemoryCandidates(
  context: CompletedQuestionContext,
  candidates: MemoryCandidate[],
): void {
  if (candidates.length > 3) {
    throw new RangeError('at most three memory candidates are allowed');
  }

  const answersById = validateContextAnswers(context);
  const participantIds = new Set(context.answers.map((answer) => answer.userId));
  const memoryKeys = new Set<string>();
  const personalSubjects = new Set<string>();
  let coupleMemoryCount = 0;

  for (const candidate of candidates) {
    requireNonBlank(candidate.memoryKey, 'memory key', 160);
    requireNonBlank(candidate.kind, 'memory kind', 100);
    requireNonBlank(candidate.statement, 'memory statement', 500);
    validateMemoryStatement(candidate.statement);

    if (candidate.sensitiveCategory !== 'none') {
      throw new Error('sensitive memory candidate is not allowed');
    }
    if (containsBlockedAiTopic(candidate.statement)) {
      throw new Error('memory candidate contains a blocked topic');
    }

    if (memoryKeys.has(candidate.memoryKey)) {
      throw new Error('duplicate memory key');
    }
    memoryKeys.add(candidate.memoryKey);

    if (
      !Number.isFinite(candidate.confidence)
      || candidate.confidence < 0
      || candidate.confidence > 1
    ) {
      throw new RangeError('memory confidence must be between 0 and 1');
    }

    if (candidate.scope === 'personal') {
      if (
        candidate.subjectUserId === null
        || !participantIds.has(candidate.subjectUserId)
      ) {
        throw new Error('unknown personal subject');
      }
      if (personalSubjects.has(candidate.subjectUserId)) {
        throw new Error(
          'only one personal memory per participant is allowed',
        );
      }
      personalSubjects.add(candidate.subjectUserId);
    } else if (candidate.scope === 'couple') {
      if (candidate.subjectUserId !== null) {
        throw new Error('couple memory cannot have a personal subject');
      }
      coupleMemoryCount += 1;
      if (coupleMemoryCount > 1) {
        throw new Error('only one couple memory is allowed');
      }
    } else {
      throw new Error('unknown memory scope');
    }

    if (candidate.evidenceAnswerIds.length === 0) {
      throw new Error('memory candidate requires answer evidence');
    }

    const uniqueEvidenceIds = new Set(candidate.evidenceAnswerIds);
    if (uniqueEvidenceIds.size !== candidate.evidenceAnswerIds.length) {
      throw new Error('duplicate evidence answer');
    }

    if (
      candidate.scope === 'personal'
      && candidate.evidenceAnswerIds.length !== 1
    ) {
      throw new Error('personal memory requires exactly one participant answer');
    }
    if (
      candidate.scope === 'couple'
      && candidate.evidenceAnswerIds.length !== context.answers.length
    ) {
      throw new Error('couple memory requires both participant answers');
    }

    for (const evidenceAnswerId of candidate.evidenceAnswerIds) {
      const evidence = answersById.get(evidenceAnswerId);
      if (evidence === undefined) {
        throw new Error(`unknown evidence answer: ${evidenceAnswerId}`);
      }
      if (
        candidate.scope === 'personal'
        && evidence.userId !== candidate.subjectUserId
      ) {
        throw new Error('personal memory evidence belongs to another participant');
      }
    }

    if (
      candidate.scope === 'couple'
      && !hasSharedMemoryEvidence({
        questionText: context.question.text,
        statement: candidate.statement,
        answerTexts: candidate.evidenceAnswerIds.map(
          (answerId) => answersById.get(answerId)!.text,
        ),
      })
    ) {
      throw new Error('couple memory requires shared answer evidence');
    }

    if (candidate.evidenceType === 'repeated_pattern') {
      const previousCandidate = context.memoryCandidates.find(
        (memory) =>
          memory.memoryKey === candidate.memoryKey
          && memory.scope === candidate.scope
          && memory.subjectUserId === candidate.subjectUserId
          && memory.kind === candidate.kind
          && memory.domain === candidate.domain
          && memory.state !== 'rejected'
          && memory.state !== 'superseded'
          && memory.evidenceQuestionCount >= 1,
      );
      if (previousCandidate === undefined) {
        throw new Error('repeated memory requires prior question evidence');
      }
    }
  }
}

const internalMemoryParticipantPatterns = [
  /파트너\s*[ab]/iu,
  /partner[_\s-]?[ab]/iu,
  /사용자\s*[ab]/iu,
  /(?:첫|두)\s*번째\s*(?:사용자|사람|파트너)/u,
  /\b[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\b/iu,
];

const reportStyleMemoryEndingPattern =
  /(?:습니다|ㅂ니다|합니다|입니다|됩니다|드립니다|바랍니다|한다|이다|된다|있다|없다)[.!?]?$/u;

function validateMemoryStatement(statement: string): void {
  if (
    internalMemoryParticipantPatterns.some((pattern) => pattern.test(statement))
  ) {
    throw new Error('memory statement cannot expose an internal participant');
  }
  validateKoreanCharacterText(statement, 'memory statement');
  if (
    reportStyleMemoryEndingPattern.test(statement)
    || statement.endsWith('.')
  ) {
    throw new Error('memory statement must use casual speech');
  }
}

export function resolveMemoryCandidates(
  context: CompletedQuestionContext,
  candidates: ModelMemoryCandidate[],
): MemoryCandidate[] {
  const participants = participantKeyMap(context);
  const userIdByParticipant = new Map<ParticipantKey, string>();
  for (const [userId, participantKey] of participants) {
    userIdByParticipant.set(participantKey, userId);
  }

  const resolved = candidates.map<MemoryCandidate>((candidate) => {
    const subjectUserId = candidate.subjectParticipantKey === null
      ? null
      : userIdByParticipant.get(candidate.subjectParticipantKey);

    if (
      candidate.scope === 'personal'
      && subjectUserId === undefined
    ) {
      throw new Error('unknown personal subject participant');
    }
    if (
      candidate.scope === 'couple'
      && candidate.subjectParticipantKey !== null
    ) {
      throw new Error('couple memory cannot have a personal subject');
    }

    const hasPriorQuestionEvidence = context.memoryCandidates.some(
      (memory) =>
        memory.memoryKey === candidate.memoryKey
        && memory.scope === candidate.scope
        && memory.subjectUserId === (subjectUserId ?? null)
        && memory.kind === candidate.kind
        && memory.domain === candidate.domain
        && memory.state !== 'rejected'
        && memory.state !== 'superseded'
        && memory.evidenceQuestionCount >= 1,
    );

    return {
      memoryKey: candidate.memoryKey,
      scope: candidate.scope,
      subjectUserId: subjectUserId ?? null,
      kind: candidate.kind,
      domain: candidate.domain,
      evidenceType: candidate.evidenceType === 'explicit'
          && hasPriorQuestionEvidence
        ? 'repeated_pattern'
        : candidate.evidenceType,
      sensitiveCategory: candidate.sensitiveCategory,
      statement: candidate.statement,
      confidence: candidate.confidence,
      evidenceAnswerIds: [...candidate.evidenceAnswerIds],
    };
  });

  validateMemoryCandidates(context, resolved);
  return resolved;
}

export function validateQuestionRecommendation(
  candidates: FoundationQuestionCandidate[],
  recommendedQuestionKey: string,
): void {
  requireNonBlank(recommendedQuestionKey, 'recommended question key', 120);

  if (
    !candidates.some(
      (candidate) => candidate.questionKey === recommendedQuestionKey,
    )
  ) {
    throw new Error('question recommendation is not an allowed candidate');
  }
}

export function validateCoupleFeedback(
  candidate: CoupleFeedbackCandidate,
  context?: AnonymizedCompletedQuestionContext,
): void {
  requireNonBlank(candidate.text, 'couple feedback', 80);
  validateKoreanCharacterText(candidate.text, 'couple feedback');
  const reactionBody = candidate.text.endsWith('...')
    ? candidate.text.slice(0, -3)
    : /[!?]$/u.test(candidate.text)
    ? candidate.text.slice(0, -1)
    : candidate.text;
  if (/[.!?]/u.test(reactionBody)) {
    throw new CoupleFeedbackValidationError(
      'invalid_punctuation',
      'couple feedback punctuation allowed endings are !, ?, ..., or none',
    );
  }
  if (
    feedbackAnswerOwnerPatterns.some((pattern) => pattern.test(candidate.text))
  ) {
    throw new CoupleFeedbackValidationError(
      'answer_owner',
      'couple feedback cannot identify an answer owner',
    );
  }
  if (containsBlockedAiTopic(candidate.text)) {
    throw new CoupleFeedbackValidationError(
      'blocked_topic',
      'couple feedback contains a blocked topic',
    );
  }
  if (feedbackInstructionLeakPattern.test(candidate.text)) {
    throw new CoupleFeedbackValidationError(
      'instruction_leak',
      'couple feedback exposes an internal generation instruction',
    );
  }
  if (feedbackAdviceOrCommandPattern.test(candidate.text)) {
    throw new CoupleFeedbackValidationError(
      'advice_or_command',
      'couple feedback cannot advise or command an action',
    );
  }
  if (context !== undefined) {
    validateQuestionEcho(context, candidate.text);
    validateUnsupportedFeedbackInference(context, candidate.text);
    validateGroundedFeedbackDetails(context, candidate.text);
    validateMixedCertaintyFeedback(context, candidate.text);
    validateAnswerRestatement(context, candidate.text);
  }
}

const feedbackInstructionLeakPattern = new RegExp(
  [
    '규칙(?:에|을|이)?\\s*맞',
    '(?:잘|다시)\\s*작성(?:됐|해|하)',
    '지시문',
    '출력\\s*(?:검사|형식|규칙)',
    'JSON\\s*(?:Schema|스키마)?',
    'feedback_text',
    'current_(?:question|answers)',
    'response_semantics',
    'confirmed_profile',
    'recent_completed_questions',
    'rejected_feedback',
    'retry_correction',
  ].join('|'),
  'iu',
);

const feedbackAdviceOrCommandPattern = new RegExp(
  [
    '(?:해|가|먹|보|쉬|걷)(?:는|어\\s*보는|해\\s*보는)?\\s*건\\s*어때',
    '(?:하면|해\\s*보면|가면|먹으면|보면)\\s*(?:좋겠|어때|괜찮겠)',
    '(?:해\\s*봐|해\\s*보자|가\\s*보자|가자|보자|먹자|쉬자|물어\\s*봐|말해\\s*봐|나눠\\s*보자)(?:[!?]|\\.\\.\\.)?$',
  ].join('|'),
  'u',
);

const unsupportedInferencePattern =
  /(?:바쁘|여유(?:가|도)?\s*없|관심\s*없|의욕\s*없|생각도\s*없|귀찮|피하|회피|마음\s*없|하기\s*싫|원하지\s*않)/u;

function validateUnsupportedFeedbackInference(
  context: AnonymizedCompletedQuestionContext,
  feedbackText: string,
): void {
  const hasOnlyUncertainAnswers = context.answers.every((answer) =>
    classifyDirectQuestionResponse(answer.text) !== 'substantive'
  );
  if (
    hasOnlyUncertainAnswers
    && unsupportedInferencePattern.test(feedbackText)
  ) {
    throw new CoupleFeedbackValidationError(
      'unsupported_inference',
      'couple feedback cannot infer a motive from uncertain answers',
    );
  }
}

function validateGroundedFeedbackDetails(
  context: AnonymizedCompletedQuestionContext,
  feedbackText: string,
): void {
  if (hasUngroundedCoupleFeedbackDetail(context, feedbackText)) {
    throw new CoupleFeedbackValidationError(
      'ungrounded_detail',
      'couple feedback cannot introduce unsupported time, frequency, or setting details',
    );
  }
}

function validateQuestionEcho(
  context: AnonymizedCompletedQuestionContext,
  feedbackText: string,
): void {
  if (!areQuestionsNearDuplicate(context.question.text, feedbackText)) {
    return;
  }

  throw new CoupleFeedbackValidationError(
    'question_echo',
    'couple feedback cannot repeat the source question',
  );
}

const mixedCertaintyFeedbackStopTerms = new Set([
  '가장',
  '그냥',
  '아직',
  '오늘',
  '요즘',
  '이제',
  '정말',
  '제일',
  '좋아',
  '좋아해',
  '싶어',
  '원해',
  '함께',
  '서로',
]);

function validateMixedCertaintyFeedback(
  context: AnonymizedCompletedQuestionContext,
  feedbackText: string,
): void {
  const answerSemantics = context.answers.map((answer) => ({
    text: answer.text,
    semantics: classifyDirectQuestionResponse(answer.text),
  }));
  const hasExplicitUncertainty = answerSemantics.some(
    ({ semantics }) => semantics !== 'substantive',
  );
  const substantiveAnswers = answerSemantics.filter(
    ({ semantics }) => semantics === 'substantive',
  );
  if (!hasExplicitUncertainty || substantiveAnswers.length === 0) {
    return;
  }

  const repeatsUncertainty = /(?:몰라|모르|없어|없다|없음|없는\s*것)/u
    .test(feedbackText);
  const repeatsSubstantiveTerm = substantiveAnswers.some(({ text }) =>
    feedbackContentTerms(text).some((term) => feedbackText.includes(term))
  );
  if (repeatsUncertainty || repeatsSubstantiveTerm) {
    throw new CoupleFeedbackValidationError(
      'mixed_certainty_content',
      'couple feedback cannot repeat mixed certainty answer content',
    );
  }
}

const feedbackRestatementPattern =
  /(?:좋아하(?:네|는|나|고|지|겠)|선호하|취향|답(?:했|은|이|도|변)|골랐|말했|생각하(?:네|는|나)|원하(?:네|는|나)|(?:같|닮|다르)(?:네|구나|군)|둘\s*다)/u;

function validateAnswerRestatement(
  context: AnonymizedCompletedQuestionContext,
  feedbackText: string,
): void {
  if (!feedbackRestatementPattern.test(feedbackText)) {
    return;
  }

  const repeatsAnswerContent = context.answers.some(({ text }) =>
    feedbackContentTerms(text).some((term) => feedbackText.includes(term))
  );
  if (!repeatsAnswerContent) {
    return;
  }

  throw new CoupleFeedbackValidationError(
    'answer_restatement',
    'couple feedback cannot merely restate an answer',
  );
}

export function resolveCoupleFeedbackFallback(
  context: AnonymizedCompletedQuestionContext,
  rejectionCode: CoupleFeedbackValidationCode | null,
): CoupleFeedbackCandidate | null {
  if (
    rejectionCode === 'mixed_certainty_content'
    && hasMixedCertaintyAnswers(context)
  ) {
    return {
      text: '같은 질문도 답이 바로 떠오르는 날과 천천히 생각나는 날이 있나 봐...',
    };
  }

  return {
    text: '두 답이 모이니 이야깃거리 하나가 생겼네',
  };
}

export function repairCoupleFeedbackPunctuation(
  candidate: CoupleFeedbackCandidate,
): CoupleFeedbackCandidate | null {
  const text = candidate.text.normalize('NFC').trim();
  const ending = text.endsWith('...')
    ? '...'
    : text.match(/[!?]$/u)?.[0] ?? '';
  const body = ending.length === 0
    ? text
    : text.slice(0, -ending.length);
  const repairedBody = body
    .replace(/[.!?]+/gu, ' ')
    .replace(/\s+/gu, ' ')
    .trim();
  const repairedText = `${repairedBody}${ending}`;

  if (repairedText.length === 0 || repairedText === text) {
    return null;
  }
  return { text: repairedText };
}

function hasMixedCertaintyAnswers(
  context: AnonymizedCompletedQuestionContext,
): boolean {
  const semantics = context.answers.map((answer) =>
    classifyDirectQuestionResponse(answer.text)
  );
  return semantics.some((value) => value !== 'substantive')
    && semantics.some((value) => value === 'substantive');
}

function feedbackContentTerms(value: string): string[] {
  return value
    .normalize('NFC')
    .replace(/[^\p{Script=Hangul}\p{L}\p{N}]+/gu, ' ')
    .trim()
    .split(/\s+/u)
    .map(normalizeFeedbackContentTerm)
    .filter((term) =>
      term.length >= 2 && !mixedCertaintyFeedbackStopTerms.has(term)
    );
}

function normalizeFeedbackContentTerm(value: string): string {
  return value
    .replace(
      /(?:에게서|한테서|으로|에서|에게|한테|까지|부터|처럼|보다|이랑|하고|은|는|이|가|을|를|도|에|로|와|과|랑)$/u,
      '',
    )
    .replace(/(?:했어|했네|했지|였어|였네|었어|었네|았어|았네)$/u, '');
}

const feedbackAnswerOwnerPatterns = [
  /(?:^|\s)(?:너는|넌|너가|네가|니가|너도|너만|너의|너랑|너와|너에게|너를|널|네\s*답|네\s*마음|당신은)(?=$|\s|[!?,'"‘’“”])/u,
  /상대방/u,
  /(?:한|다른)\s*사람/u,
  /(?:한|다른)\s*쪽(?:은|이|도|의|에서|에게|으로)?/u,
  /누군가는/u,
  /파트너\s*[ab]/iu,
  /partner[_\s-]?[ab]/iu,
  /\b(?:you|your|the other partner)\b/iu,
];

export function validatePersonalizedQuestion(
  candidate: PersonalizedQuestionCandidate,
  context?: Pick<
    AnonymizedCompletedQuestionContext,
    | 'question'
    | 'recentCompletedQuestions'
    | 'recentExposedQuestionTexts'
    | 'pendingQuestionTexts'
  >,
): void {
  validateGeneratedQuestion(candidate);

  if (
    /(?:패턴|경향|성향)[^?]{0,24}(?:맞는지|확인|파악|분석|알아보)/u.test(candidate.text)
    || /(?:확인|파악|분석|탐색)(?:해\s*보)?려면/u.test(candidate.text)
  ) {
    throw new PersonalizedQuestionValidationError('meta_language');
  }

  if (
    [candidate.category, candidate.mood ?? '', candidate.rationale]
      .some((value) => /(?:^|[^a-z])(?:continue|explore)(?:$|[^a-z])/iu.test(value))
  ) {
    throw new PersonalizedQuestionValidationError('strategy_leak');
  }

  if (
    context !== undefined
    && [
      context.question.text,
      ...context.recentCompletedQuestions.map(({ question }) => question.text),
    ].some((questionText) =>
      areQuestionsNearDuplicate(candidate.text, questionText)
    )
  ) {
    throw new PersonalizedQuestionValidationError('duplicate_question');
  }

  if (
    /(?:오늘\s*밤|오늘|내일|모레|어제|그제|(?:이번|다음|지난)\s*(?:주말|주|달|휴일|연휴))/u
      .test(candidate.text)
  ) {
    throw new PersonalizedQuestionValidationError(
      'volatile_time_reference',
    );
  }

  if (
    context !== undefined
    && hasUnsupportedPastEventPresupposition(
      context.question.text,
      candidate.text,
    )
  ) {
    throw new PersonalizedQuestionValidationError(
      'unsupported_presupposition',
    );
  }

  if (findKoreanQuestionNaturalnessIssue(candidate.text) !== null) {
    throw new PersonalizedQuestionValidationError('unnatural_question');
  }

  if (
    context !== undefined
    && [
      ...(context.recentExposedQuestionTexts ?? []),
      ...(context.pendingQuestionTexts ?? []),
    ].some((questionText) =>
      areQuestionsAboutSameTopic(candidate.text, questionText)
    )
  ) {
    throw new PersonalizedQuestionValidationError('repeated_topic');
  }
}

export function validateGeneralQuestion(
  candidate: PersonalizedQuestionCandidate,
): void {
  validateGeneratedQuestion(candidate);

  if (!/^general_[a-z0-9_]+_[a-z0-9]{8}$/.test(candidate.questionKey)) {
    throw new Error('general question key has an invalid format');
  }
}

export function validateDirectQuestionAnswer(
  context: DirectQuestionContext,
  candidate: DirectQuestionAnswer,
): void {
  requireNonBlank(candidate.text, 'direct question answer', 400);
  validateKoreanCharacterText(candidate.text, 'direct question answer');

  if (
    candidate.status !== 'answered'
    && candidate.status !== 'insufficient'
  ) {
    throw new Error('unknown direct question answer status');
  }
  if (
    internalMemoryParticipantPatterns.some(
      (pattern) => pattern.test(candidate.text),
    )
  ) {
    throw new Error('direct question answer exposes an internal participant');
  }
  if (containsBlockedAiTopic(candidate.text)) {
    throw new Error('direct question answer contains a blocked topic');
  }

  if (candidate.status === 'answered') {
    if (candidate.followUpQuestion !== null) {
      throw new Error('answered direct question cannot include a follow-up');
    }
    return;
  }

  if (candidate.followUpQuestion === null) {
    return;
  }

  validateDirectQuestionFollowUp(
    context,
    candidate.followUpQuestion,
  );
}

export function validateProactiveSuggestion(
  context: ProactiveSuggestionContext,
  candidate: ProactiveSuggestionCandidate,
): void {
  try {
    requireNonBlank(candidate.text, 'proactive suggestion', 100);
    validateKoreanCharacterText(candidate.text, 'proactive suggestion');
  } catch (error) {
    throw new ProactiveSuggestionValidationError(
      error instanceof KoreanOutputPolicyError ? error.code : 'invalid_text',
      error instanceof Error ? error.message : 'invalid proactive suggestion',
    );
  }

  if (candidate.text.trim().length < 24) {
    throw new ProactiveSuggestionValidationError(
      'too_short',
      'proactive suggestion must contain at least 24 characters',
    );
  }
  if (
    candidate.kind === 'sunset_card'
    && (context.hasCardToday || context.weather?.nearSunset !== true)
  ) {
    throw new ProactiveSuggestionValidationError(
      'invalid_sunset_context',
      'sunset card suggestion is not valid for this context',
    );
  }
  if (
    !context.hasCardToday
    && context.weather?.nearSunset === true
    && (
      candidate.kind !== 'sunset_card'
      || !/(?:사진|카드)/u.test(candidate.text)
    )
  ) {
    throw new ProactiveSuggestionValidationError(
      'sunset_card_required',
      'sunset context requires a photo or card suggestion',
    );
  }
  if (
    context.hasCardToday
    && (
      candidate.kind === 'card_idea'
      || candidate.kind === 'sunset_card'
      || /카드/u.test(candidate.text)
    )
  ) {
    throw new ProactiveSuggestionValidationError(
      'card_after_upload',
      'card suggestion is not valid after a card was uploaded',
    );
  }
  if (/[.]/u.test(candidate.text.replaceAll('...', ''))) {
    throw new ProactiveSuggestionValidationError(
      'period',
      'proactive suggestion cannot use a period',
    );
  }
  const textWithoutEllipsis = candidate.text.replaceAll('...', '');
  if (/[!?]{2,}|\.\./u.test(textWithoutEllipsis)) {
    throw new ProactiveSuggestionValidationError(
      'excessive_punctuation',
      'proactive suggestion uses excessive punctuation',
    );
  }
  if (
    /(?:해\s*봐|가\s*봐)(?:[!?….\s]|$)|(?:남겨|챙겨)(?:\s*(?:봐|줘|두자|보자))?(?:[!?….]|$)/u
      .test(candidate.text)
  ) {
    throw new ProactiveSuggestionValidationError(
      'commanding_expression',
      'proactive suggestion uses a commanding expression',
    );
  }
  if (
    /(둘의 오늘|우리의 순간|기억 한 조각|추억 한 조각)/u.test(
      candidate.text,
    )
  ) {
    throw new ProactiveSuggestionValidationError(
      'forced_abstract_expression',
      'proactive suggestion uses a forced abstract expression',
    );
  }
  if (
    /노을(?:이|은)?\s*(?:막\s*)?(?:뜨(?:는|고|면|기)|떠오르(?:는|고|면|기))/u
      .test(candidate.text)
  ) {
    throw new ProactiveSuggestionValidationError(
      'unnatural_expression',
      'proactive suggestion uses an unnatural expression',
    );
  }
  if (/(?:^|[^0-9])(?:[01]?[0-9]|2[0-3]):[0-5][0-9](?:[^0-9]|$)/u.test(
    candidate.text,
  )) {
    throw new ProactiveSuggestionValidationError(
      'raw_context_value',
      'proactive suggestion exposes a raw context value',
    );
  }
  if (
    context.weather === null
    && containsWeatherReference(candidate.text)
  ) {
    throw new ProactiveSuggestionValidationError(
      'weather_without_context',
      'proactive suggestion references unavailable weather context',
    );
  }
  if (
    /(비|눈)(?:가|이)\s*(?:오니까|와서|내리니까)/u.test(candidate.text)
    || containsCertainWeatherClaim(candidate.text)
  ) {
    throw new ProactiveSuggestionValidationError(
      'weather_overstatement',
      'proactive suggestion overstates uncertain weather',
    );
  }
  if (containsBlockedAiTopic(candidate.text)) {
    throw new ProactiveSuggestionValidationError(
      'blocked_topic',
      'proactive suggestion contains a blocked topic',
    );
  }
}

function containsWeatherReference(value: string): boolean {
  return /(?:날씨|기온|체감\s*온도|노을|폭염|한파|맑|흐리|선선|쌀쌀|덥|더우|추워|추우|비\s*소식|눈\s*소식|(?:비|눈)(?:가|이)\s*(?:오|내리|쌓|그치))/u
    .test(value);
}

function containsCertainWeatherClaim(value: string): boolean {
  const uncertaintyPattern =
    /(?:수\s*있|것\s*같|듯|가능|예보|소식|괜찮다면|달라질|느껴질)/u;
  if (uncertaintyPattern.test(value)) {
    return false;
  }

  return /(?:(?:날씨|기온|공기|하늘)[^!?…]{0,24}(?:맑|흐리|선선|쌀쌀|더워|더우|추워|추우)[^!?…]{0,16}(?:니까|라서|해서|인데|는데)|(?:폭염|한파)[^!?…]{0,12}(?:이라|이어서|인데|이니까))/u
    .test(value);
}

function validateGeneratedQuestion(
  candidate: PersonalizedQuestionCandidate,
): void {
  requireNonBlank(candidate.questionKey, 'generated question key', 120);
  requireNonBlank(candidate.text, 'generated question', 300);
  validateKoreanCharacterText(candidate.text, 'generated question');
  if (!candidate.text.trimEnd().endsWith('?')) {
    throw new Error('generated question must end with a question mark');
  }
  requireNonBlank(candidate.category, 'generated question category', 100);
  requireNonBlank(candidate.rationale, 'generated question rationale', 500);

  if (
    containsBlockedAiTopic(candidate.text)
    || containsBlockedAiTopic(candidate.category)
  ) {
    throw new Error('personalized question contains a blocked topic');
  }

  if (candidate.mood !== null) {
    requireNonBlank(candidate.mood, 'generated question mood', 100);
  }
}

export function validateDirectQuestionFollowUp(
  context: DirectQuestionContext,
  candidate: DirectQuestionFollowUpCandidate,
): void {
  try {
    requireNonBlank(candidate.questionKey, 'generated question key', 120);
  } catch {
    throw new DirectQuestionFollowUpValidationError('invalid_key');
  }
  try {
    requireNonBlank(candidate.text, 'generated question', 300);
    validateKoreanCharacterText(candidate.text, 'generated question');
  } catch (error) {
    if (error instanceof KoreanOutputPolicyError) {
      throw new DirectQuestionFollowUpValidationError(error.code);
    }
    throw new DirectQuestionFollowUpValidationError('invalid_question');
  }
  try {
    requireNonBlank(candidate.category, 'generated question category', 100);
    requireNonBlank(candidate.rationale, 'generated question rationale', 500);
    if (candidate.mood !== null) {
      requireNonBlank(candidate.mood, 'generated question mood', 100);
    }
  } catch {
    throw new DirectQuestionFollowUpValidationError('invalid_metadata');
  }
  if (
    containsBlockedAiTopic(candidate.text)
    || containsBlockedAiTopic(candidate.category)
  ) {
    throw new DirectQuestionFollowUpValidationError('blocked_topic');
  }

  if (
    !/^direct_follow_up_[a-z0-9_]+_[a-z0-9]{8}$/.test(
      candidate.questionKey,
    )
  ) {
    throw new DirectQuestionFollowUpValidationError('invalid_key');
  }
  if (!candidate.text.endsWith('?')) {
    throw new DirectQuestionFollowUpValidationError('invalid_question');
  }
  if (
    directFollowUpAsymmetricPatterns.some(
      (pattern) => pattern.test(candidate.text),
    )
  ) {
    throw new DirectQuestionFollowUpValidationError('asymmetric_question');
  }
  if (/(?:선호하는\s*)?(?:쪽|편)이\s*더\s*많/u.test(candidate.text)) {
    throw new DirectQuestionFollowUpValidationError('unnatural_question');
  }
  if (
    /여행지(?:에서|에서는)[^?]{0,24}(?:해외여행|국내여행)/u
      .test(candidate.text)
  ) {
    throw new DirectQuestionFollowUpValidationError('unnatural_question');
  }
  if (findKoreanQuestionNaturalnessIssue(candidate.text) !== null) {
    throw new DirectQuestionFollowUpValidationError('unnatural_question');
  }
  const isDuplicate = context.recentSharedQuestionTexts.some(
    (questionText) => areQuestionsNearDuplicate(questionText, candidate.text),
  );
  if (isDuplicate) {
    throw new DirectQuestionFollowUpValidationError('duplicate_question');
  }
  if (!preservesQuestionScope(context.questionText, candidate.text)) {
    throw new DirectQuestionFollowUpValidationError('scope_drift');
  }
}

const politeSpeechEndingPattern =
  /(?:습니다|ㅂ니다|입니다|됩니다|합니다|드립니다|바랍니다|십시오|습니까|입니까|인가요|해요|돼요|이에요|예요|어요|아요|네요|군요|죠|나요|까요|세요)(?=$|[\s.!?…])/u;

function validateKoreanCharacterText(value: string, label: string): void {
  normalizeAndValidateKoreanOutput(value, label);
  if (politeSpeechEndingPattern.test(value)) {
    throw new Error(`${label} must use casual speech`);
  }
}

const directFollowUpAsymmetricPatterns = [
  /(?:^|\s)(?:너는|넌|너가|네가|니가|당신은)(?=$|\s|[!?,'"‘’“”])/u,
  /(?:^|\s)(?:상대|상대방|파트너)(?:은|는|이|가)(?=$|\s)/u,
  /파트너\s*[ab]/iu,
  /partner[_\s-]?[ab]/iu,
  /사용자\s*[ab]/iu,
  /(?:첫|두)\s*번째\s*(?:사용자|사람|파트너)/u,
];

const blockedAiTopicPattern = new RegExp(
  [
    '성관계',
    '성생활',
    '섹스',
    '임신',
    '출산',
    '난임',
    '경제\\s*(상황|문제|고민|사정)',
    '재정',
    '소득',
    '연봉',
    '월급',
    '재산',
    '저축',
    '금전',
    '지출',
    '생활비',
    '대출',
    '부채',
    '빚',
    '돈\\s*(문제|고민|관리)',
    '투자\\s*(금|성향|계획|손실|수익)',
    '건강\\s*(상태|문제|고민|검진)',
    '몸\\s*(상태|건강)',
    '질병',
    '질환',
    '병원',
    '치료',
    '수술',
    '복약',
    '통증',
    '아프',
    '정신건강',
    '정신질환',
    '트라우마',
    '종교',
    '정치',
    '(가족|부모|시댁|처가).{0,30}(갈등|다툼|불화|싸움)',
    'sexual',
    'pregnan',
    'fertility',
    'debt',
    'financial',
    'salary',
    'income',
    'money',
    'loan',
    'investment',
    'physical\\s*health',
    'medical',
    'illness',
    'disease',
    'surgery',
    'medication',
    'mental\\s*health',
    'trauma',
    'religion',
    'politic',
    'family.{0,30}(conflict|fight)',
  ].join('|'),
  'i',
);

export function containsBlockedAiTopic(value: string): boolean {
  return blockedAiTopicPattern.test(value);
}
