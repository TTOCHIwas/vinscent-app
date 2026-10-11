import assert from 'node:assert/strict';
import { readdir } from 'node:fs/promises';
import { test } from 'node:test';

test('Supabase DB test discovery only includes pgTAP test files', async () => {
  const entries = await readdir(new URL('../../supabase/tests/', import.meta.url), {
    recursive: true,
  });
  const fixtures = entries.filter((entry) => entry.endsWith('.sql') && !entry.endsWith('.test.sql'));
  assert.deepEqual(fixtures, [], 'SQL fixtures must live outside supabase/tests');
});
