import assert from 'node:assert/strict';
import test from 'node:test';
import { spawnSync } from 'node:child_process';

const run = (...args: string[]) => spawnSync(process.execPath,
  ['--experimental-strip-types', 'eval/review-content-safety-policy.ts', ...args], { encoding: 'utf8' });

test('offline policy review preserves the measured failure rather than rerunning paid requests', () => {
  const result = run();
  assert.equal(result.status, 1);
  const report = JSON.parse(result.stdout);
  assert.equal(report.networkRequests, 0);
  assert.equal(report.falseAllows, 2);
  assert.equal(report.falseBlocks, 2);
  assert.equal(report.contextDraftCases, 12);
  assert.equal(report.speech.pending, 8);
  assert.equal(report.ready, false);
});

test('speech template exports pending records without copying expected scripts into observations', () => {
  const result = run('--speech-template');
  assert.equal(result.status, 0);
  const template = JSON.parse(result.stdout);
  assert.equal(template.reviews.length, 8);
  assert(template.reviews.every((r: { heardText: unknown }) => r.heardText === null));
  assert.equal(result.stdout.includes('referenceText'), false);
});

test('live requests and unreadable review files are rejected with sanitized errors', () => {
  for (const arg of ['--live', '--speech-review=missing-private-review.json']) {
    const result = run(arg);
    assert.equal(result.status, 1);
    assert.equal(JSON.parse(result.stderr).error, 'policy_review_unavailable');
    assert.equal(result.stderr.includes('missing-private-review'), false);
  }
});
