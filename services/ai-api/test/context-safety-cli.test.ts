import assert from 'node:assert/strict';
import test from 'node:test';
import { spawnSync } from 'node:child_process';

const run = (...args: string[]) => spawnSync(process.execPath,
  ['--experimental-strip-types', 'eval/run-context-evaluation.ts', ...args], { encoding: 'utf8' });

test('context comparison defaults to a network-free plan and never loads keys', () => {
  const result = run();
  assert.equal(result.status, 0);
  const plan = JSON.parse(result.stdout);
  assert.equal(plan.networkRequests, 0);
  assert.equal(plan.limits.maximumRequests, 24);
  assert.equal(plan.mode, 'plan');
  assert.equal(plan.inputs.syntheticTextCases, 12);
});

test('missing or stale approval is rejected before credentials or provider calls', () => {
  for (const args of [['--live'], ['--live', `--approved-plan=${'0'.repeat(64)}`], ['--live', '--candidate=terra']]) {
    const result = run(...args);
    assert.equal(result.status, 1);
    assert.equal(JSON.parse(result.stderr).error, 'context_plan_approval_required');
  }
});

test('unknown and duplicate arguments cannot silently select a different paid model', () => {
  for (const args of [['--candidate=unknown'], ['--candidate=luna', '--candidate=terra'], ['--model=other']]) {
    const result = run(...args);
    assert.equal(result.status, 1);
    assert.equal(JSON.parse(result.stderr).error, 'invalid_context_arguments');
  }
});
