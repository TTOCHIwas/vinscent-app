import assert from 'node:assert/strict';
import test from 'node:test';

import {
  compareMigrationInventory,
  parseLocalMigrationVersions,
  parseRemoteMigrationVersions,
} from '../../scripts/lib/supabase-migration-inventory.mjs';

test('parses and sorts local migration file versions', () => {
  assert.deepEqual(
    parseLocalMigrationVersions([
      '20260729001000_second.sql',
      '20260729000000_first.sql',
    ]),
    ['20260729000000', '20260729001000'],
  );
});

test('rejects malformed and duplicate local migration versions', () => {
  assert.throws(
    () => parseLocalMigrationVersions(['invalid.sql']),
    /invalid local migration filename: invalid\.sql/,
  );
  assert.throws(
    () =>
      parseLocalMigrationVersions([
        '20260729000000_first.sql',
        '20260729000000_duplicate.sql',
      ]),
    /duplicate local migration version: 20260729000000/,
  );
});

test('parses Supabase migration list JSON without trusting local columns', () => {
  assert.deepEqual(
    parseRemoteMigrationVersions(
      `\uFEFF${JSON.stringify({
        migrations: [
          {
            local: '20260729001000',
            remote: '',
            time: '2026-07-29 00:10:00',
          },
          {
            local: '20260729000000',
            remote: '20260729000000',
            time: '2026-07-29 00:00:00',
          },
          {
            local: '',
            remote: '20260728000000',
            time: '2026-07-28 00:00:00',
          },
        ],
      })}`,
    ),
    ['20260728000000', '20260729000000'],
  );
});

test('rejects malformed and duplicate remote migration versions', () => {
  assert.throws(
    () => parseRemoteMigrationVersions('{"unexpected":[]}'),
    /must contain a migrations array/,
  );
  assert.throws(
    () =>
      parseRemoteMigrationVersions(
        JSON.stringify({
          migrations: [{ local: '', remote: 'invalid' }],
        }),
      ),
    /entry 0 has an invalid remote version/,
  );
  assert.throws(
    () =>
      parseRemoteMigrationVersions(
        JSON.stringify({
          migrations: [
            { local: '20260729000000', remote: '20260729000000' },
            { local: '', remote: '20260729000000' },
          ],
        }),
      ),
    /duplicate remote migration version: 20260729000000/,
  );
});

test('requires exact local and remote migration inventories', () => {
  assert.deepEqual(
    compareMigrationInventory({
      localVersions: ['20260728000000', '20260729000000'],
      remoteVersions: ['20260727000000', '20260728000000'],
    }),
    [
      'remote-only migrations: 20260727000000',
      'unapplied migrations: 20260729000000',
    ],
  );
  assert.deepEqual(
    compareMigrationInventory({
      localVersions: ['20260728000000', '20260729000000'],
      remoteVersions: ['20260728000000', '20260729000000'],
    }),
    [],
  );
});

test('allows unapplied local migrations while still rejecting remote-only history', () => {
  assert.deepEqual(
    compareMigrationInventory({
      allowUnapplied: true,
      localVersions: ['20260728000000', '20260729000000'],
      remoteVersions: ['20260727000000', '20260728000000'],
    }),
    ['remote-only migrations: 20260727000000'],
  );
  assert.deepEqual(
    compareMigrationInventory({
      allowUnapplied: true,
      localVersions: ['20260728000000', '20260729000000'],
      remoteVersions: ['20260728000000'],
    }),
    [],
  );
});
