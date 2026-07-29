import assert from 'node:assert/strict';
import test from 'node:test';

import {
  optionalEnv,
  optionalPositiveIntegerEnv,
  requiredEnv,
} from '../../functions/_shared/environment.ts';

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

test('normalizes optional environment values', () => {
  assert.equal(
    optionalEnv('MODEL', () => '  gemini-test  '),
    'gemini-test',
  );
  assert.equal(optionalEnv('EMPTY', () => '   '), undefined);
  assert.equal(optionalEnv('MISSING', () => undefined), undefined);
});

test('parses optional positive integer environment values', () => {
  assert.equal(
    optionalPositiveIntegerEnv('BATCH_SIZE', () => '3'),
    3,
  );
  assert.equal(
    optionalPositiveIntegerEnv('MISSING', () => undefined),
    undefined,
  );
  assert.throws(
    () => optionalPositiveIntegerEnv('ZERO', () => '0'),
    /ZERO must be a positive integer/,
  );
  assert.throws(
    () => optionalPositiveIntegerEnv('DECIMAL', () => '1.5'),
    /DECIMAL must be a positive integer/,
  );
});
