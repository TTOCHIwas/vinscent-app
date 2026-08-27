import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const mobileScriptUrl = new URL(
  '../../scripts/verify_mobile_local.ps1',
  import.meta.url,
);
const databaseScriptUrl = new URL(
  '../../scripts/verify_database_local.ps1',
  import.meta.url,
);
const iosScriptUrl = new URL(
  '../../scripts/verify_ios_local.sh',
  import.meta.url,
);
const mobileEnvExampleUrl = new URL(
  '../../apps/mobile/.env.example',
  import.meta.url,
);

async function load(url) {
  return (await readFile(url, 'utf8')).replaceAll('\r\n', '\n');
}

test('Windows local mobile gate runs every expensive Android check', async () => {
  const source = await load(mobileScriptUrl);

  assert.match(source, /flutterw\.cmd/);
  assert.match(
    source,
    /dart\.bat[\s\S]*format[\s\S]*--set-exit-if-changed/,
  );
  assert.match(source, /flutterw\.cmd[\s\S]*analyze[\s\S]*--no-pub/);
  assert.match(source, /flutterw\.cmd[\s\S]*test[\s\S]*--no-pub/);
  assert.match(source, /gradlew\.bat[\s\S]*:app:testDebugUnitTest/);
  assert.match(
    source,
    /integration_test\/app_startup_test\.dart[\s\S]*--no-pub/,
  );
  assert.match(source, /flutterw\.cmd[\s\S]*build[\s\S]*apk[\s\S]*--debug/);
  assert.match(source, /--dart-define-from-file=\.env/);
  assert.match(source, /verify_flutter_cache\.ps1/);
  assert.match(source, /DeviceId/);
});

test('Windows local database gate preserves an already running stack', async () => {
  const source = await load(databaseScriptUrl);

  assert.match(source, /supabase@2\.109\.1/);
  assert.match(source, /status[\s\S]*--output[\s\S]*json/);
  assert.match(source, /db[\s\S]*start/);
  assert.match(source, /test[\s\S]*db/);
  assert.match(source, /db[\s\S]*lint[\s\S]*--local[\s\S]*--level[\s\S]*error/);
  assert.match(source, /finally/);
  assert.match(source, /stop[\s\S]*--no-backup/);
  assert.match(source, /startedByScript/);
});

test('Mac local iOS gate runs Flutter checks and a simulator build', async () => {
  const source = await load(iosScriptUrl);

  assert.match(source, /^#!\/usr\/bin\/env bash$/m);
  assert.match(source, /uname -s[\s\S]*Darwin/);
  assert.match(source, /dart format[\s\S]*--set-exit-if-changed/);
  assert.match(source, /flutter analyze --no-pub/);
  assert.match(source, /flutter test --no-pub/);
  assert.match(
    source,
    /flutter build ios --simulator --debug --no-codesign --no-pub/,
  );
});

test('mobile environment template covers every compile-time setting', async () => {
  const source = await load(mobileEnvExampleUrl);

  assert.equal(
    source,
    [
      'SUPABASE_URL=',
      'SUPABASE_ANON_KEY=',
      'KAKAO_NATIVE_APP_KEY=',
      'POLICY_BASE_URL=',
      '',
    ].join('\n'),
  );
});
