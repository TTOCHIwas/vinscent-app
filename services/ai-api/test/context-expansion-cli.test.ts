import assert from 'node:assert/strict';
import test from 'node:test';
import { spawnSync } from 'node:child_process';

const run = (...args: string[]) => {
  const env = { ...process.env }; delete env.CONTENT_SAFETY_OPENAI_API_KEY;
  return spawnSync(process.execPath, ['--experimental-strip-types', 'eval/run-context-expansion.ts', ...args], { encoding: 'utf8', env });
};
test('v2 CLI defaults to an offline plan; each model has 28 cases and keys are not required', () => {
  for (const selection of ['both', 'luna', 'terra']) {
    const r = run(`--candidate=${selection}`); assert.equal(r.status, 0);
    const p = JSON.parse(r.stdout); assert.equal(p.networkRequests, 0);
    assert.equal(p.limits.maximumRequests, selection === 'both' ? 56 : 28);
    assert.equal(p.mode, 'plan'); assert.equal(p.ready, false);
  }
});
test('v2 rejects old or missing approval before key access and rejects unknown/duplicate arguments', () => {
  for (const args of [['--live'], ['--live', '--approved-plan=fc1301ef9114cda9d935b704d3fb3979da9887e22425970985fbc4ed35849272']]) {
    const r = run(...args); assert.equal(r.status, 1); assert.equal(JSON.parse(r.stderr).error, 'context_expansion_approval_required');
  }
  for (const args of [['--candidate=bad'], ['--candidate=luna', '--candidate=terra'], ['--unknown']]) {
    const r = run(...args); assert.equal(r.status, 1); assert.equal(JSON.parse(r.stderr).error, 'invalid_context_expansion_arguments');
  }
  const plan = JSON.parse(run().stdout);
  const missing = run('--live', `--approved-plan=${plan.approvalFingerprint}`);
  assert.equal(JSON.parse(missing.stderr).error, 'context_expansion_credential_missing');
});

test('simulated CLI runs 56 bounded requests or stops after the first failed response without network', () => {
  const plan = JSON.parse(run().stdout);
  for (const mode of ['success', 'http_failure', 'schema_failure']) {
    const script = `import fs from 'node:fs';
const cases=JSON.parse(fs.readFileSync('eval/fixtures/content-safety-context-expansion-ko.json','utf8')).cases;
globalThis.fetch=async (_url,init)=>{
  if(${JSON.stringify(mode)}==='http_failure')return new Response('unit-private-error',{status:500});
  const b=JSON.parse(init.body);const text=JSON.parse(b.input[0].content[0].text).text;
  const decision=cases.find(c=>c.text===text).proposedDecision??'unavailable';
  const answer={policy_version:${JSON.stringify(mode)}==='schema_failure'?'wrong-version':'ko-context-proposal-v2',decision,
    intent:decision==='block'?'coercion':decision==='allow'?'benign':'unresolved_context',evidence:[text]};
  return Response.json({status:'completed',model:b.model,usage:{input_tokens:100,output_tokens:30},
    output:[{type:'message',role:'assistant',status:'completed',content:[{type:'output_text',text:JSON.stringify(answer)}]}]});
};`;
    const result = spawnSync(process.execPath, ['--experimental-strip-types', '--import', `data:text/javascript,${encodeURIComponent(script)}`,
      'eval/run-context-expansion.ts', '--live', `--approved-plan=${plan.approvalFingerprint}`],
    { encoding: 'utf8', env: { ...process.env, CONTENT_SAFETY_OPENAI_API_KEY: 'unit-test-only' } });
    assert.equal(result.status, mode === 'success' ? 0 : 1);
    const report = JSON.parse(result.stdout);
    assert.equal(report.actualRequests, mode === 'success' ? 56 : 1);
    assert.equal(report.stoppedOnOperationalFailure, mode !== 'success');
    assert.equal(report.ready, false); assert.equal(report.productionPublicationAuthorized, false);
    assert.equal(report.independentlyValidated, false);
    assert(!result.stdout.includes('unit-private-error')); assert(!result.stdout.includes('unit-test-only'));
  }
});
