import assert from 'node:assert/strict';
import test from 'node:test';
import { spawnSync } from 'node:child_process';

const run = (...args: string[]) => {
  const env = { ...process.env }; delete env.CONTENT_SAFETY_OPENAI_API_KEY;
  return spawnSync(process.execPath, ['--experimental-strip-types', 'eval/run-context-expansion.ts', ...args], { encoding: 'utf8', env });
};
test('v2 CLI defaults to an offline plan; each model has 28 cases and keys are not required', () => {
  for (const selection of ['both', 'luna', 'terra']) {
    const r = run(`--candidate=${selection}`); assert.equal(r.status, 0);
    const p = JSON.parse(r.stdout); assert.equal(p.networkRequests, 0);
    assert.equal(p.limits.maximumRequests, selection === 'both' ? 56 : 28);
    assert.equal(p.mode, 'plan'); assert.equal(p.ready, false);
  }
});
test('v2 rejects old or missing approval before key access and rejects unknown/duplicate arguments', () => {
  for (const args of [['--live'], ['--live', '--approved-plan=fc1301ef9114cda9d935b704d3fb3979da9887e22425970985fbc4ed35849272']]) {
    const r = run(...args); assert.equal(r.status, 1); assert.equal(JSON.parse(r.stderr).error, 'context_expansion_approval_required');
  }
  for (const args of [['--candidate=bad'], ['--candidate=luna', '--candidate=terra'], ['--unknown']]) {
    const r = run(...args); assert.equal(r.status, 1); assert.equal(JSON.parse(r.stderr).error, 'invalid_context_expansion_arguments');
  }
  const plan = JSON.parse(run().stdout);
  const missing = run('--live', `--approved-plan=${plan.approvalFingerprint}`);
  assert.equal(JSON.parse(missing.stderr).error, 'context_expansion_credential_missing');
});
