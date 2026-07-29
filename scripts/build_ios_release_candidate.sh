#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS release candidates must be built on macOS." >&2
  exit 1
fi

if [[ $# -ne 1 || ! "$1" =~ ^[1-9][0-9]*$ ]]; then
  echo "Usage: scripts/build_ios_release_candidate.sh <positive-build-number>" >&2
  exit 1
fi

xcode_version="$(xcodebuild -version | awk 'NR == 1 { print $2 }')"
iphoneos_sdk_version="$(xcrun --sdk iphoneos --show-sdk-version)"

validate_minimum_major_version() {
  local tool_name="$1"
  local version="$2"
  local minimum_major="$3"
  local major="${version%%.*}"

  if [[ ! "$major" =~ ^[0-9]+$ ]] || (( major < minimum_major )); then
    echo "${tool_name} ${minimum_major} or later is required; found ${version:-unknown}." >&2
    exit 1
  fi
}

validate_minimum_major_version "Xcode" "$xcode_version" 26
validate_minimum_major_version "iPhoneOS SDK" "$iphoneos_sdk_version" 26

required_variables=(
  DANJJAN_SUPABASE_URL
  DANJJAN_SUPABASE_ANON_KEY
  DANJJAN_KAKAO_NATIVE_APP_KEY
  DANJJAN_POLICY_BASE_URL
)

for variable_name in "${required_variables[@]}"; do
  if [[ -z "${!variable_name:-}" ]]; then
    echo "Missing required environment variable: ${variable_name}" >&2
    exit 1
  fi
done

validate_https_url() {
  local variable_name="$1"
  local value="$2"
  local authority="${value#https://}"
  authority="${authority%%/*}"

  if [[ "$value" != https://* ||
        -z "$authority" ||
        "$value" == *[[:space:]]* ||
        "$value" == *"?"* ||
        "$value" == *"#"* ||
        "$value" == *"@"* ]]; then
    echo "${variable_name} must be an HTTPS URL with a host and without whitespace, user info, query, or fragment." >&2
    exit 1
  fi
}

validate_https_url "DANJJAN_SUPABASE_URL" "$DANJJAN_SUPABASE_URL"
validate_https_url "DANJJAN_POLICY_BASE_URL" "$DANJJAN_POLICY_BASE_URL"

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "$script_directory/.." && pwd)"
mobile_directory="$repository_root/apps/mobile"
build_number="$1"
flutter_binary="${FLUTTER_BIN:-flutter}"
dart_binary="${DART_BIN:-dart}"
evidence_directory="$mobile_directory/build/release-evidence/ios-build-${build_number}"

cd "$mobile_directory"

app_version="$(sed -n 's/^version:[[:space:]]*\([^+[:space:]]*\).*/\1/p' pubspec.yaml)"
if [[ -z "$app_version" ]]; then
  echo "Unable to read the app version from pubspec.yaml." >&2
  exit 1
fi

if [[ -e "$evidence_directory" ]]; then
  echo "Release evidence already exists: ${evidence_directory}" >&2
  exit 1
fi

"$flutter_binary" pub get
"$dart_binary" format --output=none --set-exit-if-changed lib test
"$flutter_binary" analyze --no-pub
"$flutter_binary" test --no-pub
"$flutter_binary" build ipa \
  --release \
  --build-number "$build_number" \
  --dart-define="SUPABASE_URL=$DANJJAN_SUPABASE_URL" \
  --dart-define="SUPABASE_ANON_KEY=$DANJJAN_SUPABASE_ANON_KEY" \
  --dart-define="KAKAO_NATIVE_APP_KEY=$DANJJAN_KAKAO_NATIVE_APP_KEY" \
  --dart-define="POLICY_BASE_URL=$DANJJAN_POLICY_BASE_URL"

shopt -s nullglob
archive_candidates=(build/ios/archive/*.xcarchive)
ipa_candidates=(build/ios/ipa/*.ipa)

if [[ ${#archive_candidates[@]} -ne 1 ]]; then
  echo "Expected one Xcode archive, found ${#archive_candidates[@]}." >&2
  exit 1
fi

if [[ ${#ipa_candidates[@]} -ne 1 ]]; then
  echo "Expected one IPA, found ${#ipa_candidates[@]}." >&2
  exit 1
fi

archive_path="${archive_candidates[0]}"
ipa_path="${ipa_candidates[0]}"
app_bundle="$archive_path/Products/Applications/Runner.app"
widget_bundle="$app_bundle/PlugIns/VinscentWidgets.appex"

test -d "$app_bundle"
test -d "$widget_bundle"
test -s "$app_bundle/PrivacyInfo.xcprivacy"
test -s "$widget_bundle/PrivacyInfo.xcprivacy"
unzip -t "$ipa_path" >/dev/null
codesign --verify --deep --strict "$app_bundle"

read_plist_value() {
  local plist_path="$1"
  local key_path="$2"
  /usr/libexec/PlistBuddy -c "Print :${key_path}" "$plist_path"
}

require_equal() {
  local label="$1"
  local actual="$2"
  local expected="$3"

  if [[ "$actual" != "$expected" ]]; then
    echo "${label} must be '${expected}'; found '${actual:-missing}'." >&2
    exit 1
  fi
}

runner_bundle_id="$(read_plist_value "$app_bundle/Info.plist" CFBundleIdentifier)"
widget_bundle_id="$(
  read_plist_value "$widget_bundle/Info.plist" CFBundleIdentifier
)"
archive_version="$(
  read_plist_value "$app_bundle/Info.plist" CFBundleShortVersionString
)"
archive_build_number="$(read_plist_value "$app_bundle/Info.plist" CFBundleVersion)"

require_equal "Runner bundle ID" "$runner_bundle_id" "com.vinscent.vinscent"
require_equal \
  "Widget bundle ID" \
  "$widget_bundle_id" \
  "com.vinscent.vinscent.widgets"
require_equal "Archive version" "$archive_version" "$app_version"
require_equal "Archive build number" "$archive_build_number" "$build_number"

temporary_evidence="$(mktemp -d)"
trap 'rm -rf "$temporary_evidence"' EXIT
runner_entitlements="$temporary_evidence/Runner-entitlements.plist"
widget_entitlements="$temporary_evidence/VinscentWidgets-entitlements.plist"
privacy_manifest_list="$temporary_evidence/privacy-manifests.txt"

codesign -d --entitlements :- "$app_bundle" \
  > "$runner_entitlements" \
  2> "$temporary_evidence/Runner-codesign.txt"
codesign -d --entitlements :- "$widget_bundle" \
  > "$widget_entitlements" \
  2> "$temporary_evidence/VinscentWidgets-codesign.txt"
test -s "$runner_entitlements"
test -s "$widget_entitlements"

push_environment="$(
  read_plist_value "$runner_entitlements" aps-environment
)"
runner_app_group="$(
  read_plist_value \
    "$runner_entitlements" \
    "com.apple.security.application-groups:0"
)"
widget_app_group="$(
  read_plist_value \
    "$widget_entitlements" \
    "com.apple.security.application-groups:0"
)"
sign_in_with_apple="$(
  read_plist_value \
    "$runner_entitlements" \
    "com.apple.developer.applesignin:0"
)"

require_equal "Push environment" "$push_environment" "production"
require_equal \
  "Runner App Group" \
  "$runner_app_group" \
  "group.com.vinscent.vinscent"
require_equal \
  "Widget App Group" \
  "$widget_app_group" \
  "group.com.vinscent.vinscent"
require_equal "Sign in with Apple" "$sign_in_with_apple" "Default"

if read_plist_value "$widget_entitlements" aps-environment >/dev/null 2>&1; then
  echo "Widget must not declare the push notification entitlement." >&2
  exit 1
fi

if read_plist_value \
  "$widget_entitlements" \
  "com.apple.developer.applesignin:0" \
  >/dev/null 2>&1; then
  echo "Widget must not declare Sign in with Apple." >&2
  exit 1
fi

find "$app_bundle" -name PrivacyInfo.xcprivacy -type f -print |
  sort > "$privacy_manifest_list"
if [[ "$(wc -l < "$privacy_manifest_list")" -lt 2 ]]; then
  echo "Runner archive must contain app and widget privacy manifests." >&2
  exit 1
fi

mkdir -p "$evidence_directory"

ipa_output="$evidence_directory/danjjan-ios-build-${build_number}.ipa"
archive_output="$evidence_directory/danjjan-ios-build-${build_number}.xcarchive.zip"
cp "$ipa_path" "$ipa_output"
ditto -c -k --sequesterRsrc --keepParent \
  "$archive_path" \
  "$archive_output"
cp "$runner_entitlements" "$evidence_directory/"
cp "$widget_entitlements" "$evidence_directory/"
cp "$privacy_manifest_list" "$evidence_directory/"

commit_sha="$(git -C "$repository_root" rev-parse HEAD)"
created_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

{
  printf 'commit_sha=%s\n' "$commit_sha"
  printf 'app_version=%s\n' "$app_version"
  printf 'build_number=%s\n' "$build_number"
  printf 'xcode_version=%s\n' "$xcode_version"
  printf 'iphoneos_sdk_version=%s\n' "$iphoneos_sdk_version"
  printf 'runner_bundle_id=%s\n' "$runner_bundle_id"
  printf 'widget_bundle_id=%s\n' "$widget_bundle_id"
  printf 'push_environment=%s\n' "$push_environment"
  printf 'app_group=%s\n' "$runner_app_group"
  printf 'created_at=%s\n' "$created_at"
} > "$evidence_directory/metadata.txt"

(
  cd "$evidence_directory"
  shasum -a 256 \
    "$(basename "$ipa_output")" \
    "$(basename "$archive_output")" \
    "$(basename "$runner_entitlements")" \
    "$(basename "$widget_entitlements")" \
    "$(basename "$privacy_manifest_list")" \
    > SHA256SUMS
)

trap - EXIT
rm -rf "$temporary_evidence"

echo "iOS release candidate created at ${evidence_directory}"
