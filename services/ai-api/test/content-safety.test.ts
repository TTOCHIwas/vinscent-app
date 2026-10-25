import assert from 'node:assert/strict';
import test from 'node:test';
import { CheckSharedContent } from '../src/application/check-shared-content.ts';
import type { ContentSafetyPart } from '../src/domain/content-safety.ts';

const text: ContentSafetyPart = { id: 'caption', kind: 'text', text: '오늘 함께 산책했어.' };
const image: ContentSafetyPart = { id: 'photo', kind: 'image', mimeType: 'image/png', bytes: new Uint8Array([1, 2]) };

function fixture(parts: readonly ContentSafetyPart[] = [text, image]) {
  const calls: string[] = [];
  let saved: unknown;
  let accepted = true;
  let ready = true;
  const provider = {
    supportedKinds: ['text', 'image'] as const,
    async check(part: ContentSafetyPart, _signal: AbortSignal): Promise<unknown> {
      calls.push(part.id);
      return { decision: 'allow' };
    },
  };
  const gateway = {
    async prepare(userId: string, submissionId: string) {
      calls.push(`prepare:${userId}:${submissionId}`);
      return ready ? { id: 'claim', token: 'private-token', parts } : null;
    },
    async complete(id: string, token: string, verdict: unknown) {
      assert.equal(id, 'claim');
      assert.equal(token, 'private-token');
      calls.push('complete');
      saved = verdict;
      return accepted;
    },
  };
  const checker = new CheckSharedContent({ gateway, provider });
  return { checker, calls, provider, gateway, saved: () => saved,
    stale: () => { accepted = false; }, notReady: () => { ready = false; } };
}

test('checks every server-loaded part before recording an allowed decision', async () => {
  const f = fixture();
  assert.equal(await f.checker.execute('owner', 'submission'), 'allowed');
  assert.deepEqual(f.calls, ['prepare:owner:submission', 'caption', 'photo', 'complete']);
  assert.deepEqual(f.saved(), { status: 'allowed', blockedPartIds: [] });
});

test('does not call the provider or finish an unauthorized or unavailable submission', async () => {
  const f = fixture(); f.notReady();
  assert.equal(await f.checker.execute('stranger', 'submission'), 'unavailable');
  assert.deepEqual(f.calls, ['prepare:stranger:submission']);
});

test('cannot mark a stale or edited submission allowed', async () => {
  const f = fixture(); f.stale();
  assert.equal(await f.checker.execute('owner', 'submission'), 'stale');
});

test('blocks the whole submission when a part is rejected', async () => {
  const f = fixture();
  f.provider.check = async (part) => ({ decision: part.kind === 'image' ? 'block' : 'allow' });
  assert.equal(await f.checker.execute('owner', 'submission'), 'blocked');
  assert.deepEqual(f.saved(), { status: 'blocked', blockedPartIds: ['photo'] });
});

for (const value of [null, undefined, {}, true, 'safe', { decision: 'unknown' }, { decision: true }]) {
  test(`does not allow an invalid provider decision: ${JSON.stringify(value)}`, async () => {
    const f = fixture([text]); f.provider.check = async () => value;
    assert.equal(await f.checker.execute('owner', 'submission'), 'unavailable');
    assert.deepEqual(f.saved(), { status: 'unavailable', blockedPartIds: [] });
  });
}

test('provider failure is retryable and never becomes permission to publish', async () => {
  const f = fixture();
  f.provider.check = async () => { throw new Error('secret provider body'); };
  assert.equal(await f.checker.execute('owner', 'submission'), 'unavailable');
  assert.deepEqual(f.saved(), { status: 'unavailable', blockedPartIds: [] });
});

test('unsupported audio is not silently skipped or passed to a text-only service', async () => {
  const f = fixture([text, { id: 'voice', kind: 'audio', mimeType: 'audio/mp4', bytes: new Uint8Array([1]) }]);
  assert.equal(await f.checker.execute('owner', 'submission'), 'unavailable');
  assert.equal(f.calls.includes('caption'), false);
});

for (const parts of [[], [text, text], [{ ...text, text: '  ' }], [{ ...image, bytes: new Uint8Array() }]]) {
  test('invalid or incomplete server content cannot be approved', async () => {
    const f = fixture(parts);
    assert.equal(await f.checker.execute('owner', 'submission'), 'unavailable');
    assert.deepEqual(f.calls, ['prepare:owner:submission', 'complete']);
  });
}

test('passes an abort signal to the provider and ends a stuck check', async () => {
  const f = fixture([text]); let aborted = false;
  f.provider.check = (_part, signal) => new Promise((_resolve, reject) => {
    signal.addEventListener('abort', () => { aborted = true; reject(new Error('timeout')); }, { once: true });
  });
  const checker = new CheckSharedContent({ gateway: f.gateway, provider: f.provider, timeoutMs: 10 });
  assert.equal(await checker.execute('owner', 'submission'), 'unavailable');
  assert.equal(aborted, true);
});

test('completion failures return unavailable without exposing internal errors', async () => {
  const f = fixture([text]);
  f.gateway.complete = async () => { throw new Error('database credential'); };
  assert.equal(await f.checker.execute('owner', 'submission'), 'unavailable');
});

test('provider payload contains no owner, couple, claim token, or storage URL', async () => {
  const f = fixture([text]); let payload: unknown;
  f.provider.check = async (part) => { payload = part; return { decision: 'allow' }; };
  await f.checker.execute('owner', 'submission');
  assert.deepEqual(payload, text);
});

test('even a provider ignoring cancellation cannot keep the check open', async () => {
  const f = fixture([text]);
  f.provider.check = async () => new Promise(() => {});
  const checker = new CheckSharedContent({ gateway: f.gateway, provider: f.provider, timeoutMs: 10 });
  assert.equal(await checker.execute('owner', 'submission'), 'unavailable');
});

test('ownership lookup failures do not reach the provider', async () => {
  const f = fixture();
  f.gateway.prepare = async () => { throw new Error('private owner information'); };
  assert.equal(await f.checker.execute('owner', 'submission'), 'unavailable');
  assert.deepEqual(f.calls, []);
});
