import assert from 'node:assert/strict';
import test from 'node:test';

import { requiredEnv } from '../../functions/_shared/environment.ts';

test('returns a configured required environment value', () => {
  const value = requiredEnv('API_KEY', (name) =>
    name === 'API_KEY' ? 'configured' : undefined
  );

  assert.equal(value, 'configured');
});

test('rejects missing and empty required environment values', () => {
  assert.throws(
    () => requiredEnv('MISSING', () => undefined),
    /missing_env:MISSING/,
  );
  assert.throws(
    () => requiredEnv('EMPTY', () => ''),
    /missing_env:EMPTY/,
  );
});
