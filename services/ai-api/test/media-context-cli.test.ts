import assert from 'node:assert/strict';
import test from 'node:test';
import { spawnSync } from 'node:child_process';
const run = (...args: string[]) => {
  const env = { ...process.env }; for (const k of Object.keys(env)) if (k.startsWith('CONTENT_SAFETY_')) delete env[k];
  return spawnSync(process.execPath, ['--experimental-strip-types', 'eval/run-media-context.ts', ...args], { env, encoding: 'utf8' });
};
test('media-context CLI defaults to a keyless plan; stale approval precedes runtime/key access', () => {
  const r = run(); assert.equal(r.status, 0); const p = JSON.parse(r.stdout);
  assert.equal(p.networkRequests, 0); assert.equal(p.limits.maximumRequests, 54);
  for (const args of [['--live'], ['--live', '--approved-plan=63c0dce29e634c7b269328d64579133246b06c18f88175a6d438a2027874847d']])
    assert.equal(JSON.parse(run(...args).stderr).error, 'media_context_approval_required');
  for (const args of [['--unknown'], ['--live', '--verify-local'], ['--candidate=luna', '--candidate=terra']])
    assert.equal(JSON.parse(run(...args).stderr).error, 'invalid_media_context_arguments');
});
