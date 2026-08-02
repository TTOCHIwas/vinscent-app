import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const supabaseRoot = new URL('../../', import.meta.url);

test('proactive suggestion composes the MET Norway weather adapter', async () => {
  const source = await readFile(
    new URL(
      'functions/generate-ai-proactive-suggestion/index.ts',
      supabaseRoot,
    ),
    'utf8',
  );

  assert.match(source, /MetNorwayForecastClient/);
  assert.match(source, /requiredEnv\('MET_NORWAY_USER_AGENT'\)/);
  assert.match(source, /optionalEnv\('MET_NORWAY_FORECAST_ENDPOINT'\)/);
  assert.match(source, /optionalEnv\('MET_NORWAY_SUNRISE_ENDPOINT'\)/);
  assert.doesNotMatch(source, /OpenMeteo|OPEN_METEO/);
});

test('runtime manifest declares only the active weather provider configuration', async () => {
  const manifest = JSON.parse(
    await readFile(
      new URL('runtime-environment.manifest.json', supabaseRoot),
      'utf8',
    ),
  ) as {
    entries: Array<{
      name: string;
      availability: string;
      sensitivity: string;
      functions: string[];
    }>;
  };
  const weatherEntries = manifest.entries.filter((entry) =>
    entry.name.startsWith('MET_NORWAY_')
  );

  assert.deepEqual(
    weatherEntries.map((entry) => ({
      name: entry.name,
      availability: entry.availability,
      sensitivity: entry.sensitivity,
      functions: entry.functions,
    })),
    [
      {
        name: 'MET_NORWAY_FORECAST_ENDPOINT',
        availability: 'optional',
        sensitivity: 'configuration',
        functions: ['generate-ai-proactive-suggestion'],
      },
      {
        name: 'MET_NORWAY_SUNRISE_ENDPOINT',
        availability: 'optional',
        sensitivity: 'configuration',
        functions: ['generate-ai-proactive-suggestion'],
      },
      {
        name: 'MET_NORWAY_USER_AGENT',
        availability: 'required',
        sensitivity: 'configuration',
        functions: ['generate-ai-proactive-suggestion'],
      },
    ],
  );
  assert.equal(
    manifest.entries.some((entry) =>
      entry.name === 'OPEN_METEO_API_KEY'
      || entry.name === 'WEATHER_FORECAST_ENDPOINT'
    ),
    false,
  );
});
