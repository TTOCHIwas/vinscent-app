import { readFileSync } from 'node:fs';
import { createSpeechReviewTemplate, reviewMediaPolicyEvidence } from './policy/content-safety-policy-review.ts';
import { contentSafetyContextCases } from './fixtures/content-safety-context-ko.ts';

try {
  const args = process.argv.slice(2);
  if (args.length > 1 || (args.length === 1 && args[0] !== '--speech-template'
    && (!args[0].startsWith('--speech-review=') || args[0].length > 1024 || args[0].slice(16).trim() === ''))) throw new Error();
  const manifestBytes = readFileSync(new URL('./fixtures/content-safety-media-ko.json', import.meta.url));
  if (args[0] === '--speech-template') console.log(JSON.stringify(createSpeechReviewTemplate(manifestBytes), null, 2));
  else {
    const report = readJson(new URL('../../../docs/release/content-safety-media-evaluation-2026-10-29/openai.json', import.meta.url));
    const speechReview = args.length ? readJson(args[0].slice(16)) : undefined;
    const result = reviewMediaPolicyEvidence({ report, manifestBytes, speechReview });
    if (!result.validEvidence) throw new Error();
    console.log(JSON.stringify({ ...result, contextDraftCases: contentSafetyContextCases.length,
      newContextQualityEvaluated: false }, null, 2));
    process.exitCode = 1;
  }
} catch { console.error(JSON.stringify({ error: 'policy_review_unavailable' })); process.exitCode = 1; }

function readJson(path: string | URL): unknown {
  const bytes = readFileSync(path);
  if (bytes.length > 1024 * 1024) throw new Error();
  return JSON.parse(bytes.toString('utf8'));
}
