import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

test('all eight synthesized speech files have actual M4A bytes and separate human review status', () => {
  const manifest = JSON.parse(readFileSync('eval/fixtures/content-safety-media-ko.json', 'utf8'));
  const speech = manifest.cases.filter((c: { id: string; preparation?: string }) => c.preparation === 'local_speech_generated');
  assert.equal(speech.length, 8);
  for (const sample of speech) {
    assert.equal(sample.mimeType, 'audio/mp4');
    const bytes = readFileSync(`eval/fixtures/${sample.asset}`);
    assert.equal(bytes.subarray(4, 8).toString(), 'ftyp');
    assert.equal(createHash('sha256').update(bytes).digest('hex'), sample.sha256);
    assert(sample.durationSeconds > 0 && sample.durationSeconds <= 15);
    assert.equal(sample.humanReviewed, false);
    assert.equal(sample.synthesis.voice, 'Microsoft Heami');
  }
});

test('fixture variants cover app JPEG and WebP, plus malformed codec controls', () => {
  const manifest = JSON.parse(readFileSync('eval/fixtures/content-safety-media-ko.json', 'utf8'));
  assert(manifest.cases.some((c: { mimeType: string }) => c.mimeType === 'image/jpeg'));
  assert(manifest.cases.some((c: { mimeType: string }) => c.mimeType === 'image/webp'));
  assert.equal(manifest.codecControls.length, 3);
  for (const control of manifest.codecControls) assert.equal(control.expected, 'unavailable');
});
