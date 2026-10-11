import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createMonthlyRetrospectiveHttpHandler } from '../src/presentation/monthly-retrospective-http-handler.ts';
import { GenerateMonthlyRetrospective } from '../src/application/generate-monthly-retrospective.ts';

test('monthly endpoint authenticates before reading any private records', async () => {
  let calls = 0;
  const handler = createMonthlyRetrospectiveHttpHandler({
    authenticator: { authenticate: async () => null },
    generator: { execute: async () => { calls++; return false; } },
  });
  assert.equal((await handler(new Request('https://app/monthly', {method: 'POST'}))).status, 401);
  assert.equal((await handler(new Request('https://app/monthly'))).status, 405);
  assert.equal(calls, 0);
});

test('monthly endpoint does not expose private errors or generated content', async () => {
  const handler = createMonthlyRetrospectiveHttpHandler({
    authenticator: { authenticate: async () => 'user' },
    generator: { execute: async () => { throw new Error('private answer'); } },
  });
  const response = await handler(new Request('https://app/monthly', {method:'POST',headers:{authorization:'Bearer token'}}));
  assert.equal(response.status, 503);
  assert.equal((await response.text()).includes('private answer'), false);
});

test('monthly generation skips the model when consent or a shared claim is unavailable', async () => {
  const generator = new GenerateMonthlyRetrospective({
    gateway: { prepare: async () => ({claimed:false}), finish: async () => {throw new Error('unreachable');} },
    model: () => {throw new Error('unreachable');},
  });
  assert.equal(await generator.execute('user'), false);
});

test('failed generation releases its lease without persisting source answers', async () => {
  const finished: unknown[] = [];
  const generator = new GenerateMonthlyRetrospective({
    gateway: {
      prepare: async () => ({claimed:true,retrospective_id:'r',token:'t',month:'2026-09-01',questions:[{id:'q',text:'질문',answers:['답변1','답변2']}]}),
      finish: async (_id, _token, content) => { finished.push(content); return false; },
    },
    model: () => ({generate: async () => {throw new Error('model failure');}}),
  });
  await assert.rejects(() => generator.execute('user'));
  assert.deepEqual(finished, [null]);
});
