import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

const args = process.argv.slice(2);
if (args.length > 1 || (args.length === 1 && args[0] !== '--validate-assets')) {
  console.error(JSON.stringify({ error: 'media_evaluation_preparation_only' }));
  process.exitCode = 1;
} else {
  try {
    const root = new URL('./fixtures/', import.meta.url);
    const manifest = JSON.parse(readFileSync(new URL('content-safety-media-ko.json', root), 'utf8'));
    if (manifest.syntheticOnly !== true || !Array.isArray(manifest.cases) || manifest.cases.length !== 24
      || new Set(manifest.cases.map((c: { id: string }) => c.id)).size !== 24) throw new Error();
    let validatedAssets = 0;
    let pendingAssets = 0;
    for (const sample of manifest.cases) {
      if (!['image', 'audio'].includes(sample.kind) || !['allow', 'block', 'unavailable'].includes(sample.expected)
        || !/^[a-z0-9-]+$/.test(sample.id)) throw new Error();
      if (sample.asset === null) { pendingAssets++; continue; }
      if (!/^media-ko\/[a-z0-9-]+\.(png|jpg|webp|m4a|wav|bin|svg)$/.test(sample.asset)) throw new Error();
      if (args[0] === '--validate-assets') {
        const bytes = readFileSync(new URL(sample.asset, root));
        if (createHash('sha256').update(bytes).digest('hex') !== sample.sha256) throw new Error();
        validatedAssets++;
      }
    }
    console.log(JSON.stringify({ mode: args.length ? 'asset_validation' : 'plan', networkRequests: 0,
      syntheticOnly: true, imageCases: manifest.cases.filter((c: { kind: string }) => c.kind === 'image').length,
      audioCases: manifest.cases.filter((c: { kind: string }) => c.kind === 'audio').length,
      pendingSpeechAssets: pendingAssets, validatedAssets, pendingAssets,
      qualityEvaluated: false, providerSelected: false,
      nextLiveRunMaximum: { imageChecks: 10, ocrExtractions: 10, transcriptions: 8,
        textChecksPerCandidate: 16, audioMinutesPerCandidate: 2 },
      liveExecutionAvailable: false }, null, 2));
  } catch {
    console.error(JSON.stringify({ error: 'invalid_media_fixture_inventory' }));
    process.exitCode = 1;
  }
}
