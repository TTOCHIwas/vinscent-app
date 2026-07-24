import type {
  DirectQuestionContext,
  LearningDomain,
  PersonalizationMemoryContext,
  PersonalizationRecentQuestionContext,
} from '../domain/learning-contract.ts';

export interface ProactiveSuggestionBaseContext {
  localDate: string;
  localHour: number;
  timezone: string;
  hasCardToday: boolean;
  confirmedMemories: PersonalizationMemoryContext[];
  recentCompletedQuestions: PersonalizationRecentQuestionContext[];
}

const learningDomains = new Set<LearningDomain>([
  'personal_values',
  'emotional_support',
  'communication_repair',
  'daily_life',
  'relationship_strength',
  'future_boundaries',
]);

export function parseDirectQuestionContext(
  value: unknown,
): DirectQuestionContext {
  const record = requireRecord(value);
  const personalization = parsePersonalizationContext(record);

  return {
    questionText: requireString(record.question_text, 300),
    ...personalization,
  };
}

export function parseProactiveSuggestionBaseContext(
  value: unknown,
): ProactiveSuggestionBaseContext {
  const record = requireRecord(value);
  const localHour = record.local_hour;
  if (!Number.isInteger(localHour) || Number(localHour) < 0 || Number(localHour) > 23) {
    throw new TypeError('invalid local hour');
  }

  return {
    localDate: requireDateString(record.local_date),
    localHour: Number(localHour),
    timezone: requireString(record.timezone, 100),
    hasCardToday: requireBoolean(record.has_card_today),
    ...parsePersonalizationContext(record),
  };
}

function parsePersonalizationContext(
  record: Record<string, unknown>,
): Pick<
  DirectQuestionContext,
  'confirmedMemories' | 'recentCompletedQuestions'
> {
  const memories = requireArray(record.confirmed_memories);
  const recentQuestions = requireArray(record.recent_completed_questions);

  return {
    confirmedMemories: memories.map((memory) => {
      const item = requireRecord(memory);
      const subject = item.subject;
      if (subject !== 'me' && subject !== 'partner' && subject !== 'couple') {
        throw new TypeError('invalid personalization memory subject');
      }
      return {
        subject,
        kind: requireString(item.kind, 100),
        domain: requireLearningDomain(item.learning_domain),
        statement: requireString(item.statement, 500),
        confidence: requireConfidence(item.confidence),
      };
    }),
    recentCompletedQuestions: recentQuestions.map((question) => {
      const item = requireRecord(question);
      const answers = requireArray(item.answers);
      if (answers.length !== 2) {
        throw new TypeError('personalization context requires two answers');
      }
      return {
        questionText: requireString(item.question_text, 4000),
        answers: answers.map((answer) => {
          const answerItem = requireRecord(answer);
          const subject = answerItem.subject;
          if (subject !== 'me' && subject !== 'partner') {
            throw new TypeError('invalid recent answer subject');
          }
          return {
            subject,
            text: requireString(answerItem.text, 4000),
          };
        }),
      };
    }),
  };
}

function requireRecord(value: unknown): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new TypeError('expected object');
  }
  return value as Record<string, unknown>;
}

function requireArray(value: unknown): unknown[] {
  if (!Array.isArray(value)) {
    throw new TypeError('expected array');
  }
  return value;
}

function requireString(value: unknown, maximum: number): string {
  if (typeof value !== 'string') {
    throw new TypeError('expected string');
  }
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > maximum) {
    throw new TypeError('invalid string');
  }
  return normalized;
}

function requireBoolean(value: unknown): boolean {
  if (typeof value !== 'boolean') {
    throw new TypeError('expected boolean');
  }
  return value;
}

function requireDateString(value: unknown): string {
  const normalized = requireString(value, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(normalized)) {
    throw new TypeError('invalid date');
  }
  return normalized;
}

function requireLearningDomain(value: unknown): LearningDomain {
  if (
    typeof value !== 'string'
    || !learningDomains.has(value as LearningDomain)
  ) {
    throw new TypeError('invalid learning domain');
  }
  return value as LearningDomain;
}

function requireConfidence(value: unknown): number {
  const parsed = typeof value === 'string' ? Number(value) : value;
  if (
    typeof parsed !== 'number'
    || !Number.isFinite(parsed)
    || parsed < 0
    || parsed > 1
  ) {
    throw new TypeError('invalid memory confidence');
  }
  return parsed;
}
