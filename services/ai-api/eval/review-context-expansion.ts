import { readFileSync } from 'node:fs';
import { createContextExpansionReviewTemplate, reviewContextExpansion } from './context/context-expansion-review.ts';

function readJson(path: string | URL): unknown {
  const bytes = readFileSync(path);
  if (bytes.length > 131_072) throw new Error();
  return JSON.parse(bytes.toString('utf8').replace(/^\uFEFF/, ''));
}

try {
  const args = process.argv.slice(2);
  if (args.length > 1 || (args.length === 1 && args[0] !== '--review-template'
    && (!args[0].startsWith('--review=') || !args[0].slice(9).trim() || args[0].length > 1024))) throw new Error();
  const pack = readJson(new URL('./fixtures/content-safety-context-expansion-ko.json', import.meta.url));
  if (args[0] === '--review-template') console.log(JSON.stringify(createContextExpansionReviewTemplate(pack), null, 2));
  else {
    const result = reviewContextExpansion(pack, args.length ? readJson(args[0].slice(9)) : undefined);
    if (!result.validEvidence) throw new Error();
    console.log(JSON.stringify(result, null, 2));
  }
} catch { console.error(JSON.stringify({ error: 'context_expansion_review_unavailable' })); process.exitCode = 1; }
