import {
  validateProactiveSuggestion,
  type PersonalizationMemoryContext,
  type PersonalizationRecentQuestionContext,
  type ProactiveSuggestionCandidate,
  type ProactiveSuggestionContext,
  type ProactiveWeatherContext,
} from '../domain/learning-contract.ts';
import type {
  LearningModelResult,
} from './learning-model-port.ts';

export interface ProactiveSuggestionBaseContext {
  localDate: string;
  localHour: number;
  timezone: string;
  hasCardToday: boolean;
  confirmedMemories: PersonalizationMemoryContext[];
  recentCompletedQuestions: PersonalizationRecentQuestionContext[];
}

export interface ProactiveSuggestionCoordinates {
  latitude: number;
  longitude: number;
}

export interface ProactiveSuggestionContextSource {
  loadForUser(userId: string): Promise<ProactiveSuggestionBaseContext>;
}

export interface ProactiveSuggestionModel {
  generateProactiveSuggestion(
    context: ProactiveSuggestionContext,
  ): Promise<LearningModelResult<ProactiveSuggestionCandidate>>;
}

export interface ProactiveSuggestionWeatherClient {
  fetchContext(
    latitude: number,
    longitude: number,
    now?: Date,
  ): Promise<ProactiveWeatherContext>;
}

export interface GeneratedProactiveSuggestion {
  suggestionId: string;
  text: string;
  kind: ProactiveSuggestionCandidate['kind'];
  generatedAt: string;
  validUntil: string;
  contextDate: string;
  hasCardToday: boolean;
}

export type ProactiveSuggestionContextErrorCode =
  | 'ai_personalization_not_ready'
  | 'ai_suggestion_context_unavailable';

export class ProactiveSuggestionContextError extends Error {
  readonly code: ProactiveSuggestionContextErrorCode;

  constructor(code: ProactiveSuggestionContextErrorCode, cause?: unknown) {
    super(code, { cause });
    this.name = 'ProactiveSuggestionContextError';
    this.code = code;
  }
}

interface GenerateProactiveSuggestionOptions {
  contextSource: ProactiveSuggestionContextSource;
  model: ProactiveSuggestionModel;
  weatherClient: ProactiveSuggestionWeatherClient | null;
  now?: () => Date;
  generateId?: () => string;
}

export class GenerateProactiveSuggestionUseCase {
  readonly #contextSource: ProactiveSuggestionContextSource;
  readonly #model: ProactiveSuggestionModel;
  readonly #weatherClient: ProactiveSuggestionWeatherClient | null;
  readonly #now: () => Date;
  readonly #generateId: () => string;

  constructor(options: GenerateProactiveSuggestionOptions) {
    this.#contextSource = options.contextSource;
    this.#model = options.model;
    this.#weatherClient = options.weatherClient;
    this.#now = options.now ?? (() => new Date());
    this.#generateId = options.generateId ?? (() => crypto.randomUUID());
  }

  async execute(input: {
    userId: string;
    coordinates: ProactiveSuggestionCoordinates | null;
  }): Promise<GeneratedProactiveSuggestion> {
    const userId = requireNonBlank(input.userId, 'user id', 160);
    validateCoordinates(input.coordinates);
    const baseContext = await this.#contextSource.loadForUser(userId);
    const generatedAt = this.#now();
    if (!Number.isFinite(generatedAt.getTime())) {
      throw new RangeError('current time must be valid');
    }

    const weather = await this.#loadWeather(input.coordinates, generatedAt);
    const context: ProactiveSuggestionContext = {
      localDate: baseContext.localDate,
      localHour: baseContext.localHour,
      hasCardToday: baseContext.hasCardToday,
      confirmedMemories: baseContext.confirmedMemories,
      recentCompletedQuestions: baseContext.recentCompletedQuestions,
      weather,
    };
    const result = await this.#model.generateProactiveSuggestion(context);
    validateProactiveSuggestion(context, result.value);

    const lifetimeMinutes = result.value.kind === 'sunset_card' ? 45 : 180;
    const desiredValidUntil = new Date(
      generatedAt.getTime() + lifetimeMinutes * 60 * 1000,
    );
    const validUntil = clampToLocalDate(
      desiredValidUntil,
      generatedAt,
      baseContext.localDate,
      baseContext.timezone,
    );

    return {
      suggestionId: requireNonBlank(
        this.#generateId(),
        'suggestion id',
        160,
      ),
      text: result.value.text,
      kind: result.value.kind,
      generatedAt: generatedAt.toISOString(),
      validUntil: validUntil.toISOString(),
      contextDate: baseContext.localDate,
      hasCardToday: baseContext.hasCardToday,
    };
  }

  async #loadWeather(
    coordinates: ProactiveSuggestionCoordinates | null,
    now: Date,
  ): Promise<ProactiveWeatherContext | null> {
    if (coordinates === null || this.#weatherClient === null) {
      return null;
    }

    try {
      return await this.#weatherClient.fetchContext(
        coordinates.latitude,
        coordinates.longitude,
        now,
      );
    } catch {
      return null;
    }
  }
}

function clampToLocalDate(
  desired: Date,
  now: Date,
  contextDate: string,
  timezone: string,
): Date {
  const clamped = new Date(desired);
  while (
    clamped.getTime() > now.getTime()
    && localDateInTimeZone(clamped, timezone) !== contextDate
  ) {
    clamped.setTime(clamped.getTime() - 60 * 1000);
  }
  return clamped;
}

function localDateInTimeZone(value: Date, timezone: string): string {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(value);
  const year = parts.find((part) => part.type === 'year')?.value;
  const month = parts.find((part) => part.type === 'month')?.value;
  const day = parts.find((part) => part.type === 'day')?.value;
  if (year === undefined || month === undefined || day === undefined) {
    throw new TypeError('invalid context timezone');
  }
  return `${year}-${month}-${day}`;
}

function validateCoordinates(
  coordinates: ProactiveSuggestionCoordinates | null,
): void {
  if (coordinates === null) {
    return;
  }
  if (
    !Number.isFinite(coordinates.latitude)
    || coordinates.latitude < -90
    || coordinates.latitude > 90
    || !Number.isFinite(coordinates.longitude)
    || coordinates.longitude < -180
    || coordinates.longitude > 180
  ) {
    throw new RangeError('invalid proactive suggestion coordinates');
  }
}

function requireNonBlank(
  value: string,
  name: string,
  maximum: number,
): string {
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > maximum) {
    throw new RangeError(`${name} must contain 1 to ${maximum} characters`);
  }
  return normalized;
}
