import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const workflowUrl = new URL(
  "../../.github/workflows/supabase-production.yml",
  import.meta.url,
);

async function loadWorkflow() {
  return readFile(workflowUrl, "utf8");
}

test("Supabase production release is manual, serialized, and approval-gated", async () => {
  const source = await loadWorkflow();

  assert.match(source, /^on:\r?\n\s+workflow_dispatch:/m);
  assert.doesNotMatch(source, /^\s+(?:push|pull_request|schedule):/m);
  assert.match(source, /environment: supabase-production/);
  assert.match(source, /group: supabase-production/);
  assert.match(source, /cancel-in-progress: false/);
  assert.match(source, /permissions:\r?\n\s+contents: read/);
});

test("Supabase production release verifies the exact main commit and project", async () => {
  const source = await loadWorkflow();

  assert.match(source, /GITHUB_REF.*refs\/heads\/main/);
  assert.match(source, /CONFIRMED_COMMIT_SHA.*GITHUB_SHA/);
  assert.match(source, /CONFIRMED_PROJECT_REF.*SUPABASE_PROJECT_ID/);
  assert.match(source, /secrets\.SUPABASE_ACCESS_TOKEN/);
  assert.match(source, /secrets\.SUPABASE_DB_PASSWORD/);
  assert.match(source, /vars\.SUPABASE_PROJECT_ID/);
});

test("Supabase production release revalidates database and Edge contracts", async () => {
  const source = await loadWorkflow();

  assert.match(source, /verify_supabase_runtime_environment\.mjs/);
  assert.match(source, /test_supabase_functions\.mjs/);
  assert.match(source, /deno check/);
  assert.match(source, /supabase db start/);
  assert.match(source, /supabase test db/);
  assert.match(source, /supabase db lint --local --level error/);
});

test("Supabase production release uses forward-only deployment commands", async () => {
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

test("Supabase production workflow pins every external action to a commit", async () => {
  const source = await loadWorkflow();
  const uses = [...source.matchAll(/uses:\s*([^\s#]+)/g)].map(
    (match) => match[1],
  );

  assert.ok(uses.length > 0);
  for (const action of uses) {
    assert.match(action, /@[0-9a-f]{40}$/, action);
  }
});
