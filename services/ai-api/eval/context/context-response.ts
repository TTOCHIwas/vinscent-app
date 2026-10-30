import { contextRecord, parseContextUsage, parseResolvedContextModel } from './context-policy.ts';

export function readContextObservation(payload: unknown, model: string) {
  if (!contextRecord(payload) || payload.status !== 'completed' || payload.error != null || !Array.isArray(payload.output)
    || payload.output.some(v => !contextRecord(v) || typeof v.type !== 'string' || !['message', 'reasoning'].includes(v.type))) throw new Error();
  const messages = payload.output.filter(v => v.type === 'message');
  if (messages.length !== 1 || messages[0].role !== 'assistant' || messages[0].status !== 'completed'
    || !Array.isArray(messages[0].content) || messages[0].content.length !== 1) throw new Error();
  const content = messages[0].content[0];
  if (!contextRecord(content) || content.type !== 'output_text' || typeof content.text !== 'string' || content.text.length > 8192) throw new Error();
  const usage = payload.usage == null ? { inputTokens: null, outputTokens: null }
    : contextRecord(payload.usage) ? { inputTokens: payload.usage.input_tokens, outputTokens: payload.usage.output_tokens } : undefined;
  return { classification: JSON.parse(content.text) as unknown,
    resolvedModel: parseResolvedContextModel(payload.model, model), usage: parseContextUsage(usage) };
}
