import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const workflowUrl = new URL(
  '../../.github/workflows/supabase-production.yml',
  import.meta.url,
);

async function loadWorkflow() {
  return readFile(workflowUrl, 'utf8');
}

test('Supabase production release is manual, serialized, and approval-gated', async () => {
  const source = await loadWorkflow();

  assert.match(source, /^on:\r?\n\s+workflow_dispatch:/m);
  assert.doesNotMatch(source, /^\s+(?:push|pull_request|schedule):/m);
  assert.match(source, /environment: supabase-production/);
  assert.match(source, /group: supabase-production/);
  assert.match(source, /cancel-in-progress: false/);
  assert.match(source, /permissions:\r?\n\s+contents: read/);
});

test('Supabase production release verifies the exact main commit and project', async () => {
  const source = await loadWorkflow();

  assert.match(source, /GITHUB_REF.*refs\/heads\/main/);
  assert.match(source, /CONFIRMED_COMMIT_SHA.*GITHUB_SHA/);
  assert.match(source, /CONFIRMED_PROJECT_REF.*SUPABASE_PROJECT_ID/);
  assert.match(source, /secrets\.SUPABASE_ACCESS_TOKEN/);
  assert.match(source, /secrets\.SUPABASE_DB_PASSWORD/);
  assert.match(source, /vars\.SUPABASE_PROJECT_ID/);
});

test('Supabase deployment remains bound to the triggering source commit', async () => {
  const source = await loadWorkflow();
  const verifierCommand =
    'run: scripts/verify_release_source.sh "$GITHUB_SHA"';
  const verifierMatches = source
    .split(/\r?\n/)
    .filter((line) => line.trim() === verifierCommand);

  assert.equal(verifierMatches.length, 2);

  const deployJobIndex = source.indexOf('  deploy:');
  const deploymentSourceIndex = source.indexOf(
    '- name: Verify deployment release source',
    deployJobIndex,
  );
  const migrationPreviewIndex = source.indexOf(
    '- name: Preview pending migrations',
    deployJobIndex,
  );
  const evidenceIndex = source.indexOf(
    '- name: Capture release evidence',
    deployJobIndex,
  );
  const finalSourceIndex = source.indexOf(
    '- name: Verify final release source',
    deployJobIndex,
  );
  const uploadIndex = source.indexOf(
    '- name: Upload release evidence',
    deployJobIndex,
  );

  assert.ok(deploymentSourceIndex > deployJobIndex);
  assert.ok(migrationPreviewIndex > deploymentSourceIndex);
  assert.ok(finalSourceIndex > evidenceIndex);
  assert.ok(uploadIndex > finalSourceIndex);
});

test('Supabase production release leaves expensive validation to local gates', async () => {
  const source = await loadWorkflow();

  assert.match(source, /verify_supabase_runtime_environment\.mjs/);
  assert.doesNotMatch(source, /^  preflight:/m);
  assert.doesNotMatch(source, /needs: preflight/);
  assert.doesNotMatch(source, /test_supabase_functions\.mjs/);
  assert.doesNotMatch(source, /deno check/);
  assert.doesNotMatch(source, /supabase db start/);
  assert.doesNotMatch(source, /supabase test db/);
  assert.doesNotMatch(source, /supabase db lint --local --level error/);
  assert.doesNotMatch(source, /supabase stop --no-backup/);
});

test('Supabase production release uses forward-only deployment commands', async () => {
  const source = await loadWorkflow();

  assert.match(source, /supabase db push --linked --dry-run/);
  assert.match(source, /supabase db push --linked --yes/);
  assert.match(
    source,
    /supabase functions deploy[\s\S]*--project-ref "\$SUPABASE_PROJECT_ID"[\s\S]*--use-api/,
  );
  assert.doesNotMatch(source, /supabase db reset/);
  assert.doesNotMatch(source, /--include-all/);
  assert.doesNotMatch(source, /--prune/);
  assert.doesNotMatch(source, /supabase secrets (?:set|unset)/);
});

test('Supabase production release restores client JWT verification', async () => {
  const source = await loadWorkflow();
  const deployIndex = source.indexOf(
    '- name: Deploy all tracked Edge functions',
  );
  const jwtRepairIndex = source.indexOf(
    '- name: Enforce client JWT verification',
  );
  const evidenceIndex = source.indexOf('- name: Capture release evidence');
  const jwtRepairStep = source.slice(jwtRepairIndex, evidenceIndex);

  assert.ok(jwtRepairIndex > deployIndex);
  assert.ok(evidenceIndex > jwtRepairIndex);
  assert.match(jwtRepairStep, /--request PATCH/);
  assert.match(
    jwtRepairStep,
    /projects\/\$SUPABASE_PROJECT_ID\/functions\/generate-ai-proactive-suggestion/,
  );
  assert.match(
    jwtRepairStep,
    /Authorization: Bearer \$SUPABASE_ACCESS_TOKEN/,
  );
  assert.match(jwtRepairStep, /\{"verify_jwt":true\}/);
});

test('Supabase production release verifies Edge secrets before deployment', async () => {
  const source = await loadWorkflow();
  const secretCheckIndex = source.indexOf(
    'verify_supabase_secret_inventory.mjs',
  );
  const migrationPreviewIndex = source.indexOf(
    'supabase db push --linked --dry-run',
  );

  assert.match(source, /supabase secrets list/);
  assert.ok(secretCheckIndex >= 0);
  assert.ok(migrationPreviewIndex > secretCheckIndex);
});

test('Supabase production release rejects stale and missing remote functions', async () => {
  const source = await loadWorkflow();

  assert.match(
    source,
    /verify_supabase_function_inventory\.mjs[\s\S]*--allow-missing/,
  );
  assert.match(
    source,
    /verify_supabase_function_inventory\.mjs[\s\S]*functions\.json/,
  );
  assert.doesNotMatch(source, /--prune/);
});

test('Supabase production release verifies the final migration inventory', async () => {
  const source = await loadWorkflow();
  const migrationListIndex = source.indexOf('supabase migration list');
  const migrationVerifierIndex = source.indexOf(
    'verify_supabase_migration_inventory.mjs',
  );
  const uploadIndex = source.indexOf('- name: Upload release evidence');

  assert.ok(migrationListIndex >= 0);
  assert.match(
    source,
    /supabase migration list[\s\\]*--linked[\s\\]*--output-format json/,
  );
  assert.ok(migrationVerifierIndex > migrationListIndex);
  assert.ok(uploadIndex > migrationVerifierIndex);
  assert.match(source, /migrations\.json/);
});

test('Supabase production release rejects remote-only migrations before applying changes', async () => {
  const source = await loadWorkflow();
  const preflightIndex = source.indexOf(
    '- name: Reject untracked remote migrations',
  );
  const allowUnappliedIndex = source.indexOf(
    '--allow-unapplied',
    preflightIndex,
  );
  const migrationPreviewIndex = source.indexOf(
    '- name: Preview pending migrations',
  );

  assert.ok(preflightIndex >= 0);
  assert.ok(allowUnappliedIndex > preflightIndex);
  assert.ok(migrationPreviewIndex > allowUnappliedIndex);
  assert.match(
    source.slice(preflightIndex, migrationPreviewIndex),
    /supabase migration list[\s\\]*--linked[\s\\]*--output-format json/,
  );
});

test('Supabase production release verifies deployed Edge JWT modes', async () => {
  const source = await loadWorkflow();

  assert.match(
    source,
    /verify_supabase_function_inventory\.mjs[\s\S]*functions\.json/,
  );
  assert.match(source, /Capture release evidence/);
});

test('Supabase production workflow pins every external action to a commit', async () => {
  const source = await loadWorkflow();
  const uses = [...source.matchAll(/uses:\s*([^\s#]+)/g)].map(
    (match) => match[1],
  );

  assert.ok(uses.length > 0);
  for (const action of uses) {
    assert.match(action, /@[0-9a-f]{40}$/, action);
  }
});
