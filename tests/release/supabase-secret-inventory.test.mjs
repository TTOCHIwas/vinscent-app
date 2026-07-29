import assert from 'node:assert/strict';
import test from 'node:test';

import {
  parseRemoteSecretNames,
  validateRemoteSecretInventory,
} from '../../scripts/lib/supabase-secret-inventory.mjs';

const manifest = {
  schemaVersion: 1,
  entries: [
    {
      name: 'DIRECT_SECRET',
      availability: 'required',
      provisioning: 'supabase_secret',
    },
    {
      name: 'FALLBACK_SECRET',
      availability: 'fallback',
      fallbackTo: 'DIRECT_SECRET',
      provisioning: 'supabase_secret',
    },
    {
      name: 'OPTIONAL_SECRET',
      availability: 'optional',
      provisioning: 'supabase_secret',
    },
    {
      name: 'SUPABASE_URL',
      availability: 'required',
      provisioning: 'supabase_platform',
    },
  ],
};

test('parses and sorts Supabase secret list JSON without using values', () => {
  const names = parseRemoteSecretNames(JSON.stringify([
    { name: 'SECOND_SECRET', value: 'do-not-log-this' },
    { name: 'FIRST_SECRET', value: 'another-sensitive-digest' },
    { name: 'SECOND_SECRET', value: 'duplicate' },
  ]));

  assert.deepEqual(names, ['FIRST_SECRET', 'SECOND_SECRET']);
});

test('accepts required secrets and documented fallbacks', () => {
  assert.deepEqual(
    validateRemoteSecretInventory(manifest, ['DIRECT_SECRET']),
    [],
  );
});

test('accepts a dedicated fallback secret when its fallback is configured', () => {
  assert.deepEqual(
    validateRemoteSecretInventory(manifest, [
      'DIRECT_SECRET',
      'FALLBACK_SECRET',
    ]),
    [],
  );
});

test('rejects missing required and fallback secret contracts', () => {
  assert.deepEqual(validateRemoteSecretInventory(manifest, []), [
    'missing required Edge secret: DIRECT_SECRET',
    'missing Edge secret fallback: FALLBACK_SECRET or DIRECT_SECRET',
  ]);
});

test('ignores optional and platform-provisioned runtime values', () => {
  const optionalOnlyManifest = {
    schemaVersion: 1,
    entries: manifest.entries.slice(2),
  };

  assert.deepEqual(validateRemoteSecretInventory(optionalOnlyManifest, []), []);
});

test('rejects malformed remote inventories without exposing values', () => {
  assert.throws(
    () => parseRemoteSecretNames('{"secrets":[{"value":"hidden"}]}'),
    /entry 0 has no name/,
  );
});
