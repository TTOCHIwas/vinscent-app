import assert from 'node:assert/strict';
import test from 'node:test';

import {
  CuratedProactiveSuggestionSelector,
  curatedProactiveSuggestionCatalog,
  isCuratedProactiveSuggestionEligible,
  type CuratedProactiveSuggestionSelectionContext,
} from '../src/application/curated-proactive-suggestion-selector.ts';

const selector = new CuratedProactiveSuggestionSelector();

test('curated proactive catalog keeps reviewed copy and metadata valid', () => {
  assert.equal(curatedProactiveSuggestionCatalog.length, 64);
  assert.equal(
    new Set(curatedProactiveSuggestionCatalog.map((entry) => entry.id)).size,
    curatedProactiveSuggestionCatalog.length,
  );

  for (const entry of curatedProactiveSuggestionCatalog) {
    assert.match(entry.id, /^(?:together|card|recording|weather)_\d{2}$/);
    assert.ok(entry.text.trim().length > 0);
    assert.ok(entry.text.length <= 100);
    assert.equal(entry.text.includes('\ubbf8\uc158'), false);
    assert.equal(entry.text.includes('X'), false);
  }
});

test('curated proactive selection is stable for the same user and context', () => {
  const context = selectionContext();

  assert.deepEqual(selector.select(context), selector.select(context));
});

test('curated proactive selection rotates together, card, and recording targets', () => {
  const targets = new Set(
    Array.from({ length: 3 }, (_, dayOffset) =>
      selector.select(selectionContext({
        localDate: isoDateAt(dayOffset),
      })).target
    ),
  );

  assert.deepEqual(
    [...targets].sort(),
    ['card', 'recording', 'together'],
  );
});

test('curated proactive selection excludes card copy after today card upload', () => {
  for (let dayOffset = 0; dayOffset < 60; dayOffset += 1) {
    const selected = selector.select(selectionContext({
      localDate: isoDateAt(dayOffset),
      hasCardToday: true,
    }));

    assert.notEqual(selected.target, 'card');
    assert.equal(selected.kind, 'date_idea');
    assert.equal(selected.conditions.includes('card_missing'), false);
  }
});

test('curated proactive selection excludes recording copy when recording is unavailable', () => {
  for (let dayOffset = 0; dayOffset < 60; dayOffset += 1) {
    const selected = selector.select(selectionContext({
      localDate: isoDateAt(dayOffset),
      recordingAvailable: false,
    }));

    assert.notEqual(selected.target, 'recording');
    assert.equal(
      selected.conditions.includes('recording_available'),
      false,
    );
  }
});

test('curated proactive selection never uses weather copy without weather context', () => {
  const weatherConditions = new Set([
    'outdoor_ok',
    'near_sunset',
    'cloudy',
    'rain_possible',
    'snow_possible',
    'hot',
    'cold',
  ]);

  for (let dayOffset = 0; dayOffset < 180; dayOffset += 1) {
    const selected = selector.select(selectionContext({
      localDate: isoDateAt(dayOffset),
      weather: null,
    }));

    assert.equal(
      selected.conditions.some((condition) => weatherConditions.has(condition)),
      false,
    );
  }
});

test('curated proactive condition matcher respects time and weather boundaries', () => {
  const morningRecording = catalogEntry('recording_13');
  const nightRecording = catalogEntry('recording_14');
  const rainCard = catalogEntry('weather_06');
  const outdoorCard = catalogEntry('weather_01');

  assert.equal(
    isCuratedProactiveSuggestionEligible(
      morningRecording,
      selectionContext({ localHour: 8 }),
    ),
    true,
  );
  assert.equal(
    isCuratedProactiveSuggestionEligible(
      morningRecording,
      selectionContext({ localHour: 13 }),
    ),
    false,
  );
  assert.equal(
    isCuratedProactiveSuggestionEligible(
      nightRecording,
      selectionContext({ localHour: 22 }),
    ),
    true,
  );
  assert.equal(
    isCuratedProactiveSuggestionEligible(
      nightRecording,
      selectionContext({ localHour: 18 }),
    ),
    false,
  );
  assert.equal(
    isCuratedProactiveSuggestionEligible(
      rainCard,
      selectionContext({ weather: rainWeather() }),
    ),
    true,
  );
  assert.equal(
    isCuratedProactiveSuggestionEligible(
      rainCard,
      selectionContext({ weather: clearWeather() }),
    ),
    false,
  );
  assert.equal(
    isCuratedProactiveSuggestionEligible(
      outdoorCard,
      selectionContext({ weather: clearWeather() }),
    ),
    true,
  );
  assert.equal(
    isCuratedProactiveSuggestionEligible(
      outdoorCard,
      selectionContext({ weather: rainWeather() }),
    ),
    false,
  );
});

test('curated proactive selection keeps active suggestions at one quarter', () => {
  const selections = Array.from({ length: 120 }, (_, dayOffset) =>
    selector.select(selectionContext({ localDate: isoDateAt(dayOffset) }))
  );
  const activeCount = selections.filter(
    (selection) => selection.style === 'active',
  ).length;

  assert.equal(activeCount, 30);
});

function selectionContext(
  overrides: Partial<CuratedProactiveSuggestionSelectionContext> = {},
): CuratedProactiveSuggestionSelectionContext {
  return {
    userId: 'user-1',
    localDate: '2026-09-01',
    localHour: 14,
    hasCardToday: false,
    recordingAvailable: true,
    weather: null,
    ...overrides,
  };
}

function catalogEntry(id: string) {
  const entry = curatedProactiveSuggestionCatalog.find(
    (candidate) => candidate.id === id,
  );
  assert.ok(entry);
  return entry;
}

function isoDateAt(dayOffset: number): string {
  const date = new Date(Date.UTC(2026, 8, 1 + dayOffset));
  return date.toISOString().slice(0, 10);
}

function clearWeather() {
  return {
    condition: 'clear' as const,
    apparentTemperatureC: 24,
    precipitationPossible: false,
    nearSunset: false,
    sunsetLocalTime: '18:40',
  };
}

function rainWeather() {
  return {
    condition: 'rain_possible' as const,
    apparentTemperatureC: 20,
    precipitationPossible: true,
    nearSunset: false,
    sunsetLocalTime: '18:40',
  };
}
