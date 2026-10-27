import assert from 'node:assert/strict';
import test from 'node:test';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

const run = (...args: string[]) => spawnSync(process.execPath,
  ['--experimental-strip-types', 'eval/content-safety-media-eval.ts', ...args], { encoding: 'utf8' });

test('media plan is offline, includes pending speech and never reports model quality', () => {
  const result = run();
  assert.equal(result.status, 0);
  const plan = JSON.parse(result.stdout);
  assert.equal(plan.networkRequests, 0);
  assert.equal(plan.mode, 'plan');
  assert.equal(plan.imageCases, 12);
  assert.equal(plan.audioCases, 12);
  assert.equal(plan.pendingSpeechAssets, 0);
  assert.equal(plan.providerSelected, false);
  assert.equal(plan.nextLiveRunMaximum.transcriptions, 8);
  assert.equal(plan.nextLiveRunMaximum.textChecksPerCandidate, 16);
  assert.equal(plan.nextLiveRunMaximum.audioMinutesPerCandidate, 2);
});

test('media preparation refuses live mode and unknown arguments before any API call', () => {
  for (const args of [['--live'], ['--provider=openai'], ['--validate-assets', '--live']]) {
    const result = run(...args);
    assert.equal(result.status, 1);
    assert.equal(JSON.parse(result.stderr).error, 'media_evaluation_preparation_only');
  }
});

test('asset inventory validates committed hashes without treating missing speech as passed', () => {
  const result = run('--validate-assets');
  assert.equal(result.status, 0);
  const inventory = JSON.parse(result.stdout);
  assert.equal(inventory.validatedAssets, 24);
  assert.equal(inventory.pendingAssets, 0);
  assert.equal(inventory.qualityEvaluated, false);
  const manifest = JSON.parse(readFileSync('eval/fixtures/content-safety-media-ko.json', 'utf8'));
  assert.equal(manifest.cases.find((c: { id: string }) => c.id === 'image-normal-ko').referenceText, '내일 같이 산책하자.');
  for (const entry of manifest.cases.filter((c: { asset: string | null }) => c.asset !== null)) {
    const data = readFileSync(`eval/fixtures/${entry.asset}`);
    assert.equal(createHash('sha256').update(data).digest('hex'), entry.sha256);
  }
});
