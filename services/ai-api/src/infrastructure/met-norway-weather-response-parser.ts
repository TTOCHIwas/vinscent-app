import type {
  ProactiveWeatherCondition,
  ProactiveWeatherContext,
} from '../domain/learning-contract.ts';

interface ForecastEntry {
  time: Date;
  data: Record<string, unknown>;
}

export function parseMetNorwayWeatherContext(
  forecastValue: unknown,
  sunriseValue: unknown,
  context: { now: Date; timezone: string },
): ProactiveWeatherContext {
  const entries = selectForecastEntries(forecastValue, context.now);
  const nearest = entries.reduce((current, candidate) =>
    Math.abs(candidate.time.getTime() - context.now.getTime())
        < Math.abs(current.time.getTime() - context.now.getTime())
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
    && context.now.getTime() >= sunset.getTime() - 90 * 60 * 1000
    && context.now.getTime() <= sunset.getTime() + 15 * 60 * 1000;

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
      : formatLocalTime(sunset, context.timezone),
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

  if (
    temperatureC >= 26.7
    && relativeHumidity !== null
    && relativeHumidity >= 40
  ) {
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
  if (value === null) {
    return null;
  }
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

function roundTemperature(value: number): number {
  return Math.round(value * 10) / 10;
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
