import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const workflowUrl = new URL('../../.github/workflows/ci.yml', import.meta.url);
const filtersUrl = new URL('../../.github/ci-paths.yml', import.meta.url);

async function load(url) {
  return (await readFile(url, 'utf8')).replaceAll('\r\n', '\n');
}

function job(source, jobId) {
  const startMarker = `  ${jobId}:\n`;
  const start = source.indexOf(startMarker);

  assert.ok(start >= 0, `missing ${jobId} job`);

  const remainder = source.slice(start + startMarker.length);
  const nextJob = remainder.search(/^  [a-z0-9-]+:\n/m);
  return source.slice(
    start,
    nextJob < 0 ? source.length : start + startMarker.length + nextJob,
  );
}

function filter(source, filterId) {
  const startMarker = `${filterId}:\n`;
  const start = source.indexOf(startMarker);

  assert.ok(start >= 0, `missing ${filterId} filter`);

  const remainder = source.slice(start + startMarker.length);
  const nextFilter = remainder.search(/^[a-z][a-z0-9_]*:\n/m);
  return source.slice(
    start,
    nextFilter < 0 ? source.length : start + startMarker.length + nextFilter,
  );
}

test('CI detects component changes with a commit-pinned action', async () => {
  const source = await load(workflowUrl);
  const changes = job(source, 'changes');

  assert.match(changes, /name: Change detection/);
  assert.match(changes, /pull-requests: read/);
  assert.match(
    changes,
    /dorny\/paths-filter@[0-9a-f]{40}[^\n]*# v4\.0\.3/,
  );
  assert.match(changes, /filters: \.github\/ci-paths\.yml/);
  assert.match(changes, /node scripts\/verify_tracked_secrets\.mjs/);

  for (const output of [
    'ci_config',
    'mobile',
    'android_integration',
    'ios',
    'release_contracts',
    'ai',
    'policy',
    'edge',
    'database',
  ]) {
    assert.match(changes, new RegExp(`^      ${output}:`, 'm'));
  }
});

test('CI gates expensive jobs by component while manual runs stay complete', async () => {
  const source = await load(workflowUrl);
  const expectedScopes = new Map([
    ['mobile', 'mobile'],
    ['android-integration', 'android_integration'],
    ['ios-build', 'ios'],
    ['node-services', 'release_contracts'],
    ['edge-functions', 'edge'],
    ['database', 'database'],
  ]);

  assert.doesNotMatch(source, /^\s+paths(?:-ignore)?:/m);

  for (const [jobId, scope] of expectedScopes) {
    const block = job(source, jobId);
    assert.match(block, /^    needs: changes$/m, jobId);
    assert.match(block, /github\.event_name == 'workflow_dispatch'/, jobId);
    assert.match(
      block,
      new RegExp(`needs\\.changes\\.outputs\\.${scope} == 'true'`),
      jobId,
    );
    assert.match(
      block,
      /needs\.changes\.outputs\.ci_config == 'true'/,
      jobId,
    );
  }

  assert.match(
    job(source, 'ios-build'),
    /github\.event_name == 'push'.*github\.event_name == 'workflow_dispatch'/s,
  );
});

test('Node services run only the changed service contracts', async () => {
  const source = await load(workflowUrl);
  const nodeServices = job(source, 'node-services');

  assert.match(
    nodeServices,
    /needs\.changes\.outputs\.ai == 'true'/,
  );
  assert.match(
    nodeServices,
    /needs\.changes\.outputs\.policy == 'true'/,
  );
  assert.match(
    nodeServices,
    /name: Test repository release contracts\n\s+if:.*release_contracts/,
  );
  assert.match(
    nodeServices,
    /name: Test AI service\n\s+if:.*outputs\.ai/,
  );
  assert.match(
    nodeServices,
    /name: Install policy web dependencies\n\s+if:.*outputs\.policy/,
  );
  assert.doesNotMatch(nodeServices, /Reject tracked release secrets/);
});

test('CI path filters preserve cross-component dependencies', async () => {
  const source = await load(filtersUrl);

  assert.match(filter(source, 'ci_config'), /\.github\/workflows\/ci\.yml/);
  assert.match(filter(source, 'ci_config'), /\.github\/ci-paths\.yml/);
  assert.match(filter(source, 'mobile'), /apps\/mobile\/\*\*/);
  assert.match(
    filter(source, 'android_integration'),
    /apps\/mobile\/integration_test\/\*\*/,
  );
  assert.match(filter(source, 'ios'), /apps\/mobile\/ios\/\*\*/);
  assert.match(filter(source, 'ai'), /services\/ai-api\/\*\*/);
  assert.match(filter(source, 'policy'), /apps\/policy-web\/\*\*/);

  const edge = filter(source, 'edge');
  assert.match(edge, /supabase\/functions\/\*\*/);
  assert.match(edge, /supabase\/tests\/functions\/\*\*/);
  assert.match(edge, /services\/ai-api\/src\/\*\*/);

  const database = filter(source, 'database');
  assert.match(database, /supabase\/migrations\/\*\*/);
  assert.match(database, /supabase\/tests\/database\/\*\*/);
});

test('CI pins every external action to a commit', async () => {
  const source = await load(workflowUrl);
  const uses = [...source.matchAll(/uses:\s*([^\s#]+)/g)].map(
    (match) => match[1],
  );

  assert.ok(uses.length > 0);
  for (const action of uses) {
    assert.match(action, /@[0-9a-f]{40}$/, action);
  }
});
