import assert from 'node:assert/strict';
import test from 'node:test';
import { spawnSync } from 'node:child_process';

const run = (...args: string[]) => {
  const env = { ...process.env }; delete env.CONTENT_SAFETY_OPENAI_API_KEY;
  return spawnSync(process.execPath, ['--experimental-strip-types', 'eval/run-context-resume.ts', ...args], { env, encoding: 'utf8' });
};
test('resume CLI prints a 28-request offline plan and requires a fresh approval before key access', () => {
  const r = run(); assert.equal(r.status, 0); const p = JSON.parse(r.stdout);
  assert.equal(p.networkRequests, 0); assert.equal(p.limits.maximumRequests, 28); assert.equal(p.ready, false);
  for (const args of [['--live'], ['--live', '--approved-plan=e1d605fa44cca0845fb5fc9aa749736a903ea816d4c99986847c007d37d65ef4']]) {
    const bad = run(...args); assert.equal(bad.status, 1); assert.equal(JSON.parse(bad.stderr).error, 'context_resume_approval_required');
  }
  const missing = run('--live', `--approved-plan=${p.approvalFingerprint}`);
  assert.equal(JSON.parse(missing.stderr).error, 'context_resume_credential_missing');
  for (const args of [['--candidate=luna'], ['--source=other.json'], ['--live', '--live']])
    assert.equal(JSON.parse(run(...args).stderr).error, 'invalid_context_resume_arguments');
});

test('mocked live resume never repeats completed source requests and stops immediately on HTTP failure', () => {
  const plan = JSON.parse(run().stdout);
  for (const mode of ['success', 'failure']) {
    const script = `import fs from 'node:fs';const cases=JSON.parse(fs.readFileSync('eval/fixtures/content-safety-context-expansion-ko.json','utf8')).cases;
globalThis.fetch=async (_url,init)=>{const b=JSON.parse(init.body);const text=JSON.parse(b.input[0].content[0].text).text;
const index=cases.findIndex(c=>c.text===text);if(index<14)throw new Error('completed-request-repeated');
if(${JSON.stringify(mode)}==='failure')return new Response('unit-private-error',{status:500});
const decision=cases[index].proposedDecision??'unavailable';return Response.json({status:'completed',model:b.model,usage:{input_tokens:100,output_tokens:30},
output:[{type:'message',role:'assistant',status:'completed',content:[{type:'output_text',text:JSON.stringify({policy_version:'ko-context-proposal-v2',decision,
intent:decision==='block'?'coercion':decision==='allow'?'benign':'unresolved_context',evidence:[text]})}]}]});};`;
    const r = spawnSync(process.execPath, ['--experimental-strip-types', '--import', `data:text/javascript,${encodeURIComponent(script)}`,
      'eval/run-context-resume.ts', '--live', `--approved-plan=${plan.approvalFingerprint}`],
    { env: { ...process.env, CONTENT_SAFETY_OPENAI_API_KEY: 'unit-test-only' }, encoding: 'utf8' });
    assert.equal(r.status, mode === 'success' ? 0 : 1); const result = JSON.parse(r.stdout);
    assert.equal(result.additionalActualRequests, mode === 'success' ? 28 : 1);
    assert.equal(result.cumulativeActualRequests, mode === 'success' ? 57 : 30);
    assert.equal(result.combined.coverageComplete, mode === 'success');
    assert.equal(result.combined.ready, false); assert(!r.stdout.includes('unit-private-error')); assert(!r.stdout.includes('unit-test-only'));
  }
});
