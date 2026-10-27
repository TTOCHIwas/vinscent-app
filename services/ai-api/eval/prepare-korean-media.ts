import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { NativeMediaRuntime } from './media/native-media-runtime.ts';

if (process.argv.slice(2).join(' ') !== '--prepare') {
  console.log(JSON.stringify({ usage: 'prepare-korean-media.ts --prepare', networkRequests: 0 }));
} else {
  try {
    const root = new URL('./fixtures/', import.meta.url);
    const manifestUrl = new URL('content-safety-media-ko.json', root);
    const manifest = JSON.parse(readFileSync(manifestUrl, 'utf8'));
    const runtime = new NativeMediaRuntime({ python: required('CONTENT_SAFETY_PYTHON'),
      vadModel: required('CONTENT_SAFETY_VAD_MODEL'), asrModel: required('CONTENT_SAFETY_ASR_MODEL') });
    if (manifest.cases.filter((c: { preparation: string }) => c.preparation === 'pending_local_synthetic_speech').length !== 8) throw new Error();
    const sources = [];
    for (const sample of manifest.cases.filter((c: { preparation: string }) => c.preparation === 'pending_local_synthetic_speech')) {
      const generated = await runtime.synthesize(sample.referenceText, AbortSignal.timeout(20_000)) as { wavBase64: string; voice: string; language: string };
      if (sample.id === 'audio-noisy-threat-ko') {
        const augmented = await runtime.encodeFixture({ kind: 'audio', format: 'WAV', bytes: generated.wavBase64 }, AbortSignal.timeout(20_000)) as { bytes: string };
        generated.wavBase64 = augmented.bytes;
      }
      const wav = Buffer.from(generated.wavBase64, 'base64');
      const decoded = await runtime.decodeAudio({ id: sample.id, kind: 'audio', mimeType: 'audio/wav', bytes: wav }, AbortSignal.timeout(20_000)) as { durationMs: number };
      const encoded = await runtime.encodeFixture({ kind: 'audio', bytes: generated.wavBase64 }, AbortSignal.timeout(20_000)) as { bytes: string };
      const m4a = Buffer.from(encoded.bytes, 'base64');
      const wavAsset = `media-ko/${sample.id}.wav`;
      const asset = `media-ko/${sample.id}.m4a`;
      if (existsSync(new URL(asset, root)) || existsSync(new URL(wavAsset, root))) throw new Error();
      writeFileSync(new URL(wavAsset, root), wav, { flag: 'wx' });
      writeFileSync(new URL(asset, root), m4a, { flag: 'wx' });
      sources.push({ id: `${sample.id}-wav`, asset: wavAsset, mimeType: 'audio/wav', sha256: hash(wav) });
      Object.assign(sample, { asset, sha256: hash(m4a), mimeType: 'audio/mp4', durationSeconds: decoded.durationMs / 1000,
        preparation: 'local_speech_generated', synthesis: { voice: generated.voice, language: generated.language,
          method: 'Windows.Media.SpeechSynthesis', referenceSha256: hash(Buffer.from(sample.referenceText, 'utf8')) }, humanReviewed: false });
      if (sample.id === 'audio-noisy-threat-ko') sample.signalRecipe = { speed: 1.25, noiseSnrDb: 15, seed: 20261027 };
    }
    for (const [id, format, extension, mimeType] of [
      ['image-normal-ko', 'JPEG', 'jpg', 'image/jpeg'], ['image-threat-ko', 'WEBP', 'webp', 'image/webp'],
    ]) {
      const sample = manifest.cases.find((c: { id: string }) => c.id === id);
      const bytes = readFileSync(new URL(sample.asset, root));
      const encoded = await runtime.encodeFixture({ kind: 'image', bytes: bytes.toString('base64'), format }, AbortSignal.timeout(20_000)) as { bytes: string };
      sources.push({ id: `${id}-png`, asset: sample.asset, mimeType: 'image/png', sha256: sample.sha256 });
      sample.asset = `media-ko/${id}.${extension}`;
      writeFileSync(new URL(sample.asset, root), Buffer.from(encoded.bytes, 'base64'), { flag: 'wx' });
      sample.sha256 = hash(Buffer.from(encoded.bytes, 'base64')); sample.mimeType = mimeType;
    }
    const controls = [];
    for (const [id, sourceId, mimeType, extension] of [
      ['codec-corrupt-m4a', 'audio-normal-ko', 'audio/mp4', 'm4a'],
      ['codec-corrupt-jpeg', 'image-normal-ko', 'image/jpeg', 'jpg'],
      ['codec-corrupt-webp', 'image-threat-ko', 'image/webp', 'webp'],
    ]) {
      const sample = manifest.cases.find((c: { id: string }) => c.id === sourceId);
      const bytes = readFileSync(new URL(sample.asset, root)).subarray(0, 24);
      const asset = `media-ko/${id}.${extension}`;
      writeFileSync(new URL(asset, root), bytes, { flag: 'wx' });
      controls.push({ id, asset, mimeType, expected: 'unavailable', sha256: hash(bytes) });
    }
    manifest.schemaVersion = 2; manifest.sourceVariants = sources; manifest.codecControls = controls;
    writeFileSync(manifestUrl, JSON.stringify(manifest, null, 2) + '\n');
    console.log(JSON.stringify({ preparedSpeech: 8, sourceVariants: sources.length, codecControls: controls.length,
      humanListeningPerformed: false, networkRequests: 0 }));
  } catch { console.error(JSON.stringify({ error: 'media_preparation_failed' })); process.exitCode = 1; }
}
function required(name: string) { const value = process.env[name]?.trim(); if (!value) throw new Error(); return value; }
function hash(data: Uint8Array) { return createHash('sha256').update(data).digest('hex'); }
