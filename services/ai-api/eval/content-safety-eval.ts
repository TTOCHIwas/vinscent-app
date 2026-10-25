import { evaluateContentSafety } from '../src/application/evaluate-content-safety.ts';
import { OpenAiContentSafetyProvider } from '../src/infrastructure/openai-content-safety-provider.ts';
import { CloudflareContentSafetyProvider } from '../src/infrastructure/cloudflare-content-safety-provider.ts';
import { contentSafetyKoreanCases } from './fixtures/content-safety-ko.ts';

const args = process.argv.slice(2);
const providerName = args.find((arg) => arg.startsWith('--provider='))?.slice('--provider='.length);
if (args.some((arg) => arg !== '--live' && !/^--provider=(openai|cloudflare)$/.test(arg))) {
  console.error('Usage: eval:content-safety [--live --provider=openai|cloudflare]');
  process.exitCode = 1;
} else if (!args.includes('--live')) {
  console.log(JSON.stringify({ mode: 'plan', networkRequests: 0, scope: 'synthetic_korean_text_only',
    cases: contentSafetyKoreanCases.length,
    candidates: ['openai:omni-moderation-latest', 'cloudflare:@cf/meta/llama-guard-3-8b'],
    imageEvaluated: false, audioEvaluated: false, providerSelected: false }, null, 2));
} else {
  try {
    let provider;
    if (providerName === 'openai') {
      provider = new OpenAiContentSafetyProvider({ apiKey: required('CONTENT_SAFETY_OPENAI_API_KEY') });
    } else if (providerName === 'cloudflare') {
      provider = new CloudflareContentSafetyProvider({ accountId: required('CONTENT_SAFETY_CLOUDFLARE_ACCOUNT_ID'),
        apiToken: required('CONTENT_SAFETY_CLOUDFLARE_API_TOKEN') });
    } else throw new Error('content_safety_provider_required');
    const report = await evaluateContentSafety({ provider, cases: contentSafetyKoreanCases });
    console.log(JSON.stringify({ provider: providerName, ...report }, null, 2));
    if (report.falseAllows > 0 || report.falseBlocks > 0 || report.unavailable > 0) process.exitCode = 1;
  } catch (error) {
    const code = error instanceof Error && /^(content_safety_missing_environment:CONTENT_SAFETY_[A-Z_]+|content_safety_provider_required)$/.test(error.message)
      ? error.message : 'content_safety_evaluation_failed';
    console.error(JSON.stringify({ error: code }));
    process.exitCode = 1;
  }
}

function required(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`content_safety_missing_environment:${name}`);
  return value;
}
