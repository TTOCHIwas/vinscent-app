import { CheckSharedContent } from './check-shared-content.ts';
import type { ContentSafetyProvider } from './content-safety-port.ts';

export type ContentSafetyEvaluationCase = {
  readonly id: string; readonly group: string; readonly text: string; readonly expected: 'allow' | 'block';
};

/** Evaluates only caller-supplied synthetic cases; reports contain no submitted text. */
export async function evaluateContentSafety(options: {
  cases: readonly ContentSafetyEvaluationCase[]; provider: ContentSafetyProvider; timeoutMs?: number;
}) {
  if (options.cases.length === 0 || new Set(options.cases.map((c) => c.id)).size !== options.cases.length
    || options.cases.some((c) => !c.id?.trim() || !c.group?.trim() || !c.text?.trim()
      || !['allow', 'block'].includes(c.expected))) throw new TypeError('invalid evaluation cases');
  const results: { id: string; group: string; expected: 'allow' | 'block'; actual: 'allow' | 'block' | 'unavailable'; latencyMs: number }[] = [];
  for (const candidate of options.cases) {
    const checker = new CheckSharedContent({
      provider: options.provider, timeoutMs: options.timeoutMs,
      gateway: {
        prepare: async () => ({ id: candidate.id, token: 'synthetic-only', parts: [{ id: candidate.id, kind: 'text', text: candidate.text }] }),
        complete: async () => true,
      },
    });
    const startedAt = performance.now();
    const status = await checker.execute('synthetic-evaluation', candidate.id);
    results.push({ id: candidate.id, group: candidate.group, expected: candidate.expected,
      actual: status === 'allowed' ? 'allow' : status === 'blocked' ? 'block' : 'unavailable',
      latencyMs: Math.round(performance.now() - startedAt) });
  }
  const latencies = results.map((r) => r.latencyMs).sort((a, b) => a - b);
  return {
    scope: 'synthetic_korean_text_only' as const,
    total: results.length,
    correct: results.filter((r) => r.actual === r.expected).length,
    falseAllows: results.filter((r) => r.expected === 'block' && r.actual === 'allow').length,
    falseBlocks: results.filter((r) => r.expected === 'allow' && r.actual === 'block').length,
    unavailable: results.filter((r) => r.actual === 'unavailable').length,
    latencyP50Ms: latencies[Math.ceil(latencies.length * 0.5) - 1],
    latencyP95Ms: latencies[Math.ceil(latencies.length * 0.95) - 1],
    results,
  };
}
