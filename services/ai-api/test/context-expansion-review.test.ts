import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { createContextExpansionReviewTemplate, reviewContextExpansion } from '../eval/context/context-expansion-review.ts';

const packPath = 'eval/fixtures/content-safety-context-expansion-ko.json';
const load = () => JSON.parse(readFileSync(packPath, 'utf8'));
const inspect = (pack: unknown = load(), review?: unknown) => reviewContextExpansion(pack, review);

test('new synthetic pack has 28 unmeasured cases; label proposals grant no independent validation or publication', () => {
  const result = inspect();
  assert.equal(result.validEvidence, true);
  assert.equal(result.totalCases, 28);
  assert.equal(result.priorNormalizedOverlaps, 0);
  assert.equal(result.pendingReviews, 28);
  assert.equal(result.labelReviewComplete, false);
  assert.equal(result.independentlyValidated, false);
  assert.equal(result.newModelQualityEvaluated, false);
  assert.equal(result.ready, false);
  assert.equal(result.productionPublicationAuthorized, false);
  assert.equal(result.networkRequests, 0);
  assert.equal(JSON.stringify(result).includes(load().cases[0].text), false);
});

test('review template binds corpus and individual text hashes without copying proposed answers', () => {
  const template = createContextExpansionReviewTemplate(load());
  assert.equal(template.reviewMethod, 'human_label_review');
  assert.match(template.packSha256, /^[a-f0-9]{64}$/);
  assert.equal(template.reviews.length, 28);
  for (const row of template.reviews) {
    assert.equal(row.decision, null);
    assert.equal(row.reviewerId, null);
    assert.equal(row.reviewedAt, null);
    assert.match(row.textSha256, /^[a-f0-9]{64}$/);
  }
});

for (const [name, mutate] of [
  ['duplicate normalized text', (p: any) => { p.cases[1].text = p.cases[0].text.normalize('NFD').split('').join(' '); }],
  ['overlap with earlier corpus', (p: any) => { p.cases[0].text = '거절하면 사적인 사진을 퍼뜨리겠다.'; }],
  ['coercible ID', (p: any) => { p.cases[0].id = [p.cases[0].id]; }],
  ['coercible proposal', (p: any) => { p.cases[0].proposedDecision = ['allow']; }],
  ['unknown group', (p: any) => { p.cases[0].group = 'unknown'; }],
  ['missing case', (p: any) => { p.cases.pop(); }],
  ['claimed validated labels', (p: any) => { p.labelStatus = 'validated'; }],
  ['real source data', (p: any) => { p.syntheticOnly = false; }],
  ['wrong policy version', (p: any) => { p.policyVersion = 'ko-context-candidate-v1'; }],
  ['null as safe answer', (p: any) => { p.cases.find((c: any) => c.group === 'unresolved_context').proposedDecision = 'allow'; }],
] as const) {
  test(`${name} cannot pass preparation review`, () => {
    const pack = load(); mutate(pack);
    const result = inspect(pack);
    assert.equal(result.validEvidence, false);
    assert.equal(result.ready, false);
    assert.throws(() => createContextExpansionReviewTemplate(pack));
  });
}

test('partial human records remain pending and disagreements remain distinct from model observations', () => {
  const pack = load(); const review = createContextExpansionReviewTemplate(pack);
  review.reviews[0] = { ...review.reviews[0], decision: 'allow', reviewerId: 'test-only', reviewedAt: '2026-10-29T00:00:00.000Z' };
  const result = inspect(pack, review);
  assert.equal(result.completedReviews, 1);
  assert.equal(result.pendingReviews, 27);
  assert.equal(result.proposalDisagreements, 1);
  assert.equal(result.newModelQualityEvaluated, false);
  assert.equal(JSON.stringify(result).includes('test-only'), false);
});

for (const [name, mutate] of [
  ['stale corpus', (r: any) => { r.packSha256 = '0'.repeat(64); }],
  ['stale text', (r: any) => { r.reviews[0].textSha256 = '0'.repeat(64); }],
  ['duplicate record', (r: any) => { r.reviews.push(r.reviews[0]); }],
  ['unknown record', (r: any) => { r.reviews[0].id = 'unknown'; }],
  ['automatic review', (r: any) => { r.reviewMethod = 'automatic_asr'; }],
  ['coercible decision', (r: any) => { r.reviews[0].decision = ['allow']; }],
  ['invalid date', (r: any) => { r.reviews[0].reviewedAt = '2026-02-30T00:00:00.000Z'; }],
  ['future date', (r: any) => { r.reviews[0].reviewedAt = '2999-01-01T00:00:00.000Z'; }],
  ['decision without reviewer', (r: any) => { r.reviews[0].decision = 'allow'; }],
] as const) {
  test(`${name} cannot supply human review evidence`, () => {
    const review = createContextExpansionReviewTemplate(load()); mutate(review);
    const result = inspect(load(), review);
    assert.equal(result.validEvidence, false);
    assert.equal(result.productionPublicationAuthorized, false);
  });
}

test('completed self-reported review cannot prove reviewer independence, quality, or paid-call approval', () => {
  const pack = load(); const review = createContextExpansionReviewTemplate(pack);
  for (const row of review.reviews) Object.assign(row, { decision: pack.cases.find((c: any) => c.id === row.id).proposedDecision ?? 'unavailable',
    reviewerId: 'test-only', reviewedAt: '2026-10-29T00:00:00.000Z' });
  const result = inspect(pack, review);
  assert.equal(result.labelReviewComplete, true);
  assert.equal(result.completedReviews, 28);
  assert.equal(result.independentlyValidated, false);
  assert.equal(result.newModelQualityEvaluated, false);
  assert.equal(result.ready, false);
  assert.equal(result.productionPublicationAuthorized, false);
  assert.equal(result.paidEvaluationAuthorized, false);
});

test('offline CLI rejects live and unknown arguments; default prints no source texts', () => {
  const run = (...args: string[]) => spawnSync(process.execPath, ['--experimental-strip-types', 'eval/review-context-expansion.ts', ...args], { encoding: 'utf8' });
  const result = run(); assert.equal(result.status, 0);
  const parsed = JSON.parse(result.stdout);
  assert.equal(parsed.networkRequests, 0); assert.equal(parsed.pendingReviews, 28);
  assert.equal(result.stdout.includes(load().cases[0].text), false);
  const template = run('--review-template'); assert.equal(template.status, 0);
  assert.equal(JSON.parse(template.stdout).reviews.length, 28);
  for (const args of [['--live'], ['--unknown'], ['--review-template', '--review-template'], ['--review=']]) {
    const rejected = run(...args); assert.equal(rejected.status, 1);
    assert.deepEqual(JSON.parse(rejected.stderr), { error: 'context_expansion_review_unavailable' });
  }
});
