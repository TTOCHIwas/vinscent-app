import type {
  ProactiveWeatherCondition,
  ProactiveWeatherContext,
} from '../domain/learning-contract.ts';

export interface WeatherForecastClient {
  fetchContext(
    latitude: number,
    longitude: number,
    now?: Date,
  ): Promise<ProactiveWeatherContext>;
}

interface OpenMeteoForecastClientOptions {
  endpoint?: string;
  apiKey?: string;
  timeoutMs?: number;
  fetchImpl?: typeof fetch;
}

export class OpenMeteoForecastClient implements WeatherForecastClient {
  readonly #endpoint: string;
  readonly #apiKey: string | null;
  readonly #timeoutMs: number;
  readonly #fetch: typeof fetch;

  constructor(options: OpenMeteoForecastClientOptions = {}) {
    this.#endpoint = normalizeEndpoint(
      options.endpoint ?? 'https://api.open-meteo.com/v1/forecast',
    );
    this.#apiKey = normalizeOptional(options.apiKey);
    this.#timeoutMs = options.timeoutMs ?? 5000;
    this.#fetch = options.fetchImpl ?? fetch;

    if (!Number.isInteger(this.#timeoutMs) || this.#timeoutMs < 1000) {
      throw new RangeError('weather timeout must be at least 1000ms');
    }
  }

  async fetchContext(
    latitude: number,
    longitude: number,
    now = new Date(),
  ): Promise<ProactiveWeatherContext> {
    validateCoordinate(latitude, -90, 90, 'latitude');
    validateCoordinate(longitude, -180, 180, 'longitude');

    const url = new URL(this.#endpoint);
    url.searchParams.set('latitude', roundCoordinate(latitude).toString());
    url.searchParams.set('longitude', roundCoordinate(longitude).toString());
    url.searchParams.set(
      'current',
      'apparent_temperature,weather_code,cloud_cover,precipitation',
    );
    url.searchParams.set('hourly', 'precipitation_probability');
    url.searchParams.set('daily', 'sunset');
    url.searchParams.set('forecast_hours', '4');
    url.searchParams.set('forecast_days', '2');
    url.searchParams.set('timezone', 'auto');
    url.searchParams.set('timeformat', 'unixtime');
    if (this.#apiKey !== null) {
      url.searchParams.set('apikey', this.#apiKey);
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.#timeoutMs);
    let response: Response;
    try {
      response = await this.#fetch(url, { signal: controller.signal });
    } finally {
      clearTimeout(timeout);
    }

    if (!response.ok) {
      throw new Error(`weather_provider_${response.status}`);
    }

    return parseForecast(await response.json(), now);
  }
}

function parseForecast(
  value: unknown,
  now: Date,
): ProactiveWeatherContext {
  const root = requireRecord(value);
  const current = requireRecord(root.current);
  const hourly = requireRecord(root.hourly);
  const daily = requireRecord(root.daily);
  const apparentTemperature = requireNullableNumber(
    current.apparent_temperature,
  );
  const weatherCode = requireNullableInteger(current.weather_code);
  const cloudCover = requireNullableNumber(current.cloud_cover);
  const precipitation = requireNullableNumber(current.precipitation) ?? 0;
  const precipitationProbabilities = requireNumberArray(
    hourly.precipitation_probability,
  ).slice(0, 4);
  const maximumPrecipitationProbability = precipitationProbabilities.length === 0
    ? 0
    : Math.max(...precipitationProbabilities);
  const precipitationPossible = precipitation > 0.1
    || maximumPrecipitationProbability >= 40
    || isRainCode(weatherCode)
    || isSnowCode(weatherCode);
  const sunset = selectRelevantSunset(
    requireNumberArray(daily.sunset),
    now,
  );
  const nearSunset = sunset !== null
    && now.getTime() >= sunset.getTime() - 90 * 60 * 1000
    && now.getTime() <= sunset.getTime() + 15 * 60 * 1000;
  const timezone = requireOptionalString(root.timezone);

  return {
    condition: deriveCondition({
      weatherCode,
      cloudCover,
      apparentTemperature,
    }),
    apparentTemperatureC: apparentTemperature,
    precipitationPossible,
    nearSunset,
    sunsetLocalTime: sunset === null || timezone === null
      ? null
      : formatLocalTime(sunset, timezone),
  };
}

function deriveCondition({
  weatherCode,
  cloudCover,
  apparentTemperature,
}: {
  weatherCode: number | null;
  cloudCover: number | null;
  apparentTemperature: number | null;
}): ProactiveWeatherCondition {
  if (isSnowCode(weatherCode)) {
    return 'snow_possible';
  }
  if (isRainCode(weatherCode)) {
    return 'rain_possible';
  }
  if (apparentTemperature !== null && apparentTemperature >= 33) {
    return 'hot';
  }
  if (apparentTemperature !== null && apparentTemperature <= 3) {
    return 'cold';
  }
  if (weatherCode === 0 || (weatherCode === null && cloudCover !== null && cloudCover <= 20)) {
    return 'clear';
  }
  if (
    weatherCode === 1
    || weatherCode === 2
    || (
      weatherCode === null
      && cloudCover !== null
      && cloudCover <= 70
    )
  ) {
    return 'partly_cloudy';
  }
  if (
    weatherCode === 3
    || weatherCode === 45
    || weatherCode === 48
    || (weatherCode === null && cloudCover !== null)
  ) {
    return 'cloudy';
  }
  return 'unknown';
}

function isRainCode(code: number | null): boolean {
  return code !== null
    && (
      (code >= 51 && code <= 67)
      || (code >= 80 && code <= 82)
      || (code >= 95 && code <= 99)
    );
}

function isSnowCode(code: number | null): boolean {
  return code !== null
    && (
      (code >= 71 && code <= 77)
      || (code >= 85 && code <= 86)
    );
}

function selectRelevantSunset(values: number[], now: Date): Date | null {
  const earliestRelevant = now.getTime() - 15 * 60 * 1000;
  for (const value of values) {
    const candidate = new Date(value * 1000);
    if (candidate.getTime() >= earliestRelevant) {
      return candidate;
    }
  }
  return null;
}

function formatLocalTime(value: Date, timezone: string): string | null {
  try {
    return new Intl.DateTimeFormat('ko-KR', {
      timeZone: timezone,
      hour: '2-digit',
      minute: '2-digit',
      hourCycle: 'h23',
    }).format(value);
  } catch {
    return null;
  }
}

function normalizeEndpoint(value: string): string {
  const normalized = value.trim();
  const url = new URL(normalized);
  if (url.protocol !== 'https:') {
    throw new TypeError('weather endpoint must use HTTPS');
  }
  return url.toString();
}

function normalizeOptional(value: string | undefined): string | null {
  const normalized = value?.trim();
  return normalized ? normalized : null;
}

function roundCoordinate(value: number): number {
  return Math.round(value * 100) / 100;
}

function validateCoordinate(
  value: number,
  minimum: number,
  maximum: number,
  label: string,
): void {
  if (!Number.isFinite(value) || value < minimum || value > maximum) {
    throw new RangeError(`invalid ${label}`);
  }
}

function requireRecord(value: unknown): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new TypeError('invalid weather response');
  }
  return value as Record<string, unknown>;
}

function requireNullableNumber(value: unknown): number | null {
  if (value === null || value === undefined) {
    return null;
  }
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new TypeError('invalid weather number');
  }
  return value;
}

function requireNullableInteger(value: unknown): number | null {
  const parsed = requireNullableNumber(value);
  if (parsed !== null && !Number.isInteger(parsed)) {
    throw new TypeError('invalid weather integer');
  }
  return parsed;
}

function requireNumberArray(value: unknown): number[] {
  if (!Array.isArray(value)) {
    throw new TypeError('invalid weather array');
  }
  return value.filter(
    (item): item is number => typeof item === 'number' && Number.isFinite(item),
  );
}

function requireOptionalString(value: unknown): string | null {
  if (value === null || value === undefined) {
    return null;
  }
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new TypeError('invalid weather timezone');
  }
  return value.trim();
}
