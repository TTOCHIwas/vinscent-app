import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { createSpeechReviewTemplate, reviewMediaPolicyEvidence } from '../eval/policy/content-safety-policy-review.ts';
import { contentSafetyContextCases } from '../eval/fixtures/content-safety-context-ko.ts';

const manifestBytes = readFileSync('eval/fixtures/content-safety-media-ko.json');
const manifest = JSON.parse(manifestBytes.toString('utf8'));
const recorded = JSON.parse(readFileSync('../../docs/release/content-safety-media-evaluation-2026-10-29/openai.json', 'utf8'));
const inspect = (report: unknown = structuredClone(recorded), speechReview?: unknown, bytes = manifestBytes) =>
  reviewMediaPolicyEvidence({ report, manifestBytes: bytes, speechReview });
const simulatedReviews = () => {
  const evidence = createSpeechReviewTemplate(manifestBytes);
  for (const review of evidence.reviews) {
    Object.assign(review, { listenedM4a: true, listenedWav: true, reviewerId: 'unit-test-only',
      reviewedAt: '2026-10-29T00:00:00.000Z', heardText: manifest.cases.find((c: { id: string }) => c.id === review.id).referenceText });
  }
  return evidence;
};

test('replays four observed context failures and groups the two duplicated texts without approving HTTP success', () => {
  const result = inspect();
  assert.equal(result.validEvidence, true);
  assert.equal(result.ready, false);
  assert.equal(result.productionPublicationAuthorized, false);
  assert.equal(result.networkRequests, 0);
  assert.equal(result.substantiveCases, 18);
  assert.equal(result.substantiveMatches, 14);
  assert.equal(result.falseAllows, 2);
  assert.equal(result.falseBlocks, 2);
  assert.equal(result.uniqueMismatchTexts, 2);
  assert.equal(result.speech.pending, 8);
  assert(result.blockers.includes('classification_mismatch'));
  assert.equal(JSON.stringify(result).includes('거절하면'), false);
});

for (const mutate of [
  (r: any) => r.results.pop(),
  (r: any) => r.results.push(r.results[0]),
  (r: any) => { r.results[6].expected = r.results[6].actual; },
  (r: any) => { r.results[6].sourceSha256 = '0'.repeat(64); },
  (r: any) => { r.diagnostics.pop(); },
  (r: any) => { r.results[0].characterErrorRate = NaN; },
]) {
  test('incomplete, relabelled or stale recorded evidence cannot pass review', () => {
    const report = structuredClone(recorded); mutate(report);
    const result = inspect(report);
    assert.equal(result.validEvidence, false);
    assert.equal(result.ready, false);
    assert.equal(result.productionPublicationAuthorized, false);
  });
}

test('same manifest with different checkout newlines remains reviewable; content edits do not', () => {
  const crlf = Buffer.from(manifestBytes.toString('utf8').replace(/\r?\n/g, '\r\n'));
  assert.equal(inspect(recorded, undefined, crlf).validEvidence, true);
  const changed = structuredClone(manifest); changed.cases[6].referenceText = '수정된 합성 대본';
  assert.equal(inspect(recorded, undefined, Buffer.from(JSON.stringify(changed))).validEvidence, false);
});

test('a failed provider call blocks readiness independently of classification counts', () => {
  const report = structuredClone(recorded); report.diagnostics[0] = { status: 500, failure: 'http_error' };
  const result = inspect(report);
  assert(result.blockers.includes('provider_failure'));
  assert.equal(result.ready, false);
});

test('an unexpected approval of a control is reported explicitly', () => {
  const report = structuredClone(recorded); report.results.find((r: { id: string }) => r.id === 'audio-silence').actual = 'allow';
  const result = inspect(report);
  assert.equal(result.controlUnexpectedApprovals, 1);
  assert(result.blockers.includes('control_approved'));
});

test('ASR or a report boolean cannot supply human listening evidence', () => {
  const report = structuredClone(recorded); report.humanListeningPerformed = true;
  const result = inspect(report);
  assert.equal(result.speech.completed, 0);
  assert.equal(result.speech.pending, 8);
  assert(result.blockers.includes('human_listening_pending'));
  const automatic = simulatedReviews(); automatic.reviewMethod = 'automatic_asr';
  assert.equal(inspect(recorded, automatic).validEvidence, false);
});

test('human review template binds eight M4A and WAV pairs to hashes without prefilled heard text', () => {
  const template = createSpeechReviewTemplate(manifestBytes);
  assert.equal(template.reviews.length, 8);
  for (const review of template.reviews) {
    assert.equal(review.heardText, null);
    assert.equal(review.listenedM4a, false);
    assert.equal(review.listenedWav, false);
    assert.match(review.m4aSha256, /^[a-f0-9]{64}$/);
    assert.match(review.wavSha256, /^[a-f0-9]{64}$/);
  }
  assert.equal(inspect(recorded, template).speech.pending, 8);
});

test('only explicit listening to both codecs and heard text completes a record', () => {
  const evidence = simulatedReviews(); evidence.reviews[0].listenedWav = false;
  const result = inspect(recorded, evidence);
  assert.equal(result.speech.completed, 7);
  assert.equal(result.speech.pending, 1);
  assert.equal(JSON.stringify(result).includes('unit-test-only'), false);
  evidence.reviews[0].listenedWav = true; evidence.reviews[0].heardText = '대본과 다르게 들린 합성 발화';
  const mismatch = inspect(recorded, evidence);
  assert.equal(mismatch.speech.mismatches, 1);
  assert(mismatch.blockers.includes('human_listening_mismatch'));
});

for (const mutate of [
  (e: any) => { e.reviews[0].m4aSha256 = '0'.repeat(64); },
  (e: any) => { e.reviews[0].wavSha256 = '0'.repeat(64); },
  (e: any) => { e.reviews.push(e.reviews[0]); },
  (e: any) => { e.reviews[0].id = 'unknown-audio'; },
  (e: any) => { e.reviews[0].reviewedAt = 'not-a-date'; },
]) {
  test('stale, duplicated, unknown or invalid human records are rejected', () => {
    const evidence = simulatedReviews(); mutate(evidence);
    assert.equal(inspect(recorded, evidence).validEvidence, false);
  });
}

test('even simulated matching labels and complete human records grant no publication rights or policy approval', () => {
  const report = structuredClone(recorded);
  for (const row of report.results) row.actual = row.expected;
  const result = inspect(report, simulatedReviews());
  assert.equal(result.speech.matches, 8);
  assert.equal(result.automaticClassificationPassed, true);
  assert.equal(result.ready, false);
  assert(result.blockers.includes('draft_policy'));
  assert.equal(result.productionPublicationAuthorized, false);
});

test('context corpus keeps existing failure labels and leaves unresolved quotation/reporting cases unavailable', () => {
  assert.equal(contentSafetyContextCases.length, 12);
  assert.equal(new Set(contentSafetyContextCases.map(c => c.id)).size, 12);
  assert(contentSafetyContextCases.every(c => c.reviewStatus === 'draft'));
  for (const id of ['coercion-direct', 'violence-prevention']) {
    const sample = contentSafetyContextCases.find(c => c.id === id)!;
    const media = manifest.cases.find((c: { id: string }) => c.id === (id === 'coercion-direct' ? 'image-coercion-ko' : 'image-negation-ko'));
    assert.equal(sample.text, media.referenceText);
    assert.equal(sample.expected, media.expected);
  }
  assert(contentSafetyContextCases.filter(c => c.group === 'unresolved_context').every(c => c.expected === 'unavailable'));
  assert.equal(contentSafetyContextCases.find(c => c.id === 'mixed-negation-coercion')?.expected, 'block');
});
