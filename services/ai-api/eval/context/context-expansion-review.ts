import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { contentSafetyContextCases } from '../fixtures/content-safety-context-ko.ts';
import { contentSafetyKoreanCases } from '../fixtures/content-safety-ko.ts';

type Decision = 'allow' | 'block' | 'unavailable';
type Sample = { id: string; group: string; text: string; proposedDecision: 'allow' | 'block' | null; rationale: string };
type Pack = { schemaVersion: 1; syntheticOnly: true; policyVersion: string; policyText: string; labelStatus: 'draft'; authorship: string; cases: Sample[] };
type ReviewRow = { id: string; textSha256: string; decision: Decision | null; reviewerId: string | null; reviewedAt: string | null };
const groups = ['direct_threat', 'coercion', 'mixed_context', 'benign_boundary', 'report_and_quotation', 'unresolved_context', 'instruction_resistance'];
const base = { schemaVersion: 1, mode: 'offline_context_expansion_review', networkRequests: 0,
  ready: false, productionPublicationAuthorized: false, paidEvaluationAuthorized: false,
  independentlyValidated: false, newModelQualityEvaluated: false } as const;
const record = (value: unknown): value is Record<string, unknown> => value !== null && typeof value === 'object' && !Array.isArray(value);
const hash = (value: unknown) => createHash('sha256').update(JSON.stringify(value)).digest('hex');
const normalized = (value: string) => value.replace(/[\p{White_Space}\p{P}\p{Z}]/gu, '').normalize('NFC');
const idValid = (value: unknown): value is string => typeof value === 'string' && /^[a-z0-9-]{1,80}$/.test(value);

function parsePack(value: unknown): Pack {
  if (!record(value) || Object.keys(value).length !== 7 || value.schemaVersion !== 1 || value.syntheticOnly !== true
    || value.policyVersion !== 'ko-context-proposal-v2' || value.labelStatus !== 'draft'
    || value.authorship !== 'agent_authored_not_independently_reviewed'
    || typeof value.policyText !== 'string' || !value.policyText.trim() || value.policyText.length > 5000 || !Array.isArray(value.cases)
    || value.cases.length !== 28) throw new Error();
  const samples = value.cases;
  const media = JSON.parse(readFileSync(new URL('../fixtures/content-safety-media-ko.json', import.meta.url), 'utf8'));
  const prior = new Set([...contentSafetyContextCases, ...contentSafetyKoreanCases, ...media.cases]
    .map(c => normalized(c.text ?? c.referenceText)).filter(Boolean));
  const ids = new Set<string>(); const texts = new Set<string>();
  for (const c of samples) {
    if (!record(c) || Object.keys(c).length !== 5 || !idValid(c.id) || ids.has(c.id)
      || typeof c.group !== 'string' || !groups.includes(c.group)
      || typeof c.text !== 'string' || !c.text.trim() || Buffer.byteLength(c.text, 'utf8') > 1200
      || typeof c.rationale !== 'string' || !c.rationale.trim() || c.rationale.length > 500
      || (c.group === 'unresolved_context' ? c.proposedDecision !== null : !['allow', 'block'].includes(c.proposedDecision as string))) throw new Error();
    const text = normalized(c.text);
    if (!text || prior.has(text) || texts.has(text)) throw new Error();
    ids.add(c.id); texts.add(text);
  }
  if (groups.some(group => samples.filter(c => c.group === group).length !== 4)) throw new Error();
  return value as unknown as Pack;
}

function template(pack: Pack) {
  return { schemaVersion: 1, policyVersion: pack.policyVersion, packSha256: hash(pack), reviewMethod: 'human_label_review',
    reviews: pack.cases.map(c => ({ id: c.id, textSha256: hash(c.text), decision: null, reviewerId: null, reviewedAt: null } as ReviewRow)) };
}

export function createContextExpansionReviewTemplate(value: unknown) {
  return template(parsePack(value));
}

export function reviewContextExpansion(value: unknown, evidence?: unknown) {
  try {
    const pack = parsePack(value); const expected = template(pack); const input = evidence === undefined ? expected : evidence;
    if (!record(input) || Object.keys(input).length !== 5 || input.schemaVersion !== 1
      || input.policyVersion !== pack.policyVersion || input.packSha256 !== expected.packSha256
      || input.reviewMethod !== 'human_label_review' || !Array.isArray(input.reviews) || input.reviews.length > 28) throw new Error();
    const reviews = new Map<string, ReviewRow>();
    for (const row of input.reviews) {
      if (!record(row) || Object.keys(row).length !== 5 || !idValid(row.id) || reviews.has(row.id)
        || row.textSha256 !== expected.reviews.find(c => c.id === row.id)?.textSha256
        || !expected.reviews.some(c => c.id === row.id)) throw new Error();
      const empty = row.decision === null && row.reviewerId === null && row.reviewedAt === null;
      if (!empty && (typeof row.decision !== 'string' || !['allow', 'block', 'unavailable'].includes(row.decision)
        || typeof row.reviewerId !== 'string' || !/^[a-z0-9_-]{1,40}$/i.test(row.reviewerId)
        || typeof row.reviewedAt !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(row.reviewedAt)
        || !Number.isFinite(Date.parse(row.reviewedAt)) || Date.parse(row.reviewedAt) > Date.now()
        || new Date(row.reviewedAt).toISOString() !== row.reviewedAt)) throw new Error();
      reviews.set(row.id, row as unknown as ReviewRow);
    }
    const rows = pack.cases.map(c => {
      const review = reviews.get(c.id);
      return { id: c.id, textSha256: hash(c.text), group: c.group, proposedDecision: c.proposedDecision,
        reviewedDecision: review?.decision ?? null, status: review?.decision == null ? 'pending' : 'reviewed' };
    });
    const completed = rows.filter(r => r.status === 'reviewed');
    return { ...base, validEvidence: true, policyVersion: pack.policyVersion, policyStatus: 'proposal',
      packSha256: expected.packSha256, totalCases: rows.length, priorNormalizedOverlaps: 0,
      completedReviews: completed.length, pendingReviews: rows.length - completed.length, labelReviewComplete: completed.length === rows.length,
      proposalDisagreements: completed.filter(r => r.proposedDecision !== null && r.proposedDecision !== r.reviewedDecision).length,
      unresolvedPolicyCases: rows.filter(r => r.proposedDecision === null).length,
      evidenceKind: 'human_self_report_not_independence_verification', results: rows };
  } catch { return { ...base, validEvidence: false, reason: 'invalid_context_expansion_evidence' }; }
}
