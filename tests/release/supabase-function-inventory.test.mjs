import assert from 'node:assert/strict';
import test from 'node:test';

import {
  compareFunctionInventory,
  parseRemoteFunctionNames,
} from '../../scripts/lib/supabase-function-inventory.mjs';

test('parses and sorts Supabase function list JSON', () => {
  assert.deepEqual(
    parseRemoteFunctionNames(
      JSON.stringify([
        { name: 'send-beta', slug: 'send-beta' },
        { name: 'send-alpha', slug: 'send-alpha' },
      ]),
    ),
    ['send-alpha', 'send-beta'],
  );
  assert.deepEqual(
    parseRemoteFunctionNames(
      JSON.stringify({ functions: [{ name: 'send-alpha' }] }),
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
