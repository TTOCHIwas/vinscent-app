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
  '20260730000000_enforce_profile_minimum_age.sql',
);

test('profiles enforce the minimum service age at the database write boundary', () => {
  assert.equal(
    existsSync(migrationPath),
    true,
    'the profile minimum-age migration must exist',
  );

  const sql = readFileSync(migrationPath, 'utf8');

  assert.match(
    sql,
    /create\s+or\s+replace\s+function\s+private\.enforce_profile_minimum_age\(\)/i,
  );
  assert.match(sql, /security\s+definer/i);
  assert.match(sql, /private\.current_app_date\(\)/i);
  assert.match(sql, /interval\s+'14 years'/i);
  assert.match(
    sql,
    /private\.raise_app_error\('minimum_age_required'\)/i,
  );
  assert.match(
    sql,
    /create\s+trigger\s+profiles_enforce_minimum_age\s+before\s+insert\s+or\s+update\s+of\s+birth_date\s+on\s+public\.profiles/i,
  );
  assert.match(
    sql,
    /revoke\s+all\s+on\s+function\s+private\.enforce_profile_minimum_age\(\)\s+from\s+public,\s*anon,\s*authenticated/i,
  );
});
