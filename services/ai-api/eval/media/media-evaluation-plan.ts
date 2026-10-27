import { createHash } from 'node:crypto';

export function mediaEvaluationPlan(manifestSha256: string, provider: string, asr: string) {
  if (!/^[a-f0-9]{64}$/.test(manifestSha256) || !['openai', 'cloudflare'].includes(provider)
    || !['local', 'openai'].includes(asr)) throw new TypeError('invalid_media_plan');
  const maximumRequests = (provider === 'openai' ? 26 : 16) + (asr === 'openai' ? 8 : 0);
  const plan = { schemaVersion: 1, manifestSha256, provider, asr,
    models: { ocr: 'Windows.Media.Ocr:ko', vad: 'silero-vad-v6.2',
      transcription: asr === 'openai' ? 'gpt-transcribe' : 'vosk-model-small-ko-0.22',
      classification: provider === 'openai' ? 'omni-moderation-latest' : '@cf/meta/llama-guard-3-8b' },
    inputs: { syntheticCases: 24, imagesSentExternally: provider === 'openai' ? 10 : 0,
      maximumTranscriptions: asr === 'openai' ? 8 : 0, maximumAudioMinutes: asr === 'openai' ? 2 : 0,
      maximumTextChecks: 16, sourceAudioFormat: 'M4A/AAC', transmittedAudioFormat: 'PCM16 WAV mono 16kHz' },
    limits: { maximumRequests, retries: 0, perCaseTimeoutMs: 30_000,
      maximumInputBytes: 20 * 1024 * 1024, maximumAudioDurationMs: 15_000 },
    estimatedUsd: (asr === 'openai' ? 0.009 : 0) + (provider === 'cloudflare' ? 0.00780544 : 0),
    estimateAssumptions: 'ASR <= 2 minutes at $0.0045/min; Cloudflare <=16 calls assumed 1000 input/128 output tokens each; taxes and account credits excluded; estimate is not a hard billing cap',
    humanListeningPerformed: false, productionPublicationConnected: false };
  return { ...plan, approvalFingerprint: createHash('sha256').update(JSON.stringify(plan)).digest('hex') };
}

export function createRequestBudget(maximumRequests: number, fetcher: typeof fetch = fetch) {
  if (!Number.isSafeInteger(maximumRequests) || maximumRequests < 1 || maximumRequests > 34) throw new TypeError('invalid_request_budget');
  const diagnostics: { status: number | null; failure: string | null }[] = [];
  let stopped = false;
  const budgetedFetch: typeof fetch = async (url, init) => {
    if (stopped || diagnostics.length >= maximumRequests) throw new Error('media_request_budget_stopped');
    const entry = { status: null as number | null, failure: null as string | null };
    diagnostics.push(entry);
    try {
      const response = await fetcher(url, init);
      entry.status = response.status;
      if (!response.ok) { entry.failure = 'http_error'; stopped = true; }
      return response;
    } catch { stopped = true; entry.failure = 'transport_error'; throw new Error('media_transport_unavailable'); }
  };
  return { fetcher: budgetedFetch, diagnostics, isStopped: () => stopped };
}
