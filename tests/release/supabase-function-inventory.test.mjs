import assert from 'node:assert/strict';
import test from 'node:test';

import {
  compareFunctionAuthorizationModes,
  compareFunctionInventory,
  parseLocalFunctionAuthorizationModes,
  parseRemoteFunctionAuthorizationModes,
  parseRemoteFunctionNames,
} from '../../scripts/lib/supabase-function-inventory.mjs';

test('parses and sorts Supabase function list JSON', () => {
  assert.deepEqual(
    parseRemoteFunctionNames(
      JSON.stringify([
        { name: 'send-beta', slug: 'send-beta', verify_jwt: false },
        { name: 'send-alpha', slug: 'send-alpha', verify_jwt: true },
      ]),
    ),
    ['send-alpha', 'send-beta'],
  );
  assert.deepEqual(
    parseRemoteFunctionNames(
      JSON.stringify({
        functions: [{ name: 'send-alpha', verify_jwt: true }],
      }),
    ),
    ['send-alpha'],
  );
});

test('rejects malformed remote function inventory', () => {
  assert.throws(
    () => parseRemoteFunctionNames('{"unexpected":[]}'),
    /must be a JSON array/,
  );
  assert.throws(
    () => parseRemoteFunctionNames('[{"id":"missing-name"}]'),
    /entry 0 has no name/,
  );
});

test('parses local and remote Edge Function JWT modes', () => {
  const localModes = parseLocalFunctionAuthorizationModes(
    [
      '[functions.custom-webhook]',
      'verify_jwt = false',
      '',
      '[functions.explicit-client]',
      'verify_jwt = true',
      '',
      '[functions.final-webhook]',
      'verify_jwt = false # custom authorization',
    ].join('\n'),
    [
      'custom-webhook',
      'default-client',
      'explicit-client',
      'final-webhook',
    ],
  );
  const remoteModes = parseRemoteFunctionAuthorizationModes(
    JSON.stringify([
      { name: 'custom-webhook', verify_jwt: false },
      { name: 'default-client', verify_jwt: true },
      { name: 'explicit-client', verify_jwt: true },
      { name: 'final-webhook', verify_jwt: false },
    ]),
  );

  assert.deepEqual(
    Object.fromEntries(localModes),
    {
      'custom-webhook': false,
      'default-client': true,
      'explicit-client': true,
      'final-webhook': false,
    },
  );
  assert.deepEqual(Object.fromEntries(remoteModes), {
    'custom-webhook': false,
    'default-client': true,
    'explicit-client': true,
    'final-webhook': false,
  });
});

test('detects remote-only functions without pruning them', () => {
  assert.deepEqual(
    compareFunctionInventory({
      localNames: ['send-current'],
      remoteNames: ['send-current', 'send-retired'],
      allowMissing: true,
    }),
    ['remote-only Edge Functions: send-retired'],
  );
});

test('requires exact JWT modes only after all functions are deployed', () => {
  const localModes = new Map([
    ['client-function', true],
    ['custom-webhook', false],
  ]);
  const remoteModes = new Map([
    ['client-function', false],
    ['custom-webhook', false],
  ]);

  assert.deepEqual(
    compareFunctionAuthorizationModes({
      localModes,
      remoteModes,
      allowMissing: true,
    }),
    [],
  );
  assert.deepEqual(
    compareFunctionAuthorizationModes({
      localModes,
      remoteModes,
      allowMissing: false,
    }),
    [
      'Edge Function JWT mode mismatch: client-function expected true, remote false',
    ],
  );
});

test('rejects remote inventories without explicit JWT modes', () => {
  assert.throws(
    () => parseRemoteFunctionAuthorizationModes('[{"name":"send-alpha"}]'),
    /entry 0 has no verify_jwt mode/,
  );
});

test('allows missing functions before deploy and requires them afterward', () => {
  assert.deepEqual(
    compareFunctionInventory({
      localNames: ['send-alpha', 'send-beta'],
      remoteNames: ['send-alpha'],
      allowMissing: true,
    }),
    [],
  );
  assert.deepEqual(
    compareFunctionInventory({
      localNames: ['send-alpha', 'send-beta'],
      remoteNames: ['send-alpha'],
      allowMissing: false,
    }),
    ['undeployed Edge Functions: send-beta'],
  );
});
