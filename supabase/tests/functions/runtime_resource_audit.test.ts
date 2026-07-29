import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import test from 'node:test';

const supabaseRoot = new URL('../../', import.meta.url);
const functionsRoot = new URL('functions/', supabaseRoot);
const auditSqlUrl = new URL(
  'snippets/audit_edge_runtime_resources.sql',
  supabaseRoot,
);

test('remote resource audit covers every custom-secret Edge Function', async () => {
  const auditSql = await readFile(auditSqlUrl, 'utf8');
  const directories = await readdir(functionsRoot, { withFileTypes: true });
  const auditedFunctions = [];

  for (const directory of directories) {
    if (!directory.isDirectory() || directory.name.startsWith('_')) {
      continue;
    }
    const indexUrl = new URL(`${directory.name}/index.ts`, functionsRoot);
    let source;
    try {
      source = await readFile(indexUrl, 'utf8');
    } catch (error) {
      if (error?.code === 'ENOENT') {
        continue;
      }
      throw error;
    }

    if (!source.includes('verifyWebhookSecret(request,')) {
      continue;
    }
    const headerName = source.match(
      /headerName:\s*'([^']+)'/,
    )?.[1];
    assert.ok(
      headerName,
      `${directory.name} must declare a literal primary header name`,
    );
    assert.match(auditSql, new RegExp(`'${directory.name}'`));
    assert.match(auditSql, new RegExp(`'${headerName}'`));
    auditedFunctions.push(directory.name);
  }

  assert.ok(auditedFunctions.length > 0);
});

test('remote resource audit never selects raw trigger or Cron definitions', async () => {
  const auditSql = await readFile(auditSqlUrl, 'utf8');

  assert.doesNotMatch(
    auditSql,
    /\bselect\s+[\s\S]*?\bactual\.definition\s+as\b/i,
  );
  assert.doesNotMatch(
    auditSql,
    /\bjobs\.command\s+as\b/i,
  );
});
