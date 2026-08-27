import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { matchesGlob } from 'node:path';
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

function parseFilters(source) {
  const filters = new Map();
  let currentFilter;

  for (const line of source.split('\n')) {
    if (line.length === 0) {
      continue;
    }

    const header = /^([a-z][a-z0-9_]*):$/.exec(line);
    if (header) {
      currentFilter = header[1];
      filters.set(currentFilter, []);
      continue;
    }

    const rule = /^  - '([^']+)'$/.exec(line);
    assert.ok(rule && currentFilter, `unsupported filter line: ${line}`);
    filters.get(currentFilter).push(rule[1]);
  }

  return filters;
}

function matchingFilters(filters, path) {
  return [...filters]
    .filter(([, rules]) => rules.some((rule) => matchesGlob(path, rule)))
    .map(([name]) => name)
    .sort();
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
    'release_contracts',
    'ai',
    'policy',
    'edge',
  ]) {
    assert.match(changes, new RegExp(`^      ${output}:`, 'm'));
  }

  for (const removedOutput of [
    'android',
    'android_integration',
    'ios',
    'database',
  ]) {
    assert.doesNotMatch(
      changes,
      new RegExp(`^      ${removedOutput}:`, 'm'),
    );
  }
});

test('CI gates lightweight jobs by component', async () => {
  const source = await load(workflowUrl);
  const expectedScopes = new Map([
    ['mobile', 'mobile'],
    ['edge-functions', 'edge'],
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

});

test('CI runs expensive platform validation only by manual request', async () => {
  const source = await load(workflowUrl);

  for (const jobId of ['android-integration', 'ios-build', 'database']) {
    const block = job(source, jobId);
    assert.match(block, /^    needs: changes$/m, jobId);
    assert.match(
      block,
      /^    if: github\.event_name == 'workflow_dispatch'$/m,
      jobId,
    );
    assert.doesNotMatch(block, /needs\.changes\.outputs\./, jobId);
  }

  const mobile = job(source, 'mobile');
  assert.match(
    mobile,
    /uses: actions\/setup-java@[^\n]+\n\s+if: github\.event_name == 'workflow_dispatch'/,
  );
  assert.match(
    mobile,
    /name: Test Android native code\n\s+if: github\.event_name == 'workflow_dispatch'/,
  );
  assert.match(
    mobile,
    /name: Build Android debug APK\n\s+if: github\.event_name == 'workflow_dispatch'/,
  );
});

test('Node services propagates change detection failures', async () => {
  const source = await load(workflowUrl);
  const nodeServices = job(source, 'node-services');

  assert.match(nodeServices, /^    needs: changes$/m);
  assert.match(nodeServices, /^    if: always\(\)$/m);
  assert.match(
    nodeServices,
    /name: Require successful change detection\n\s+if: needs\.changes\.result != 'success'\n\s+run: exit 1/,
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
  const mobile = filter(source, 'mobile');
  assert.match(mobile, /apps\/mobile\/lib\/\*\*/);
  assert.match(mobile, /apps\/mobile\/test\/\*\*/);
  assert.match(mobile, /apps\/mobile\/tool\/\*\*/);
  assert.doesNotMatch(mobile, /'apps\/mobile\/\*\*'/);
  assert.doesNotMatch(
    source,
    /^(?:android|android_integration|ios|database):$/m,
  );
  assert.match(filter(source, 'ai'), /services\/ai-api\/\*\*/);
  assert.match(filter(source, 'policy'), /apps\/policy-web\/\*\*/);

  const edge = filter(source, 'edge');
  assert.match(edge, /supabase\/functions\/\*\*/);
  assert.match(edge, /supabase\/tests\/functions\/\*\*/);
  assert.match(edge, /services\/ai-api\/src\/\*\*/);
});

test('CI routes representative paths to the minimum required checks', async () => {
  const filters = parseFilters(await load(filtersUrl));
  const cases = new Map([
    ['services/ai-api/eval/question.ts', ['ai']],
    ['services/ai-api/src/domain/question.ts', ['ai', 'edge']],
    [
      'apps/mobile/ios/Runner/AppDelegate.swift',
      ['mobile', 'release_contracts'],
    ],
    ['apps/mobile/android/app/build.gradle.kts', ['mobile']],
    ['apps/mobile/lib/main.dart', ['mobile']],
    ['apps/mobile/test/widget_test.dart', ['mobile']],
    ['apps/mobile/tool/verify_store_assets.dart', ['mobile']],
    ['apps/mobile/README.md', []],
    ['apps/mobile/windows/runner/main.cpp', []],
    [
      '.github/workflows/android-release.yml',
      ['mobile', 'release_contracts'],
    ],
    [
      'scripts/check_ios_release_mac.sh',
      ['mobile', 'release_contracts'],
    ],
    ['store-assets/google-play/app-icon-512.png', ['mobile']],
    [
      'docs/release/store-listing-copy-ko.md',
      ['mobile', 'release_contracts'],
    ],
    [
      'supabase/migrations/20260101000000_example.sql',
      ['release_contracts'],
    ],
    ['supabase/functions/example/index.ts', ['edge', 'release_contracts']],
    ['docs/architecture.md', []],
  ]);

  for (const [path, expected] of cases) {
    assert.deepEqual(matchingFilters(filters, path), expected, path);
  }
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
