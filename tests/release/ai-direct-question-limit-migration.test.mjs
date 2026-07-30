import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const migrationPath = resolve(
  repositoryRoot,
  'supabase',
  'migrations',
  '20260730001000_set_ai_direct_question_release_limit.sql',
);

test('direct AI questions restore the release limit at the database boundary', () => {
  assert.equal(
    existsSync(migrationPath),
    true,
    'the direct-question release-limit migration must exist',
  );

  const sql = readFileSync(migrationPath, 'utf8');

  assert.match(
    sql,
    /create\s+or\s+replace\s+function\s+private\.ai_direct_question_daily_limit\(\)/i,
  );
  assert.match(sql, /select\s+3::smallint/i);
  assert.match(
    sql,
    /set\s+submission_count\s*=\s*least\(submission_count,\s*3\)/i,
  );
  assert.match(
    sql,
    /check\s*\(\s*submission_count\s+between\s+0\s+and\s+3\s*\)/i,
  );
  assert.match(
    sql,
    /revoke\s+execute\s+on\s+function\s+private\.ai_direct_question_daily_limit\(\)\s+from\s+public,\s*anon,\s*authenticated/i,
  );
});
