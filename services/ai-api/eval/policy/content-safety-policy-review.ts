import { createHash } from 'node:crypto';

type Decision = 'allow' | 'block' | 'unavailable';
type MediaCase = { id: string; kind: 'image' | 'audio'; sha256: string; expected: Decision;
  referenceText: string; preparation?: string };
type Manifest = { cases: MediaCase[]; sourceVariants: { id: string; sha256: string; mimeType: string }[] };
type SpeechRecord = { id: string; m4aSha256: string; wavSha256: string; listenedM4a: boolean; listenedWav: boolean;
  heardText: string | null; reviewerId: string | null; reviewedAt: string | null };
const record = (v: unknown): v is Record<string, unknown> => v !== null && typeof v === 'object' && !Array.isArray(v);
const sha256 = (text: string) => createHash('sha256').update(text).digest('hex');
const hashIsValid = (v: unknown): v is string => typeof v === 'string' && /^[a-f0-9]{64}$/.test(v);
const idIsValid = (v: unknown): v is string => typeof v === 'string' && /^[a-z0-9-]{1,80}$/.test(v);
const decisionIsValid = (v: unknown): v is Decision => typeof v === 'string' && ['allow', 'block', 'unavailable'].includes(v);
const normalizedSpeech = (text: string) => text.normalize('NFC').replace(/[\s.,!?]/g, '');
const base = { schemaVersion: 1, policyVersion: 'ko-context-review-v1', policyStatus: 'draft',
  networkRequests: 0, ready: false, productionPublicationAuthorized: false } as const;

function readManifest(bytes: Uint8Array): Manifest {
  if (!(bytes instanceof Uint8Array) || bytes.length > 1024 * 1024) throw new Error();
  const manifest: unknown = JSON.parse(Buffer.from(bytes).toString('utf8'));
  if (!record(manifest) || manifest.syntheticOnly !== true || !Array.isArray(manifest.cases)
    || manifest.cases.length !== 24 || !Array.isArray(manifest.sourceVariants)) throw new Error();
  for (const sample of manifest.cases) {
    if (!record(sample) || !idIsValid(sample.id) || !hashIsValid(sample.sha256)
      || typeof sample.kind !== 'string' || !['image', 'audio'].includes(sample.kind) || !decisionIsValid(sample.expected)
      || typeof sample.referenceText !== 'string' || sample.referenceText.length > 2000) throw new Error();
  }
  if (new Set(manifest.cases.map(c => c.id)).size !== 24) throw new Error();
  for (const source of manifest.sourceVariants) {
    if (!record(source) || !idIsValid(source.id) || !hashIsValid(source.sha256) || typeof source.mimeType !== 'string') throw new Error();
  }
  if (new Set(manifest.sourceVariants.map(s => s.id)).size !== manifest.sourceVariants.length) throw new Error();
  const typed = manifest as unknown as Manifest;
  const speech = typed.cases.filter(c => c.preparation === 'local_speech_generated');
  if (speech.length !== 8 || speech.some(c => c.kind !== 'audio'
    || !typed.sourceVariants.some(s => s.id === `${c.id}-wav` && s.mimeType === 'audio/wav'))) throw new Error();
  return typed;
}

function templateFor(manifest: Manifest) {
  return { schemaVersion: 1, syntheticOnly: true, reviewMethod: 'human_listening',
    reviews: manifest.cases.filter(c => c.preparation === 'local_speech_generated').map(c => ({
      id: c.id, m4aSha256: c.sha256, wavSha256: manifest.sourceVariants.find(s => s.id === `${c.id}-wav`)!.sha256,
      listenedM4a: false, listenedWav: false, heardText: null, reviewerId: null, reviewedAt: null,
    } as SpeechRecord)) };
}

export function createSpeechReviewTemplate(manifestBytes: Uint8Array) {
  return templateFor(readManifest(manifestBytes));
}

function reviewSpeech(manifest: Manifest, evidence: unknown) {
  const template = templateFor(manifest);
  const input = evidence === undefined ? template : evidence;
  if (!record(input) || input.schemaVersion !== 1 || input.syntheticOnly !== true || input.reviewMethod !== 'human_listening'
    || !Array.isArray(input.reviews) || input.reviews.length > 8) throw new Error();
  const byId = new Map<string, SpeechRecord>();
  for (const value of input.reviews) {
    if (!record(value) || !idIsValid(value.id) || byId.has(value.id)) throw new Error();
    const expected = template.reviews.find(r => r.id === value.id);
    if (!expected || value.m4aSha256 !== expected.m4aSha256 || value.wavSha256 !== expected.wavSha256
      || typeof value.listenedM4a !== 'boolean' || typeof value.listenedWav !== 'boolean'
      || (value.heardText !== null && (typeof value.heardText !== 'string' || value.heardText.length > 2000))
      || (value.reviewerId !== null && (typeof value.reviewerId !== 'string' || !/^[a-z0-9_-]{1,40}$/i.test(value.reviewerId)))
      || (value.reviewedAt !== null && (typeof value.reviewedAt !== 'string'
        || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value.reviewedAt)
        || !Number.isFinite(Date.parse(value.reviewedAt)) || Date.parse(value.reviewedAt) > Date.now()
        || new Date(value.reviewedAt).toISOString() !== value.reviewedAt))) throw new Error();
    byId.set(value.id, value as unknown as SpeechRecord);
  }
  const results = template.reviews.map(expected => {
    const review = byId.get(expected.id);
    const complete = review?.listenedM4a === true && review.listenedWav === true
      && !!review.heardText?.trim() && !!review.reviewerId && !!review.reviewedAt;
    const source = manifest.cases.find(c => c.id === expected.id)!;
    return { id: expected.id, status: !complete ? 'pending'
      : normalizedSpeech(review!.heardText!) === normalizedSpeech(source.referenceText) ? 'match' : 'mismatch' };
  });
  return { total: 8, completed: results.filter(r => r.status !== 'pending').length,
    pending: results.filter(r => r.status === 'pending').length, matches: results.filter(r => r.status === 'match').length,
    mismatches: results.filter(r => r.status === 'mismatch').length, evidenceKind: 'human_self_report_not_identity_verification', results };
}

export function reviewMediaPolicyEvidence(options: { report: unknown; manifestBytes: Uint8Array; speechReview?: unknown }) {
  try {
    const manifest = readManifest(options.manifestBytes);
    const report = options.report;
    const text = Buffer.from(options.manifestBytes).toString('utf8');
    const lf = text.replace(/\r\n/g, '\n');
    const hashes = [sha256(text), sha256(lf), sha256(lf.replace(/\n/g, '\r\n'))];
    if (!record(report) || !record(report.plan) || !hashIsValid(report.plan.manifestSha256)
      || !hashes.includes(report.plan.manifestSha256)
      || !record(report.plan.limits) || !Number.isSafeInteger(report.plan.limits.maximumRequests)
      || Number(report.plan.limits.maximumRequests) < 1 || Number(report.plan.limits.maximumRequests) > 34
      || !Number.isSafeInteger(report.actualRequests) || Number(report.actualRequests) < 0
      || Number(report.actualRequests) > Number(report.plan.limits.maximumRequests)
      || !Array.isArray(report.diagnostics) || report.diagnostics.length !== report.actualRequests
      || report.completedCases !== 24 || !Array.isArray(report.results) || report.results.length !== 24) throw new Error();
    for (const diagnostic of report.diagnostics) {
      if (!record(diagnostic) || (diagnostic.status !== null && (!Number.isSafeInteger(diagnostic.status)
        || Number(diagnostic.status) < 100 || Number(diagnostic.status) > 599))
        || ![null, 'http_error', 'transport_error'].includes(diagnostic.failure as string | null)) throw new Error();
    }
    const seen = new Set<string>();
    const rows = report.results.map(row => {
      if (!record(row) || !idIsValid(row.id) || seen.has(row.id)) throw new Error();
      seen.add(row.id);
      const source = manifest.cases.find(c => c.id === row.id);
      if (!source || row.expected !== source.expected || row.sourceSha256 !== source.sha256 || !decisionIsValid(row.actual)
        || !Number.isFinite(row.latencyMs) || Number(row.latencyMs) < 0
        || (row.characterErrorRate !== null && (!Number.isFinite(row.characterErrorRate) || Number(row.characterErrorRate) < 0))) throw new Error();
      return { id: source.id, expected: source.expected, actual: row.actual,
        textSha256: sha256(source.referenceText.normalize('NFC').replace(/\s/g, '') || source.id) };
    });
    const mismatches = rows.filter(r => r.actual !== r.expected);
    const controls = rows.filter(r => r.expected === 'unavailable');
    const substantive = rows.filter(r => r.expected !== 'unavailable');
    const providerFailed = report.circuitStopped === true || report.diagnostics.some(d =>
      d.status === null || d.status < 200 || d.status >= 300 || d.failure !== null);
    const speech = reviewSpeech(manifest, options.speechReview);
    const controlUnexpectedApprovals = controls.filter(r => r.actual === 'allow').length;
    const blockers = ['draft_policy'];
    if (mismatches.length) blockers.push('classification_mismatch');
    if (providerFailed) blockers.push('provider_failure');
    if (controlUnexpectedApprovals) blockers.push('control_approved');
    if (speech.pending) blockers.push('human_listening_pending');
    if (speech.mismatches) blockers.push('human_listening_mismatch');
    return { ...base, validEvidence: true, mode: 'historical_media_policy_review',
      recordedCases: rows.length, substantiveCases: substantive.length,
      substantiveMatches: substantive.filter(r => r.actual === r.expected).length,
      falseAllows: rows.filter(r => r.expected === 'block' && r.actual === 'allow').length,
      falseBlocks: rows.filter(r => r.expected === 'allow' && r.actual === 'block').length,
      controlUnexpectedApprovals, uniqueMismatchTexts: new Set(mismatches.map(r => r.textSha256)).size,
      automaticClassificationPassed: !providerFailed && !mismatches.length, mismatches, speech, blockers };
  } catch { return { ...base, validEvidence: false, reason: 'invalid_policy_evidence' }; }
}
