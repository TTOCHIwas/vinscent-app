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
  statement: string;
  confidence: number;
}

export interface FoundationQuestionCandidate {
  questionKey: string;
  text: string;
  domain: LearningDomain;
}

export interface CompletedQuestionContext {
  coupleId: string;
  question: {
    dailyQuestionId: string;
    questionId: string;
    text: string;
    domain: LearningDomain | null;
  };
  answers: CompletedQuestionAnswer[];
  confirmedMemories: ConfirmedMemoryContext[];
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
    statement: string;
    confidence: number;
  }>;
  remainingFoundationQuestions: FoundationQuestionCandidate[];
}

export interface MemoryCandidate {
  memoryKey: string;
  scope: 'personal' | 'couple';
  subjectUserId: string | null;
  kind: string;
  statement: string;
  confidence: number;
  evidenceAnswerIds: string[];
}

export interface ModelMemoryCandidate {
  memoryKey: string;
  scope: 'personal' | 'couple';
  subjectParticipantKey: ParticipantKey | null;
  kind: string;
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

  return {
    question: { ...context.question },
    answers: context.answers.map((answer) => ({
      answerId: answer.answerId,
      participantKey: participants.get(answer.userId)!,
      text: answer.text,
    })),
    confirmedMemories: context.confirmedMemories.map((memory) => {
      const subjectParticipantKey = memory.subjectUserId === null
        ? null
        : participants.get(memory.subjectUserId);

      if (memory.scope === 'personal' && subjectParticipantKey === undefined) {
        throw new Error('confirmed memory has an unknown personal subject');
      }
      if (memory.scope === 'couple' && memory.subjectUserId !== null) {
        throw new Error('couple memory cannot have a personal subject');
      }

      return {
        memoryKey: memory.memoryKey,
        scope: memory.scope,
        subjectParticipantKey: subjectParticipantKey ?? null,
        kind: memory.kind,
        statement: memory.statement,
        confidence: memory.confidence,
      };
    }),
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
  requireNonBlank(candidate.text, 'couple feedback', 500);
}

export function validatePersonalizedQuestion(
  candidate: PersonalizedQuestionCandidate,
): void {
  requireNonBlank(candidate.questionKey, 'personalized question key', 120);
  requireNonBlank(candidate.text, 'personalized question', 300);
  requireNonBlank(candidate.category, 'personalized question category', 100);
  requireNonBlank(candidate.rationale, 'personalized question rationale', 500);

  if (candidate.mood !== null) {
    requireNonBlank(candidate.mood, 'personalized question mood', 100);
  }
}
