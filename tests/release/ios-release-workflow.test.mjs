import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const workflowUrl = new URL(
  '../../.github/workflows/ios-release.yml',
  import.meta.url,
);
const signingInstallerUrl = new URL(
  '../../scripts/install_ios_signing_assets.sh',
  import.meta.url,
);
const signingCleanupUrl = new URL(
  '../../scripts/cleanup_ios_signing_assets.sh',
  import.meta.url,
);
const releaseBuilderUrl = new URL(
  '../../scripts/build_ios_release_candidate.sh',
  import.meta.url,
);
const xcodeProjectUrl = new URL(
  '../../apps/mobile/ios/Runner.xcodeproj/project.pbxproj',
  import.meta.url,
);

async function load(url) {
  return readFile(url, 'utf8');
}

test('iOS release is manual, serialized, and approval-gated', async () => {
  const source = await load(workflowUrl);

  assert.match(source, /^on:\r?\n\s+workflow_dispatch:/m);
  assert.doesNotMatch(source, /^\s+(?:push|pull_request|schedule):/m);
  assert.match(source, /environment: ios-release/);
  assert.match(source, /group: ios-release/);
  assert.match(source, /cancel-in-progress: false/);
  assert.match(source, /permissions:\r?\n\s+contents: read/);
});

test('iOS release verifies the exact main commit and required inputs', async () => {
  const source = await load(workflowUrl);

  assert.match(source, /GITHUB_REF.*refs\/heads\/main/);
  assert.match(source, /CONFIRMED_COMMIT_SHA.*GITHUB_SHA/);
  assert.match(source, /inputs\.build_number/);
  assert.match(source, /vars\.DANJJAN_APPLE_TEAM_ID/);
  assert.match(source, /secrets\.DANJJAN_IOS_DISTRIBUTION_CERTIFICATE_BASE64/);
  assert.match(source, /secrets\.DANJJAN_IOS_RUNNER_PROFILE_BASE64/);
  assert.match(source, /secrets\.DANJJAN_IOS_WIDGET_PROFILE_BASE64/);
});

test('iOS release restores signing before the verified release build', async () => {
  const source = await load(workflowUrl);
  const preflightIndex = source.indexOf('scripts/check_ios_release_mac.sh');
  const installIndex = source.indexOf('scripts/install_ios_signing_assets.sh');
  const buildIndex = source.indexOf('scripts/build_ios_release_candidate.sh');
  const artifactIndex = source.indexOf('actions/upload-artifact@');

  assert.ok(preflightIndex >= 0);
  assert.ok(installIndex > preflightIndex);
  assert.ok(installIndex >= 0);
  assert.ok(buildIndex > installIndex);
  assert.ok(artifactIndex > buildIndex);
  assert.match(source, /retention-days: 90/);
});

test('iOS release isolates the Pub cache before the first dependency resolution', async () => {
  const source = await load(workflowUrl);
  const pubCacheIndex = source.indexOf(
    'PUB_CACHE: ${{ runner.temp }}/danjjan-pub-cache',
  );
  const dependencyResolutionIndex = source.indexOf('run: flutter pub get');

  assert.ok(pubCacheIndex >= 0);
  assert.ok(dependencyResolutionIndex > pubCacheIndex);
});

test('iOS release validates and uploads only when TestFlight is selected', async () => {
  const source = await load(workflowUrl);

  assert.match(source, /inputs\.publish_testflight/);
  assert.match(source, /secrets\.DANJJAN_ASC_API_PRIVATE_KEY_BASE64/);
  assert.match(source, /vars\.DANJJAN_ASC_API_KEY_ID/);
  assert.match(source, /vars\.DANJJAN_ASC_API_ISSUER_ID/);
  assert.match(source, /xcrun altool --validate-app/);
  assert.match(source, /xcrun altool --upload-app/);
  assert.match(source, /--apiKey/);
  assert.match(source, /--apiIssuer/);
});

test('iOS release always removes restored credentials', async () => {
  const source = await load(workflowUrl);
  const cleanupIndex = source.indexOf('scripts/cleanup_ios_signing_assets.sh');

  assert.ok(cleanupIndex >= 0);
  assert.match(source.slice(cleanupIndex - 100, cleanupIndex), /if: always\(\)/);
});

test('iOS workflow pins every external action to a commit', async () => {
  const source = await load(workflowUrl);
  const uses = [...source.matchAll(/uses:\s*([^\s#]+)/g)].map(
    (match) => match[1],
  );

  assert.ok(uses.length > 0);
  for (const action of uses) {
    assert.match(action, /@[0-9a-f]{40}$/, action);
  }
});

test('signing installer validates both target profiles and isolates the keychain', async () => {
  const source = await load(signingInstallerUrl);

  assert.match(source, /security create-keychain/);
  assert.match(source, /security import/);
  assert.match(source, /security set-key-partition-list/);
  assert.match(source, /security cms -D -i/);
  assert.match(source, /com\.vinscent\.vinscent/);
  assert.match(source, /com\.vinscent\.vinscent\.widgets/);
  assert.match(source, /group\.com\.vinscent\.vinscent/);
  assert.match(source, /FLUTTER_XCODE_DANJJAN_RUNNER_PROFILE_SPECIFIER/);
  assert.match(source, /FLUTTER_XCODE_DANJJAN_WIDGET_PROFILE_SPECIFIER/);
});

test('signing cleanup removes the temporary keychain and profiles', async () => {
  const source = await load(signingCleanupUrl);

  assert.match(source, /security delete-keychain/);
  assert.match(source, /DANJJAN_IOS_RUNNER_PROFILE_PATH/);
  assert.match(source, /DANJJAN_IOS_WIDGET_PROFILE_PATH/);
});

test('release builder supports explicit manual export options', async () => {
  const source = await load(releaseBuilderUrl);

  assert.match(source, /DANJJAN_IOS_EXPORT_OPTIONS_PLIST/);
  assert.match(source, /--export-options-plist/);
});

test('iOS release builds the signed artifact without repeating local validation', async () => {
  const source = await load(releaseBuilderUrl);

  assert.doesNotMatch(source, /"\$dart_binary"\s+format/);
  assert.doesNotMatch(source, /"\$flutter_binary"\s+analyze/);
  assert.doesNotMatch(source, /"\$flutter_binary"\s+test/);
  assert.match(source, /"\$flutter_binary"\s+build\s+"\$\{build_arguments\[@\]\}"/);
  assert.match(source, /codesign --verify --deep --strict/);
});

test('Runner and widget use separate release profile specifiers', async () => {
  const source = await load(xcodeProjectUrl);

  assert.match(
    source,
    /PROVISIONING_PROFILE_SPECIFIER = "\$\(DANJJAN_RUNNER_PROFILE_SPECIFIER\)";/,
  );
  assert.match(
    source,
    /PROVISIONING_PROFILE_SPECIFIER = "\$\(DANJJAN_WIDGET_PROFILE_SPECIFIER\)";/,
  );
});
