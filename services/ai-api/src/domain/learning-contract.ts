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

export interface PersonalizedQuestionCandidate {
  questionKey: string;
  text: string;
  category: string;
  mood: string | null;
  rationale: string;
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
    remainingFoundationQuestions: context.remainingFoundationQuestions.map(
      (question) => ({ ...question }),
    ),
  };
}

export function validateMemoryCandidates(
  context: CompletedQuestionContext,
  candidates: MemoryCandidate[],
): void {
  const answersById = validateContextAnswers(context);
  const participantIds = new Set(context.answers.map((answer) => answer.userId));
  const memoryKeys = new Set<string>();

  for (const candidate of candidates) {
    requireNonBlank(candidate.memoryKey, 'memory key', 160);
    requireNonBlank(candidate.kind, 'memory kind', 100);
    requireNonBlank(candidate.statement, 'memory statement', 500);

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
    } else if (candidate.scope === 'couple') {
      if (candidate.subjectUserId !== null) {
        throw new Error('couple memory cannot have a personal subject');
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

    return {
      memoryKey: candidate.memoryKey,
      scope: candidate.scope,
      subjectUserId: subjectUserId ?? null,
      kind: candidate.kind,
      domain: candidate.domain,
      evidenceType: candidate.evidenceType,
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
): void {
  requireNonBlank(candidate.text, 'couple feedback', 80);
  const reactionBody = candidate.text.endsWith('...')
    ? candidate.text.slice(0, -3)
    : /[!?]$/u.test(candidate.text)
    ? candidate.text.slice(0, -1)
    : candidate.text;
  if (/[.!?]/u.test(reactionBody)) {
    throw new Error(
      'couple feedback punctuation allowed endings are !, ?, ..., or none',
    );
  }
  if (
    feedbackAnswerOwnerPatterns.some((pattern) => pattern.test(candidate.text))
  ) {
    throw new Error('couple feedback cannot identify an answer owner');
  }
  if (containsBlockedAiTopic(candidate.text)) {
    throw new Error('couple feedback contains a blocked topic');
  }
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
): void {
  requireNonBlank(candidate.questionKey, 'personalized question key', 120);
  requireNonBlank(candidate.text, 'personalized question', 300);
  requireNonBlank(candidate.category, 'personalized question category', 100);
  requireNonBlank(candidate.rationale, 'personalized question rationale', 500);

  if (
    containsBlockedAiTopic(candidate.text)
    || containsBlockedAiTopic(candidate.category)
  ) {
    throw new Error('personalized question contains a blocked topic');
  }

  if (candidate.mood !== null) {
    requireNonBlank(candidate.mood, 'personalized question mood', 100);
  }
}

const blockedAiTopicPattern = new RegExp(
  [
    '성관계',
    '성생활',
    '섹스',
    '임신',
    '출산',
    '난임',
    '부채',
    '빚',
    '정신건강',
    '정신질환',
    '트라우마',
    '종교',
    '정치',
    '가족\\s*(갈등|다툼)',
    'sexual',
    'pregnan',
    'fertility',
    'debt',
    'mental\\s*health',
    'trauma',
    'religion',
    'politic',
    'family\\s*conflict',
  ].join('|'),
  'i',
);

function containsBlockedAiTopic(value: string): boolean {
  return blockedAiTopicPattern.test(value);
}
