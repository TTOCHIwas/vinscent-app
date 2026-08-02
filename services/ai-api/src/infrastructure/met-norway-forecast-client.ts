import type {
  ProactiveSuggestionWeatherClient,
  ProactiveSuggestionWeatherRequest,
} from '../application/generate-proactive-suggestion.ts';
import type {
  ProactiveWeatherCondition,
  ProactiveWeatherContext,
} from '../domain/learning-contract.ts';

interface MetNorwayForecastClientOptions {
  forecastEndpoint?: string;
  sunriseEndpoint?: string;
  userAgent: string;
  timeoutMs?: number;
  fetchImpl?: typeof fetch;
}

interface CachedProviderResponse {
  body: unknown;
  expiresAt: number;
  lastModified: string | null;
}

interface ForecastEntry {
  time: Date;
  data: Record<string, unknown>;
}

const defaultForecastEndpoint =
  'https://api.met.no/weatherapi/locationforecast/2.0/compact';
const defaultSunriseEndpoint =
  'https://api.met.no/weatherapi/sunrise/3.0/sun';
const defaultForecastTtlMs = 30 * 60 * 1000;
const defaultSunriseTtlMs = 6 * 60 * 60 * 1000;
const maximumCacheEntries = 256;

export class MetNorwayForecastClient
  implements ProactiveSuggestionWeatherClient {
  readonly #forecastEndpoint: string;
  readonly #sunriseEndpoint: string;
  readonly #userAgent: string;
  readonly #timeoutMs: number;
  readonly #fetch: typeof fetch;
  readonly #cache = new Map<string, CachedProviderResponse>();
  readonly #inFlight = new Map<string, Promise<unknown>>();

  constructor(options: MetNorwayForecastClientOptions) {
    this.#forecastEndpoint = normalizeEndpoint(
      options.forecastEndpoint ?? defaultForecastEndpoint,
    );
    this.#sunriseEndpoint = normalizeEndpoint(
      options.sunriseEndpoint ?? defaultSunriseEndpoint,
    );
    this.#userAgent = requireNonBlank(options.userAgent, 'weather user agent');
    this.#timeoutMs = options.timeoutMs ?? 5000;
    this.#fetch = options.fetchImpl ?? fetch;

    if (!Number.isInteger(this.#timeoutMs) || this.#timeoutMs < 1000) {
      throw new RangeError('weather timeout must be at least 1000ms');
    }
  }

  async fetchContext(
    request: ProactiveSuggestionWeatherRequest,
  ): Promise<ProactiveWeatherContext> {
    validateRequest(request);
    const latitude = roundCoordinate(request.latitude);
    const longitude = roundCoordinate(request.longitude);
    const forecastUrl = createLocationUrl(
      this.#forecastEndpoint,
      latitude,
      longitude,
    );
    const sunriseUrl = createLocationUrl(
      this.#sunriseEndpoint,
      latitude,
      longitude,
    );
    sunriseUrl.searchParams.set('date', request.localDate);

    const [forecast, sunrise] = await Promise.all([
      this.#fetchJson(
        forecastUrl,
        request.now,
        defaultForecastTtlMs,
      ),
      this.#fetchJson(
        sunriseUrl,
        request.now,
        defaultSunriseTtlMs,
      ),
    ]);

    return parseContext(forecast, sunrise, request);
  }

  async #fetchJson(
    url: URL,
    now: Date,
    fallbackTtlMs: number,
  ): Promise<unknown> {
    const key = url.toString();
    const cached = this.#cache.get(key);
    if (cached !== undefined && now.getTime() < cached.expiresAt) {
      return cached.body;
    }

    const pending = this.#inFlight.get(key);
    if (pending !== undefined) {
      return pending;
    }

    const request = this.#requestAndCache(
      key,
      url,
      now,
      fallbackTtlMs,
      cached,
    );
    this.#inFlight.set(key, request);
    try {
      return await request;
    } finally {
      this.#inFlight.delete(key);
    }
  }

  async #requestAndCache(
    key: string,
    url: URL,
    now: Date,
    fallbackTtlMs: number,
    cached: CachedProviderResponse | undefined,
  ): Promise<unknown> {
    const headers = new Headers({
      accept: 'application/json',
      'user-agent': this.#userAgent,
    });
    if (cached?.lastModified !== null && cached?.lastModified !== undefined) {
      headers.set('if-modified-since', cached.lastModified);
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.#timeoutMs);
    let response: Response;
    try {
      response = await this.#fetch(url, {
        headers,
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timeout);
    }

    const expiresAt = resolveExpiry(response, now, fallbackTtlMs);
    if (response.status === 304 && cached !== undefined) {
      this.#storeCache(key, {
        ...cached,
        expiresAt,
      });
      return cached.body;
    }
    if (!response.ok) {
      throw new Error(`weather_provider_${response.status}`);
    }

    const body = await response.json();
    this.#storeCache(key, {
      body,
      expiresAt,
      lastModified: normalizeHeader(response.headers.get('last-modified')),
    });
    return body;
  }

  #storeCache(key: string, value: CachedProviderResponse): void {
    this.#cache.delete(key);
    this.#cache.set(key, value);
    while (this.#cache.size > maximumCacheEntries) {
      const oldestKey = this.#cache.keys().next().value;
      if (typeof oldestKey !== 'string') {
        break;
      }
      this.#cache.delete(oldestKey);
    }
  }
}

function parseContext(
  forecastValue: unknown,
  sunriseValue: unknown,
  request: ProactiveSuggestionWeatherRequest,
): ProactiveWeatherContext {
  const entries = selectForecastEntries(forecastValue, request.now);
  const nearest = entries.reduce((current, candidate) =>
    Math.abs(candidate.time.getTime() - request.now.getTime())
        < Math.abs(current.time.getTime() - request.now.getTime())
      ? candidate
      : current
  );
  const nearestInstant = requireRecord(
    requireRecord(nearest.data.instant).details,
  );
  const airTemperature = requireNullableNumber(
    nearestInstant.air_temperature,
  );
  const cloudAreaFraction = requireNullableNumber(
    nearestInstant.cloud_area_fraction,
  );
  const relativeHumidity = requireNullableNumber(
    nearestInstant.relative_humidity,
  );
  const windSpeed = requireNullableNumber(nearestInstant.wind_speed);
  const apparentTemperature = estimateApparentTemperature(
    airTemperature,
    relativeHumidity,
    windSpeed,
  );
  const symbols = entries
    .map(readSymbolCode)
    .filter((value): value is string => value !== null);
  const precipitationPossible = entries.some(
    (entry) => (readPrecipitationAmount(entry) ?? 0) > 0.1,
  ) || symbols.some(isPrecipitationSymbol);
  const sunset = parseSunset(sunriseValue);
  const nearSunset = sunset !== null
    && request.now.getTime() >= sunset.getTime() - 90 * 60 * 1000
    && request.now.getTime() <= sunset.getTime() + 15 * 60 * 1000;

  return {
    condition: deriveCondition({
      symbols,
      cloudAreaFraction,
      apparentTemperature,
    }),
    apparentTemperatureC: apparentTemperature,
    precipitationPossible,
    nearSunset,
    sunsetLocalTime: sunset === null
      ? null
      : formatLocalTime(sunset, request.timezone),
  };
}

function selectForecastEntries(value: unknown, now: Date): ForecastEntry[] {
  const timeseries = requireArray(requireRecord(value).properties)
    .map((item): ForecastEntry => {
      const record = requireRecord(item);
      const time = new Date(requireString(record.time, 'forecast time'));
      if (!Number.isFinite(time.getTime())) {
        throw new TypeError('invalid forecast time');
      }
      return { time, data: requireRecord(record.data) };
    })
    .sort((left, right) => left.time.getTime() - right.time.getTime());
  if (timeseries.length === 0) {
    throw new TypeError('weather forecast is empty');
  }

  const earliest = now.getTime() - 60 * 60 * 1000;
  const latest = now.getTime() + 4 * 60 * 60 * 1000;
  const relevant = timeseries.filter((entry) => {
    const time = entry.time.getTime();
    return time >= earliest && time <= latest;
  });
  return relevant.length === 0 ? [timeseries[0]] : relevant;
}

function readSymbolCode(entry: ForecastEntry): string | null {
  const period = readForecastPeriod(entry.data);
  if (period === null) {
    return null;
  }
  return requireOptionalString(requireRecord(period.summary).symbol_code)
    ?.toLowerCase() ?? null;
}

function readPrecipitationAmount(entry: ForecastEntry): number | null {
  const period = readForecastPeriod(entry.data);
  if (period === null) {
    return null;
  }
  return requireNullableNumber(
    requireRecord(period.details).precipitation_amount,
  );
}

function readForecastPeriod(
  data: Record<string, unknown>,
): Record<string, unknown> | null {
  const value = data.next_1_hours ?? data.next_6_hours;
  return value === null || value === undefined ? null : requireRecord(value);
}

function deriveCondition({
  symbols,
  cloudAreaFraction,
  apparentTemperature,
}: {
  symbols: string[];
  cloudAreaFraction: number | null;
  apparentTemperature: number | null;
}): ProactiveWeatherCondition {
  if (symbols.some(isSnowSymbol)) {
    return 'snow_possible';
  }
  if (symbols.some(isRainSymbol)) {
    return 'rain_possible';
  }
  if (apparentTemperature !== null && apparentTemperature >= 33) {
    return 'hot';
  }
  if (apparentTemperature !== null && apparentTemperature <= 3) {
    return 'cold';
  }

  const nearestSymbol = symbols[0] ?? null;
  if (
    nearestSymbol?.includes('clearsky') === true
    || (
      nearestSymbol === null
      && cloudAreaFraction !== null
      && cloudAreaFraction <= 20
    )
  ) {
    return 'clear';
  }
  if (
    nearestSymbol?.includes('fair') === true
    || nearestSymbol?.includes('partlycloudy') === true
    || (
      nearestSymbol === null
      && cloudAreaFraction !== null
      && cloudAreaFraction <= 70
    )
  ) {
    return 'partly_cloudy';
  }
  if (
    nearestSymbol?.includes('cloudy') === true
    || nearestSymbol?.includes('fog') === true
    || (nearestSymbol === null && cloudAreaFraction !== null)
  ) {
    return 'cloudy';
  }
  return 'unknown';
}

function isPrecipitationSymbol(value: string): boolean {
  return isRainSymbol(value) || isSnowSymbol(value);
}

function isRainSymbol(value: string): boolean {
  return value.includes('rain') || value.includes('thunder');
}

function isSnowSymbol(value: string): boolean {
  return value.includes('snow') || value.includes('sleet');
}

function estimateApparentTemperature(
  temperatureC: number | null,
  relativeHumidity: number | null,
  windSpeedMetersPerSecond: number | null,
): number | null {
  if (temperatureC === null) {
    return null;
  }

  const windSpeedKilometersPerHour = windSpeedMetersPerSecond === null
    ? null
    : windSpeedMetersPerSecond * 3.6;
  if (
    temperatureC <= 10
    && windSpeedKilometersPerHour !== null
    && windSpeedKilometersPerHour >= 4.8
  ) {
    const windFactor = Math.pow(windSpeedKilometersPerHour, 0.16);
    return roundTemperature(
      13.12
        + 0.6215 * temperatureC
        - 11.37 * windFactor
        + 0.3965 * temperatureC * windFactor,
    );
  }

  if (temperatureC >= 26.7 && relativeHumidity !== null) {
    const temperatureF = temperatureC * 9 / 5 + 32;
    const heatIndexF = -42.379
      + 2.04901523 * temperatureF
      + 10.14333127 * relativeHumidity
      - 0.22475541 * temperatureF * relativeHumidity
      - 0.00683783 * temperatureF * temperatureF
      - 0.05481717 * relativeHumidity * relativeHumidity
      + 0.00122874 * temperatureF * temperatureF * relativeHumidity
      + 0.00085282 * temperatureF * relativeHumidity * relativeHumidity
      - 0.00000199
        * temperatureF
        * temperatureF
        * relativeHumidity
        * relativeHumidity;
    return roundTemperature((heatIndexF - 32) * 5 / 9);
  }

  return temperatureC;
}

function parseSunset(value: unknown): Date | null {
  const sunset = requireRecord(value).properties;
  const properties = requireRecord(sunset);
  if (properties.sunset === null || properties.sunset === undefined) {
    return null;
  }
  const time = new Date(
    requireString(requireRecord(properties.sunset).time, 'sunset time'),
  );
  if (!Number.isFinite(time.getTime())) {
    throw new TypeError('invalid sunset time');
  }
  return time;
}

function createLocationUrl(
  endpoint: string,
  latitude: number,
  longitude: number,
): URL {
  const url = new URL(endpoint);
  url.searchParams.set('lat', latitude.toString());
  url.searchParams.set('lon', longitude.toString());
  return url;
}

function resolveExpiry(
  response: Response,
  now: Date,
  fallbackTtlMs: number,
): number {
  const expires = response.headers.get('expires');
  if (expires !== null) {
    const parsed = Date.parse(expires);
    if (Number.isFinite(parsed) && parsed > now.getTime()) {
      return parsed;
    }
  }
  return now.getTime() + fallbackTtlMs;
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

function validateRequest(request: ProactiveSuggestionWeatherRequest): void {
  validateCoordinate(request.latitude, -90, 90, 'latitude');
  validateCoordinate(request.longitude, -180, 180, 'longitude');
  if (!Number.isFinite(request.now.getTime())) {
    throw new RangeError('invalid weather current time');
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(request.localDate)) {
    throw new RangeError('invalid weather local date');
  }
  requireNonBlank(request.timezone, 'weather timezone');
}

function normalizeEndpoint(value: string): string {
  const url = new URL(value.trim());
  if (url.protocol !== 'https:') {
    throw new TypeError('weather endpoint must use HTTPS');
  }
  return url.toString();
}

function roundCoordinate(value: number): number {
  return Math.round(value * 100) / 100;
}

function roundTemperature(value: number): number {
  return Math.round(value * 10) / 10;
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

function requireArray(value: unknown): unknown[] {
  const timeseries = requireRecord(value).timeseries;
  if (!Array.isArray(timeseries)) {
    throw new TypeError('invalid weather timeseries');
  }
  return timeseries;
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

function requireString(value: unknown, label: string): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new TypeError(`invalid ${label}`);
  }
  return value.trim();
}

function requireOptionalString(value: unknown): string | null {
  if (value === null || value === undefined) {
    return null;
  }
  return requireString(value, 'weather string');
}

function requireNonBlank(value: string, label: string): string {
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > 256) {
    throw new RangeError(`${label} must contain 1 to 256 characters`);
  }
  return normalized;
}

function normalizeHeader(value: string | null): string | null {
  const normalized = value?.trim();
  return normalized ? normalized : null;
}
