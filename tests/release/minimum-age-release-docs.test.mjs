import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');

function readRepositoryFile(relativePath) {
  return readFileSync(resolve(repositoryRoot, relativePath), 'utf8');
}

test('release documents match the implemented minimum service age', () => {
  const privacyDataMap = readRepositoryFile(
    'docs/release/privacy-data-map.md',
  );
  const policyReleaseGates = readRepositoryFile(
    'docs/release/policy-web-release-gates.md',
  );
  const combined = `${privacyDataMap}\n${policyReleaseGates}`;

  assert.doesNotMatch(combined, /최저 연령 제한이 없음/);
  assert.doesNotMatch(combined, /만 14세 이상 검증은 없다/);
  assert.doesNotMatch(combined, /서비스 가입과 이용을 만 18세 이상으로 제한/);
  assert.match(combined, /서비스 가입과 이용은 만 14세 이상/);
  assert.match(combined, /app_age_policy\.dart/);
  assert.match(combined, /20260730000000_enforce_profile_minimum_age\.sql/);
});
