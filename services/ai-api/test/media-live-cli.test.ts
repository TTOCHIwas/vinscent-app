import assert from 'node:assert/strict';
import test from 'node:test';
import { spawnSync } from 'node:child_process';

const run = (...args: string[]) => spawnSync(process.execPath,
  ['--experimental-strip-types', 'eval/run-media-evaluation.ts', ...args], { encoding: 'utf8' });

test('new media runner defaults to a concrete network-free cost and transmission plan', () => {
  const result = run('--provider=openai', '--asr=openai');
  assert.equal(result.status, 0);
  const plan = JSON.parse(result.stdout);
  assert.equal(plan.networkRequests, 0);
  assert.equal(plan.models.transcription, 'gpt-transcribe');
  assert.equal(plan.limits.maximumRequests, 34);
  assert.match(plan.approvalFingerprint, /^[a-f0-9]{64}$/);
});

test('paid execution needs an exact plan fingerprint before runtime or credential lookup', () => {
  for (const args of [['--live'], ['--live', `--approved-plan=${'0'.repeat(64)}`]]) {
    const result = run(...args);
    assert.equal(result.status, 1);
    assert.equal(JSON.parse(result.stderr).error, 'media_plan_approval_required');
  }
});

test('duplicate and unknown CLI options cannot start evaluation', () => {
  const result = run('--live', '--live');
  assert.equal(result.status, 1);
  assert.equal(JSON.parse(result.stderr).error, 'invalid_media_arguments');
});
