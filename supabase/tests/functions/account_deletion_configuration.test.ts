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
