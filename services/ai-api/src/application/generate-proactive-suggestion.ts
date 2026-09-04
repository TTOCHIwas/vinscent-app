import type {
  PersonalizationMemoryContext,
  PersonalizationRecentQuestionContext,
  ProactiveSuggestionCandidate,
  ProactiveWeatherContext,
} from '../domain/learning-contract.ts';
import {
  CuratedProactiveSuggestionSelector,
  type CuratedProactiveSuggestionSelectionContext,
} from './curated-proactive-suggestion-selector.ts';

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

export interface ProactiveSuggestionQuota {
  claimGeneration(userId: string, contextDate: string): Promise<boolean>;
}

export interface ProactiveSuggestionSelector {
  select(
    context: CuratedProactiveSuggestionSelectionContext,
  ): ProactiveSuggestionCandidate;
}

export interface ProactiveSuggestionWeatherRequest {
  latitude: number;
  longitude: number;
  now: Date;
  localDate: string;
  timezone: string;
}

export interface ProactiveSuggestionWeatherClient {
  fetchContext(
    request: ProactiveSuggestionWeatherRequest,
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
  | 'ai_proactive_daily_limit_reached'
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
  quota: ProactiveSuggestionQuota;
  selector?: ProactiveSuggestionSelector;
  weatherClient: ProactiveSuggestionWeatherClient | null;
  now?: () => Date;
  generateId?: () => string;
}

export class GenerateProactiveSuggestionUseCase {
  readonly #contextSource: ProactiveSuggestionContextSource;
  readonly #quota: ProactiveSuggestionQuota;
  readonly #selector: ProactiveSuggestionSelector;
  readonly #weatherClient: ProactiveSuggestionWeatherClient | null;
  readonly #now: () => Date;
  readonly #generateId: () => string;

  constructor(options: GenerateProactiveSuggestionOptions) {
    this.#contextSource = options.contextSource;
    this.#quota = options.quota;
    this.#selector = options.selector
      ?? new CuratedProactiveSuggestionSelector();
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
    await this.#claimGeneration(userId, baseContext.localDate);
    const generatedAt = this.#now();
    if (!Number.isFinite(generatedAt.getTime())) {
      throw new RangeError('current time must be valid');
    }

    const weather = await this.#loadWeather(
      input.coordinates,
      generatedAt,
      baseContext,
    );
    const candidate = this.#selector.select({
      userId,
      localDate: baseContext.localDate,
      localHour: baseContext.localHour,
      hasCardToday: baseContext.hasCardToday,
      recordingAvailable: true,
      weather,
    });

    const lifetimeMinutes = candidate.kind === 'sunset_card' ? 45 : 180;
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
      text: candidate.text,
      kind: candidate.kind,
      generatedAt: generatedAt.toISOString(),
      validUntil: validUntil.toISOString(),
      contextDate: baseContext.localDate,
      hasCardToday: baseContext.hasCardToday,
    };
  }

  async #claimGeneration(userId: string, contextDate: string): Promise<void> {
    if (!await this.#quota.claimGeneration(userId, contextDate)) {
      throw new ProactiveSuggestionContextError(
        'ai_proactive_daily_limit_reached',
      );
    }
  }

  async #loadWeather(
    coordinates: ProactiveSuggestionCoordinates | null,
    now: Date,
    baseContext: ProactiveSuggestionBaseContext,
  ): Promise<ProactiveWeatherContext | null> {
    if (coordinates === null || this.#weatherClient === null) {
      return null;
    }

    try {
      return await this.#weatherClient.fetchContext({
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        now,
        localDate: baseContext.localDate,
        timezone: baseContext.timezone,
      });
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
