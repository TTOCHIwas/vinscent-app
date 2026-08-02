import {
  ProactiveSuggestionValidationError,
  validateProactiveSuggestion,
  type PersonalizationMemoryContext,
  type PersonalizationRecentQuestionContext,
  type ProactiveSuggestionCandidate,
  type ProactiveSuggestionContext,
  type ProactiveWeatherContext,
} from '../domain/learning-contract.ts';
import {
  LearningModelError,
  type LearningModelResult,
  type ProactiveSuggestionGenerationOptions,
} from './learning-model-port.ts';
import { rejectedModelTextForRetry } from './model-output-retry.ts';

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

export interface ProactiveSuggestionModel {
  generateProactiveSuggestion(
    context: ProactiveSuggestionContext,
    options?: ProactiveSuggestionGenerationOptions,
  ): Promise<LearningModelResult<ProactiveSuggestionCandidate>>;
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
  model: ProactiveSuggestionModel;
  weatherClient: ProactiveSuggestionWeatherClient | null;
  now?: () => Date;
  generateId?: () => string;
}

export class GenerateProactiveSuggestionUseCase {
  readonly #contextSource: ProactiveSuggestionContextSource;
  readonly #quota: ProactiveSuggestionQuota;
  readonly #model: ProactiveSuggestionModel;
  readonly #weatherClient: ProactiveSuggestionWeatherClient | null;
  readonly #now: () => Date;
  readonly #generateId: () => string;

  constructor(options: GenerateProactiveSuggestionOptions) {
    this.#contextSource = options.contextSource;
    this.#quota = options.quota;
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
    const context: ProactiveSuggestionContext = {
      localDate: baseContext.localDate,
      localHour: baseContext.localHour,
      hasCardToday: baseContext.hasCardToday,
      confirmedMemories: baseContext.confirmedMemories,
      recentCompletedQuestions: baseContext.recentCompletedQuestions,
      weather,
    };
    const candidate = await this.#generateValidCandidate(
      context,
      userId,
      baseContext.localDate,
    );

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

  async #generateValidCandidate(
    context: ProactiveSuggestionContext,
    userId: string,
    contextDate: string,
  ): Promise<ProactiveSuggestionCandidate> {
    let rejectedText: string | null = null;
    let rejectionCode: ProactiveSuggestionGenerationOptions['rejectionCode'] =
      null;

    for (let attempt = 0; attempt < 2; attempt += 1) {
      if (attempt > 0) {
        await this.#claimGeneration(userId, contextDate);
      }
      let result: LearningModelResult<ProactiveSuggestionCandidate>;
      try {
        result = await this.#model.generateProactiveSuggestion(
          context,
          { rejectedText, rejectionCode },
        );
      } catch (error) {
        if (
          !(error instanceof LearningModelError)
          || error.code !== 'model_invalid_output'
        ) {
          throw error;
        }
        if (attempt === 1) {
          return buildProactiveSuggestionFallback(context);
        }
        rejectedText = null;
        rejectionCode = 'invalid_structure';
        continue;
      }

      try {
        validateProactiveSuggestion(context, result.value);
        return result.value;
      } catch (error) {
        const validationCode = error instanceof ProactiveSuggestionValidationError
          ? error.code
          : 'candidate_validation_failed';
        if (attempt === 1) {
          return buildProactiveSuggestionFallback(context);
        }
        rejectedText = rejectedModelTextForRetry(
          result.value.text,
          validationCode,
        );
        rejectionCode = validationCode;
      }
    }

    throw new Error('proactive suggestion generation exhausted');
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

function buildProactiveSuggestionFallback(
  context: ProactiveSuggestionContext,
): ProactiveSuggestionCandidate {
  const candidate = resolveProactiveSuggestionFallback(context);
  validateProactiveSuggestion(context, candidate);
  return candidate;
}

function resolveProactiveSuggestionFallback(
  context: ProactiveSuggestionContext,
): ProactiveSuggestionCandidate {
  const weather = context.weather;

  if (context.hasCardToday) {
    if (weather?.condition === 'hot' ||
      (weather?.apparentTemperatureC ?? -Infinity) >= 32) {
      return {
        text: '밖에서 오래 보내기 부담스러울 수 있으니 가까운 실내에서 함께 쉬는 건 어때?',
        kind: 'date_idea',
      };
    }
    if (weather?.precipitationPossible === true) {
      return {
        text: '날씨가 달라질 수 있으니 가까운 실내에서 함께 느긋하게 보내면 좋겠다',
        kind: 'date_idea',
      };
    }
    if (weather?.condition === 'cold') {
      return {
        text: '쌀쌀하게 느껴질 수 있는 날엔 가까운 실내에서 따뜻한 차를 함께 마시는 건 어때?',
        kind: 'date_idea',
      };
    }
    return {
      text: '오늘은 둘이 좋아하는 간식을 천천히 나눠 먹으며 쉬는 건 어때?',
      kind: 'date_idea',
    };
  }

  if (weather?.nearSunset === true) {
    return {
      text: '곧 노을 질 시간인데 하늘이 괜찮다면 사진 한 장 찍어서 카드로 남겨도 예쁘겠다',
      kind: 'sunset_card',
    };
  }
  if (weather?.condition === 'hot' ||
    (weather?.apparentTemperatureC ?? -Infinity) >= 32) {
    return {
      text: '밖에서 오래 보내기 부담스러울 수 있으니 가까운 실내에서 함께 쉬는 건 어때?',
      kind: 'date_idea',
    };
  }
  if (weather?.condition === 'rain_possible') {
    return {
      text: '비 소식은 달라질 수 있으니 가까운 실내에서 함께 느긋하게 보내면 좋겠다',
      kind: 'date_idea',
    };
  }
  if (weather?.condition === 'snow_possible') {
    return {
      text: '눈 소식은 달라질 수 있으니 가까운 실내에서 따뜻하게 쉬면 좋겠다',
      kind: 'date_idea',
    };
  }
  if (weather?.precipitationPossible === true) {
    return {
      text: '날씨가 달라질 수 있으니 가까운 실내에서 함께 느긋하게 보내면 좋겠다',
      kind: 'date_idea',
    };
  }
  if (weather?.condition === 'cold') {
    return {
      text: '쌀쌀하게 느껴질 수 있는 날엔 가까운 실내에서 따뜻한 차를 함께 마시는 건 어때?',
      kind: 'date_idea',
    };
  }
  return {
    text: '오늘 함께한 작은 장면 하나를 사진이나 카드로 남겨도 예쁘겠다',
    kind: 'card_idea',
  };
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
