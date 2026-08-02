import assert from 'node:assert/strict';
import test from 'node:test';

import {
  MetNorwayForecastClient,
} from '../src/infrastructure/met-norway-forecast-client.ts';

const request = {
  latitude: 37.56653,
  longitude: 126.97796,
  now: new Date('2026-07-24T10:00:00.000Z'),
  localDate: '2026-07-24',
  timezone: 'Asia/Seoul',
};

test('MET Norway client identifies the app and builds a rounded global forecast request', async () => {
  const requestedUrls: URL[] = [];
  const requestedUserAgents: Array<string | null> = [];
  const client = new MetNorwayForecastClient({
    userAgent: 'Danjjan/1.0 vinscent0929@gmail.com',
    fetchImpl: async (input, init) => {
      const url = new URL(input.toString());
      requestedUrls.push(url);
      requestedUserAgents.push(new Headers(init?.headers).get('user-agent'));
      return jsonResponse(
        url.pathname.includes('/sunrise/')
          ? sunrisePayload('2026-07-24T10:30:00Z')
          : forecastPayload({
            airTemperature: 29,
            cloudAreaFraction: 28,
            relativeHumidity: 60,
            windSpeed: 2,
            symbolCode: 'partlycloudy_day',
            precipitationAmount: 0,
          }),
      );
    },
  });

  const context = await client.fetchContext(request);

  assert.equal(requestedUrls.length, 2);
  for (const url of requestedUrls) {
    assert.equal(url.searchParams.get('lat'), '37.57');
    assert.equal(url.searchParams.get('lon'), '126.98');
  }
  assert.equal(
    requestedUrls.find((url) => url.pathname.includes('/sunrise/'))
      ?.searchParams.get('date'),
    '2026-07-24',
  );
  assert.deepEqual(requestedUserAgents, [
    'Danjjan/1.0 vinscent0929@gmail.com',
    'Danjjan/1.0 vinscent0929@gmail.com',
  ]);
  assert.equal(context.condition, 'partly_cloudy');
  assert.equal(context.precipitationPossible, false);
  assert.equal(context.nearSunset, true);
  assert.equal(context.sunsetLocalTime, '19:30');
});

test('MET Norway client derives uncertain precipitation from global amount and symbol data', async () => {
  const client = new MetNorwayForecastClient({
    userAgent: 'Danjjan/1.0 vinscent0929@gmail.com',
    fetchImpl: async (input) => {
      const url = new URL(input.toString());
      return jsonResponse(
        url.pathname.includes('/sunrise/')
          ? sunrisePayload(null)
          : forecastPayload({
            airTemperature: 7,
            cloudAreaFraction: 95,
            relativeHumidity: 82,
            windSpeed: 4,
            symbolCode: 'lightrain',
            precipitationAmount: 0.4,
          }),
      );
    },
  });

  const context = await client.fetchContext(request);

  assert.equal(context.condition, 'rain_possible');
  assert.equal(context.precipitationPossible, true);
  assert.equal(context.nearSunset, false);
  assert.equal(context.sunsetLocalTime, null);
});

test('MET Norway client caches provider payloads and conditionally revalidates expired entries', async () => {
  let callCount = 0;
  const conditionalHeaders: Array<string | null> = [];
  const client = new MetNorwayForecastClient({
    userAgent: 'Danjjan/1.0 vinscent0929@gmail.com',
    fetchImpl: async (input, init) => {
      callCount += 1;
      const url = new URL(input.toString());
      const ifModifiedSince = new Headers(init?.headers).get(
        'if-modified-since',
      );
      conditionalHeaders.push(ifModifiedSince);
      if (ifModifiedSince !== null) {
        return new Response(null, {
          status: 304,
          headers: { expires: 'Fri, 24 Jul 2026 11:00:00 GMT' },
        });
      }
      return jsonResponse(
        url.pathname.includes('/sunrise/')
          ? sunrisePayload('2026-07-24T10:30:00Z')
          : forecastPayload({
            airTemperature: 24,
            cloudAreaFraction: 10,
            relativeHumidity: 50,
            windSpeed: 1,
            symbolCode: 'clearsky_day',
            precipitationAmount: 0,
          }),
        {
          expires: 'Fri, 24 Jul 2026 10:01:00 GMT',
          'last-modified': 'Fri, 24 Jul 2026 09:50:00 GMT',
        },
      );
    },
  });

  await client.fetchContext(request);
  await client.fetchContext({
    ...request,
    now: new Date('2026-07-24T10:00:30.000Z'),
  });
  await client.fetchContext({
    ...request,
    now: new Date('2026-07-24T10:02:00.000Z'),
  });

  assert.equal(callCount, 4);
  assert.deepEqual(conditionalHeaders, [
    null,
    null,
    'Fri, 24 Jul 2026 09:50:00 GMT',
    'Fri, 24 Jul 2026 09:50:00 GMT',
  ]);
});

test('MET Norway client rejects an unidentified caller', () => {
  assert.throws(
    () => new MetNorwayForecastClient({ userAgent: '  ' }),
    /user agent/i,
  );
});

function forecastPayload({
  airTemperature,
  cloudAreaFraction,
  relativeHumidity,
  windSpeed,
  symbolCode,
  precipitationAmount,
}: {
  airTemperature: number;
  cloudAreaFraction: number;
  relativeHumidity: number;
  windSpeed: number;
  symbolCode: string;
  precipitationAmount: number;
}) {
  return {
    properties: {
      timeseries: [
        {
          time: '2026-07-24T10:00:00Z',
          data: {
            instant: {
              details: {
                air_temperature: airTemperature,
                cloud_area_fraction: cloudAreaFraction,
                relative_humidity: relativeHumidity,
                wind_speed: windSpeed,
              },
            },
            next_1_hours: {
              summary: { symbol_code: symbolCode },
              details: { precipitation_amount: precipitationAmount },
            },
          },
        },
      ],
    },
  };
}

function sunrisePayload(sunset: string | null) {
  return {
    properties: {
      sunset: sunset === null ? null : { time: sunset },
    },
  };
}

function jsonResponse(
  body: unknown,
  headers: Record<string, string> = {},
) {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: {
      'content-type': 'application/json',
      expires: 'Fri, 24 Jul 2026 10:30:00 GMT',
      ...headers,
    },
  });
}
