import assert from 'node:assert/strict';
import test from 'node:test';
import {
  inspectTrackedText,
  shouldInspectTrackedText,
  trackedPathIssue,
} from '../../scripts/lib/tracked-secret-guard.mjs';

test('rejects tracked runtime environment and credential files', () => {
  assert.equal(trackedPathIssue('apps/mobile/.env'), 'environment_file');
  assert.equal(
    trackedPathIssue('supabase/.temp/remote-catalog.json'),
    'supabase_temp_cache',
  );
  assert.equal(
    trackedPathIssue('credentials/AuthKey_TEST.p8'),
    'credential_file',
  );
  assert.equal(
    trackedPathIssue('apps/mobile/android/key.properties'),
    'credential_file',
  );
});

test('allows documented environment templates and ordinary source files', () => {
  assert.equal(trackedPathIssue('apps/mobile/.env.example'), null);
  assert.equal(trackedPathIssue('docs/release/configuration.md'), null);
  assert.equal(shouldInspectTrackedText('lib/example.dart'), true);
  assert.equal(shouldInspectTrackedText('assets/image.png'), false);
});

test('detects high-confidence secrets without returning their values', () => {
  const privateKey = [
    ['-----BEGIN ', 'PRIVATE KEY-----'].join(''),
    'A'.repeat(128),
    ['-----END ', 'PRIVATE KEY-----'].join(''),
  ].join('\n');
  const googleKey = ['AIza', 'A'.repeat(35)].join('');
  const issues = inspectTrackedText(
    'config.txt',
    `${privateKey}\n${googleKey}`,
  );

  assert.deepEqual(
    issues.map(({ code, line }) => ({ code, line })),
    [
      { code: 'private_key', line: 1 },
      { code: 'google_api_key', line: 4 },
    ],
  );
  assert.equal(JSON.stringify(issues).includes(googleKey), false);
});

test('allows key format examples and Firebase client configuration keys', () => {
  const keyExample = [
    ['-----BEGIN ', 'PRIVATE KEY-----'].join(''),
    '<private-key>',
    ['-----END ', 'PRIVATE KEY-----'].join(''),
  ].join('\n');
  const googleKey = ['AIza', 'A'.repeat(35)].join('');

  assert.deepEqual(inspectTrackedText('docs/example.md', keyExample), []);
  assert.deepEqual(
    inspectTrackedText(
      'apps/mobile/android/app/google-services.json',
      googleKey,
    ),
    [],
  );
  assert.deepEqual(inspectTrackedText('server/config.json', googleKey), [
    {
      filePath: 'server/config.json',
      code: 'google_api_key',
      line: 1,
    },
  ]);
});

test('detects only service-role Supabase JWT payloads', () => {
  const serviceRoleToken = jwtWithRole('service_role');
  const anonToken = jwtWithRole('anon');

  assert.deepEqual(
    inspectTrackedText('service.txt', serviceRoleToken).map(
      ({ code }) => code,
    ),
    ['supabase_service_role_jwt'],
  );
  assert.deepEqual(inspectTrackedText('client.txt', anonToken), []);
});

test('detects provider credentials with stable public prefixes', () => {
  const cases = [
    [['ghp_', 'A'.repeat(36)].join(''), 'github_token'],
    [['github_pat_', 'A'.repeat(20)].join(''), 'github_token'],
    [['sb_secret_', 'A'.repeat(20)].join(''), 'supabase_secret_key'],
    [['AKIA', 'A'.repeat(16)].join(''), 'aws_access_key'],
  ];

  for (const [secret, expectedCode] of cases) {
    const issues = inspectTrackedText('config.txt', secret);
    assert.deepEqual(issues.map(({ code }) => code), [expectedCode]);
    assert.equal(JSON.stringify(issues).includes(secret), false);
  }
});

function jwtWithRole(role) {
  const encode = (value) =>
    Buffer.from(JSON.stringify(value)).toString('base64url');
  return [
    encode({ alg: 'HS256', typ: 'JWT' }),
    encode({ role, padding: 'x'.repeat(24) }),
    'signature'.repeat(4),
  ].join('.');
}
