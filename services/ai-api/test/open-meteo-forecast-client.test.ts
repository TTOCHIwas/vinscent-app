import assert from 'node:assert/strict';
import test from 'node:test';

import {
  OpenMeteoForecastClient,
} from '../src/infrastructure/open-meteo-forecast-client.ts';

test('weather client rounds coordinates and detects a sunset opportunity', async () => {
  let requestedUrl: URL | null = null;
  const now = new Date('2026-07-24T10:00:00.000Z');
  const sunset = Math.floor(
    new Date('2026-07-24T10:30:00.000Z').getTime() / 1000,
  );
  const client = new OpenMeteoForecastClient({
    fetchImpl: async (input) => {
      requestedUrl = new URL(input.toString());
      return new Response(JSON.stringify({
        timezone: 'Asia/Seoul',
        current: {
          apparent_temperature: 27,
          weather_code: 1,
          cloud_cover: 24,
          precipitation: 0,
        },
        hourly: {
          precipitation_probability: [10, 15, 20, 10],
        },
        daily: {
          sunrise: [],
          sunset: [sunset],
          apparent_temperature_max: [29],
          apparent_temperature_min: [22],
        },
      }), { status: 200 });
    },
  });

  const context = await client.fetchContext(
    37.56653,
    126.97796,
    now,
  );

  assert.equal(requestedUrl?.searchParams.get('latitude'), '37.57');
  assert.equal(requestedUrl?.searchParams.get('longitude'), '126.98');
  assert.equal(requestedUrl?.searchParams.get('forecast_hours'), '4');
  assert.equal(context.condition, 'partly_cloudy');
  assert.equal(context.precipitationPossible, false);
  assert.equal(context.nearSunset, true);
  assert.equal(context.sunsetLocalTime, '19:30');
});

test('weather client treats forecast precipitation as uncertain context', async () => {
  const client = new OpenMeteoForecastClient({
    fetchImpl: async () => new Response(JSON.stringify({
      timezone: 'Asia/Seoul',
      current: {
        apparent_temperature: 31,
        weather_code: 2,
        cloud_cover: 55,
        precipitation: 0,
      },
      hourly: {
        precipitation_probability: [20, 60, 30],
      },
      daily: {
        sunrise: [],
        sunset: [],
        apparent_temperature_max: [34],
        apparent_temperature_min: [25],
      },
    }), { status: 200 }),
  });

  const context = await client.fetchContext(37.5, 127);

  assert.equal(context.precipitationPossible, true);
  assert.equal(context.condition, 'partly_cloudy');
  assert.equal(context.nearSunset, false);
});
