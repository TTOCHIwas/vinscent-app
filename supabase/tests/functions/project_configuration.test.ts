import assert from 'node:assert/strict';
import { access, readFile, readdir } from 'node:fs/promises';
import test from 'node:test';

const supabaseRoot = new URL('../../', import.meta.url);
const configUrl = new URL('config.toml', supabaseRoot);

function sectionFor(config: string, sectionName: string) {
  const escapedName = sectionName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = config.match(
    new RegExp(
      `^\\[${escapedName}\\]\\r?\\n([\\s\\S]*?)(?=^\\[|\\Z)`,
      'm',
    ),
  );
  return match?.[1] ?? '';
}

test('local database reset does not reference a missing seed file', async () => {
  const config = await readFile(configUrl, 'utf8');
  const seedSection = sectionFor(config, 'db.seed');
  const isEnabled = /^\s*enabled\s*=\s*true\s*$/m.test(seedSection);

  if (!isEnabled) {
    return;
  }

  const sqlPaths = seedSection.match(
    /^\s*sql_paths\s*=\s*\[([^\]]*)\]\s*$/m,
  )?.[1] ?? '';
  const paths = [...sqlPaths.matchAll(/"([^"]+\.sql)"/g)].map(
    ([, path]) => path,
  );
  assert.ok(paths.length > 0, 'enabled database seeding needs a SQL path');

  await Promise.all(
    paths.map((path) =>
      access(new URL(path.replace(/^\.\//, ''), supabaseRoot)),
    ),
  );
});

test('custom-secret webhooks bypass platform JWT only after local verification', async () => {
  const config = await readFile(configUrl, 'utf8');
  const functionDirectories = await readdir(
    new URL('functions/', supabaseRoot),
    { withFileTypes: true },
  );
  const customSecretHandlers: Array<{
    functionName: string;
    handler: string;
  }> = [];

  for (const directory of functionDirectories) {
    if (!directory.isDirectory()) {
      continue;
    }
    const handlerUrl = new URL(
      `functions/${directory.name}/index.ts`,
      supabaseRoot,
    );
    try {
      await access(handlerUrl);
    } catch {
      continue;
    }
    const handler = await readFile(handlerUrl, 'utf8');
    if (handler.includes('verifyWebhookSecret(request,')) {
      customSecretHandlers.push({
        functionName: directory.name,
        handler,
      });
    }
  }

  assert.ok(customSecretHandlers.length > 0);

  for (const { functionName, handler } of customSecretHandlers) {
    const section = sectionFor(config, `functions.${functionName}`);
    assert.match(
      section,
      /^\s*verify_jwt\s*=\s*false\s*$/m,
      `${functionName} must disable platform JWT verification`,
    );
    assert.match(
      handler,
      /verifyWebhookSecret\(request,/,
      `${functionName} must verify its custom secret before processing`,
    );
    assert.match(handler, /return jsonResponse\(\{ error: 'unauthorized' \}, 401\)/);
  }
});

test('client-authenticated proactive suggestions keep platform JWT verification', async () => {
  const config = await readFile(configUrl, 'utf8');
  const section = sectionFor(
    config,
    'functions.generate-ai-proactive-suggestion',
  );

  assert.doesNotMatch(section, /^\s*verify_jwt\s*=\s*false\s*$/m);
});

test('migration directory contains only timestamped migrations', async () => {
  const entries = await readdir(new URL('migrations/', supabaseRoot));
  const invalidEntries = entries.filter(
    (entry) => !/^\d{14}_[a-z0-9_]+\.sql$/.test(entry),
  );
  const timestamps = entries.map((entry) => entry.slice(0, 14));
  const duplicateTimestamps = timestamps.filter(
    (timestamp, index) => timestamps.indexOf(timestamp) !== index,
  );

  assert.deepEqual(invalidEntries, []);
  assert.deepEqual([...new Set(duplicateTimestamps)], []);
});
