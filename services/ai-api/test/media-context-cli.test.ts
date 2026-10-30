import assert from 'node:assert/strict';
import test from 'node:test';
import { spawnSync } from 'node:child_process';
const run = (...args: string[]) => {
  const env = { ...process.env }; for (const k of Object.keys(env)) if (k.startsWith('CONTENT_SAFETY_')) delete env[k];
  return spawnSync(process.execPath, ['--experimental-strip-types', 'eval/run-media-context.ts', ...args], { env, encoding: 'utf8' });
};
test('media-context CLI defaults to a keyless plan; stale approval precedes runtime/key access', () => {
  const r = run(); assert.equal(r.status, 0); const p = JSON.parse(r.stdout);
  assert.equal(p.networkRequests, 0); assert.equal(p.limits.maximumRequests, 54);
  for (const args of [['--live'], ['--live', '--approved-plan=63c0dce29e634c7b269328d64579133246b06c18f88175a6d438a2027874847d']])
    assert.equal(JSON.parse(run(...args).stderr).error, 'media_context_approval_required');
  for (const args of [['--unknown'], ['--live', '--verify-local'], ['--candidate=luna', '--candidate=terra']])
    assert.equal(JSON.parse(run(...args).stderr).error, 'invalid_media_context_arguments');
});

test('mocked CLI shares observed OCR/ASR across both candidates and keeps no-text images unavailable', () => {
  const plan = JSON.parse(run().stdout);
  const runtimeUrl = new URL('../eval/media/native-media-runtime.ts', import.meta.url).href;
  const script = `import {NativeMediaRuntime} from ${JSON.stringify(runtimeUrl)};
NativeMediaRuntime.prototype.decodeImage=async p=>{if(p.id.includes('corrupt')||p.id.includes('unsupported'))throw new Error();return {id:p.id,pngBase64:'AQ=='};};
NativeMediaRuntime.prototype.ocr=async p=>({text:p.id.includes('drawing')||p.id.includes('scene-proxy')?'':'관측된 합성 문장',words:p.id.includes('drawing')||p.id.includes('scene-proxy')?0:3});
NativeMediaRuntime.prototype.decodeAudio=async p=>{if(p.id.includes('corrupt')||p.id.includes('unsupported'))throw new Error();return {wavBase64:Buffer.from(p.id).toString('base64'),durationMs:1000,sampleRate:16000,samples:16000};};
NativeMediaRuntime.prototype.detectSpeech=async p=>({speechDetected:!Buffer.from(p.wavBase64,'base64').toString().match(/silence|noise$/),speechMs:1000,maximumProbability:.9});
globalThis.fetch=async(url,init)=>{if(String(url).endsWith('/transcriptions'))return Response.json({text:'관측된 합성 문장',languages:[{code:'ko'}]});
const b=JSON.parse(init.body);if(String(url).endsWith('/moderations')){const keys=['harassment','harassment/threatening','hate','hate/threatening','illicit','illicit/violent','self-harm','self-harm/intent','self-harm/instructions','sexual','sexual/minors','violence','violence/graphic'];return Response.json({results:[{flagged:false,categories:Object.fromEntries(keys.map(k=>[k,false]))}]});}
const text=JSON.parse(b.input[0].content[0].text).text;if(text!=='관측된 합성 문장')throw new Error('reference-substitution');
return Response.json({status:'completed',model:b.model,usage:{input_tokens:100,output_tokens:30},output:[{type:'message',role:'assistant',status:'completed',content:[{type:'output_text',text:JSON.stringify({policy_version:'ko-context-proposal-v2',decision:'allow',intent:'benign',evidence:[text]})}]}]});};`;
  const r = spawnSync(process.execPath, ['--experimental-strip-types', '--import', `data:text/javascript,${encodeURIComponent(script)}`,
    'eval/run-media-context.ts', '--live', `--approved-plan=${plan.approvalFingerprint}`], { encoding: 'utf8', env: { ...process.env,
    CONTENT_SAFETY_OPENAI_API_KEY: 'unit-test-only', CONTENT_SAFETY_PYTHON: 'mock', CONTENT_SAFETY_VAD_MODEL: 'mock', CONTENT_SAFETY_ASR_MODEL: 'mock' } });
  assert.equal(r.status, 1); const report = JSON.parse(r.stdout);
  assert.equal(report.actualRequests, 50); assert.equal(report.results.length, 48);
  assert.equal(report.stoppedOnOperationalFailure, false);
  assert(report.results.filter(x => ['image-drawing', 'image-scene-proxy'].includes(x.id)).every(x => x.actual === 'unavailable'));
  assert.equal(report.diagnostics.filter(x => x.stage === 'transcription').length, 8);
  assert.equal(report.generalTextSafetyCovered, false);
});

test('local verification prepares request hashes from observed recognition without fake classifier outputs or network', () => {
  const runtimeUrl = new URL('../eval/media/native-media-runtime.ts', import.meta.url).href;
  const script = `import {NativeMediaRuntime} from ${JSON.stringify(runtimeUrl)};
NativeMediaRuntime.prototype.decodeImage=async p=>{if(p.id.includes('corrupt')||p.id.includes('unsupported'))throw new Error();return {id:p.id,pngBase64:'AQ=='};};
NativeMediaRuntime.prototype.ocr=async p=>({text:p.id.includes('drawing')||p.id.includes('scene-proxy')?'':'실제 관측 대체 모의값',words:p.id.includes('drawing')||p.id.includes('scene-proxy')?0:3});
NativeMediaRuntime.prototype.decodeAudio=async p=>{if(p.id.includes('corrupt')||p.id.includes('unsupported'))throw new Error();return {wavBase64:Buffer.from(p.id).toString('base64'),durationMs:1000,sampleRate:16000,samples:16000};};
NativeMediaRuntime.prototype.detectSpeech=async p=>({speechDetected:!Buffer.from(p.wavBase64,'base64').toString().match(/silence|noise$/),speechMs:1000,maximumProbability:.9});
NativeMediaRuntime.prototype.transcribe=async()=>({text:'실제 관측 대체 모의값',language:'ko',confidence:.99});
globalThis.fetch=async()=>{throw new Error('network-must-not-run');};`;
  const result = spawnSync(process.execPath, ['--experimental-strip-types', '--import', `data:text/javascript,${encodeURIComponent(script)}`,
    'eval/run-media-context.ts', '--verify-local'], { encoding: 'utf8', env: { ...process.env,
      CONTENT_SAFETY_PYTHON: 'mock', CONTENT_SAFETY_VAD_MODEL: 'mock', CONTENT_SAFETY_ASR_MODEL: 'mock' } });
  assert.equal(result.status, 1); const report = JSON.parse(result.stdout);
  assert.equal(report.networkRequests, 0); assert.equal(report.contextQualityEvaluated, false);
  assert.equal(report.contextRequestsPrepared, 32);
  assert(report.results.filter(r => r.requestBodySha256ByModel.length).every(r => r.extractionStatus === 'complete' && r.externalEligible));
  assert(!result.stdout.includes('실제 관측 대체 모의값'));
});
