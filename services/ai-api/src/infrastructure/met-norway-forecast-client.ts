import type {
  ProactiveSuggestionWeatherClient,
  ProactiveSuggestionWeatherRequest,
} from '../application/generate-proactive-suggestion.ts';
import type { ProactiveWeatherContext } from '../domain/learning-contract.ts';
import {
  parseMetNorwayWeatherContext,
} from './met-norway-weather-response-parser.ts';

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
      ).catch(() => null),
    ]);

    return parseMetNorwayWeatherContext(forecast, sunrise, {
      now: request.now,
      timezone: request.timezone,
    });
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
