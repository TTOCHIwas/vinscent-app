import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const preflightUrl = new URL(
  '../../scripts/check_ios_release_mac.sh',
  import.meta.url,
);
const handoffUrl = new URL(
  '../../docs/release/ios-mac-handoff.md',
  import.meta.url,
);
const signingGuideUrl = new URL(
  '../../docs/release/mobile-signing-and-capabilities.md',
  import.meta.url,
);
const submissionChecklistUrl = new URL(
  '../../docs/release/store-submission-checklist.md',
  import.meta.url,
);

async function load(url) {
  return readFile(url, 'utf8');
}

test('Mac preflight validates the fixed iOS release toolchain', async () => {
  const source = await load(preflightUrl);

  assert.match(source, /uname -s/);
  assert.match(source, /xcodebuild -version/);
  assert.match(source, /xcrun --sdk iphoneos --show-sdk-version/);
  assert.match(source, /3\.41\.9/);
  assert.match(source, /pod --version/);
  assert.match(source, /Runner\.xcworkspace/);
  assert.match(source, /xcodebuild[^\n]+-list/);
});

test('Mac preflight checks both bundle and capability contracts', async () => {
  const source = await load(preflightUrl);

  assert.match(source, /com\.vinscent\.vinscent/);
  assert.match(source, /com\.vinscent\.vinscent\.widgets/);
  assert.match(source, /group\.com\.vinscent\.vinscent/);
  assert.match(source, /com\.apple\.developer\.applesignin/);
  assert.match(source, /aps-environment/);
  assert.match(source, /GoogleService-Info\.plist/);
});

test('Mac handoff separates secrets, variables, and Mac-only work', async () => {
  const source = await load(handoffUrl);

  assert.match(source, /DANJJAN_IOS_DISTRIBUTION_CERTIFICATE_BASE64/);
  assert.match(source, /DANJJAN_IOS_RUNNER_PROFILE_BASE64/);
  assert.match(source, /DANJJAN_IOS_WIDGET_PROFILE_BASE64/);
  assert.match(source, /DANJJAN_ASC_API_PRIVATE_KEY_BASE64/);
  assert.match(source, /DANJJAN_APPLE_TEAM_ID/);
  assert.match(source, /APPLE_SIGN_IN_CLIENT_ID/);
  assert.match(source, /com\.vinscent\.vinscent/);
  assert.match(source, /Supabase Dashboard/);
  assert.match(source, /Firebase Console/);
  assert.match(source, /TestFlight/);
  assert.match(source, /check_ios_release_mac\.sh/);
});

test('release documents point to the automated iOS handoff', async () => {
  const signingGuide = await load(signingGuideUrl);
  const checklist = await load(submissionChecklistUrl);

  assert.match(signingGuide, /ios-mac-handoff\.md/);
  assert.match(signingGuide, /iOS release candidate/);
  assert.doesNotMatch(
    signingGuide,
    /스크립트는 App Store Connect에 업로드하지 않으므로/,
  );
  assert.match(checklist, /check_ios_release_mac\.sh/);
  assert.match(checklist, /iOS release candidate/);
});
