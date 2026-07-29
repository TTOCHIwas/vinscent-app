import { spawnSync } from 'node:child_process';
import { readdir } from 'node:fs/promises';
import path from 'node:path';

const testRoots = [
  'supabase/tests/functions',
  'supabase/functions',
];

const testFiles = (
  await Promise.all(testRoots.map((root) => findTests(root)))
).flat().sort();

if (testFiles.length === 0) {
  throw new Error('No Supabase function tests were found');
}

const result = spawnSync(
  process.execPath,
  ['--experimental-strip-types', '--test', ...testFiles],
  { stdio: 'inherit' },
);

if (result.error) {
  throw result.error;
}
process.exitCode = result.status ?? 1;

async function findTests(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const tests = [];

  for (const entry of entries) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      tests.push(...await findTests(entryPath));
    } else if (entry.isFile() && entry.name.endsWith('.test.ts')) {
      tests.push(entryPath);
    }
  }

  return tests;
}
