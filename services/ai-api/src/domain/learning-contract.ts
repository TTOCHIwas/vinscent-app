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
}

export interface DirectQuestionAnswer {
  text: string;
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
  validateGeneratedQuestion(candidate);
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
  candidate: DirectQuestionAnswer,
): void {
  requireNonBlank(candidate.text, 'direct question answer', 400);

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
}

export function validateProactiveSuggestion(
  context: ProactiveSuggestionContext,
  candidate: ProactiveSuggestionCandidate,
): void {
  requireNonBlank(candidate.text, 'proactive suggestion', 100);

  if (candidate.text.trim().length < 35) {
    throw new RangeError('proactive suggestion must contain at least 35 characters');
  }
  if (
    candidate.kind === 'sunset_card'
    && (context.hasCardToday || context.weather?.nearSunset !== true)
  ) {
    throw new Error('sunset card suggestion is not valid for this context');
  }
  if (
    context.hasCardToday
    && (
      candidate.kind === 'card_idea'
      || candidate.kind === 'sunset_card'
      || /카드/u.test(candidate.text)
    )
  ) {
    throw new Error('card suggestion is not valid after a card was uploaded');
  }
  if (/[.]/u.test(candidate.text.replaceAll('...', ''))) {
    throw new Error('proactive suggestion cannot use a period');
  }
  const textWithoutEllipsis = candidate.text.replaceAll('...', '');
  if (/[!?]{2,}|\.\./u.test(textWithoutEllipsis)) {
    throw new Error('proactive suggestion uses excessive punctuation');
  }
  if (
    /(해\s*봐|가\s*봐|남겨|챙겨)(?:[!?….\s]|$)/u.test(candidate.text)
  ) {
    throw new Error('proactive suggestion uses a commanding expression');
  }
  if (
    /(둘의 오늘|우리의 순간|기억 한 조각|추억 한 조각)/u.test(
      candidate.text,
    )
  ) {
    throw new Error('proactive suggestion uses a forced abstract expression');
  }
  if (
    /(비|눈)(?:가|이)\s*(?:오니까|와서|내리니까)/u.test(candidate.text)
  ) {
    throw new Error('proactive suggestion overstates uncertain weather');
  }
  if (containsBlockedAiTopic(candidate.text)) {
    throw new Error('proactive suggestion contains a blocked topic');
  }
}

function validateGeneratedQuestion(
  candidate: PersonalizedQuestionCandidate,
): void {
  requireNonBlank(candidate.questionKey, 'generated question key', 120);
  requireNonBlank(candidate.text, 'generated question', 300);
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
