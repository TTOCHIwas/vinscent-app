import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const projectRoot = new URL('../../', import.meta.url);

test('declares manual authentication for the account deletion function', async () => {
  const [config, handler] = await Promise.all([
    readFile(new URL('config.toml', projectRoot), 'utf8'),
    readFile(
      new URL(
        'functions/delete-account/account_deletion_http_handler.ts',
        projectRoot,
      ),
      'utf8',
    ),
  ]);

  assert.match(
    config,
    /\[functions\.delete-account\]\s+verify_jwt\s*=\s*false/,
  );
  assert.match(handler, /bearerTokenFrom\(request\)/);
  assert.match(handler, /authenticator\.authenticate\(/);
  assert.match(handler, /return jsonResponse\(\{ error: 'unauthorized' \}, 401\)/);
});

test('keeps Apple revocation credentials optional for Android release', async () => {
  const manifest = JSON.parse(
    await readFile(
      new URL('../../runtime-environment.manifest.json', import.meta.url),
      'utf8',
    ),
  );
  const entries = new Map(
    manifest.entries.map((entry: { name: string }) => [entry.name, entry]),
  );

  for (const name of [
    'APPLE_SIGN_IN_CLIENT_ID',
    'APPLE_SIGN_IN_KEY_ID',
    'APPLE_SIGN_IN_PRIVATE_KEY',
    'APPLE_SIGN_IN_TEAM_ID',
  ]) {
    assert.equal(entries.get(name)?.availability, 'optional');
  }
});
