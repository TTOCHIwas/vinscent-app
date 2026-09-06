#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS release candidates must be built on macOS." >&2
  exit 1
fi

if [[ $# -ne 2 ||
      ! "$1" =~ ^[1-9][0-9]*$ ||
      ! "$2" =~ ^[0-9a-f]{40}$ ]]; then
  echo \
    "Usage: scripts/build_ios_release_candidate.sh <positive-build-number> <main-commit-sha>" \
    >&2
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
  DANJJAN_APPLE_TEAM_ID
)

for variable_name in "${required_variables[@]}"; do
  if [[ -z "${!variable_name:-}" ]]; then
    echo "Missing required environment variable: ${variable_name}" >&2
    exit 1
  fi
done

if [[ ! "$DANJJAN_APPLE_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
  echo \
    "DANJJAN_APPLE_TEAM_ID must be a 10-character Apple Developer Team ID." \
    >&2
  exit 1
fi

if [[ ! "$DANJJAN_KAKAO_NATIVE_APP_KEY" =~ ^[A-Za-z0-9]+$ ]]; then
  echo "DANJJAN_KAKAO_NATIVE_APP_KEY must be alphanumeric." >&2
  exit 1
fi

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
expected_commit_sha="$2"
flutter_binary="${FLUTTER_BIN:-flutter}"
evidence_directory="$mobile_directory/build/release-evidence/ios-build-${build_number}"
evidence_parent="$(dirname "$evidence_directory")"
source_verifier="$repository_root/scripts/verify_release_source.sh"
source_branch="$(git -C "$repository_root" branch --show-current)"
source_commit_sha="$(git -C "$repository_root" rev-parse HEAD)"
kakao_xcconfig="$mobile_directory/ios/Flutter/Kakao.generated.xcconfig"

if [[ "$source_branch" != "main" && "${GITHUB_REF:-}" != "refs/heads/main" ]]; then
  echo "iOS release candidates must be built from main." >&2
  exit 1
fi

"$source_verifier" "$expected_commit_sha"

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

if [[ -n "${RUNNER_TEMP:-}" ]]; then
  export PUB_CACHE="$RUNNER_TEMP/danjjan-pub-cache"
fi

"$flutter_binary" pub get
release_temp_root="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
export GEM_HOME="$release_temp_root/danjjan-ios-ruby-gems"
export PATH="$GEM_HOME/bin:$PATH"
export BUNDLE_GEMFILE="$mobile_directory/ios/Gemfile"
export BUNDLE_PATH="$release_temp_root/danjjan-ios-bundle"
export BUNDLE_APP_CONFIG="$release_temp_root/danjjan-ios-bundle-config"
export BUNDLE_FROZEN=true
gem install bundler --version 2.4.22 --no-document
bundle _2.4.22_ install --jobs 4 --retry 3
(
  cd ios
  bundle _2.4.22_ exec pod install --deployment
)
build_arguments=(
  ipa
  --release
  --no-pub
  --build-number "$build_number"
  --dart-define="SUPABASE_URL=$DANJJAN_SUPABASE_URL"
  --dart-define="SUPABASE_ANON_KEY=$DANJJAN_SUPABASE_ANON_KEY"
  --dart-define="KAKAO_NATIVE_APP_KEY=$DANJJAN_KAKAO_NATIVE_APP_KEY"
  --dart-define="POLICY_BASE_URL=$DANJJAN_POLICY_BASE_URL"
)
export_method="app-store"

cleanup_kakao_xcconfig() {
  rm -f "$kakao_xcconfig"
}

trap cleanup_kakao_xcconfig EXIT
printf 'KAKAO_NATIVE_APP_KEY=%s\n' \
  "$DANJJAN_KAKAO_NATIVE_APP_KEY" > "$kakao_xcconfig"
chmod 600 "$kakao_xcconfig"

if [[ -n "${DANJJAN_IOS_EXPORT_OPTIONS_PLIST:-}" ]]; then
  if [[ ! -s "$DANJJAN_IOS_EXPORT_OPTIONS_PLIST" ]]; then
    echo "DANJJAN_IOS_EXPORT_OPTIONS_PLIST must reference a non-empty file." >&2
    exit 1
  fi
  build_arguments+=(
    --export-options-plist="$DANJJAN_IOS_EXPORT_OPTIONS_PLIST"
  )
  export_method="app-store-connect"
else
  build_arguments+=(--export-method app-store)
fi

"$flutter_binary" build "${build_arguments[@]}"
cleanup_kakao_xcconfig
trap - EXIT

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
archive_app_bundle="$archive_path/Products/Applications/Runner.app"
archive_widget_bundle="$archive_app_bundle/PlugIns/VinscentWidgets.appex"

test -d "$archive_app_bundle"
test -d "$archive_widget_bundle"
test -s "$archive_app_bundle/PrivacyInfo.xcprivacy"
test -s "$archive_widget_bundle/PrivacyInfo.xcprivacy"
unzip -t "$ipa_path" >/dev/null
codesign --verify --deep --strict "$archive_app_bundle"

temporary_evidence="$(mktemp -d)"
trap 'rm -rf "$temporary_evidence"' EXIT
ipa_extract_directory="$temporary_evidence/ipa"
mkdir -p "$ipa_extract_directory"
unzip -q "$ipa_path" -d "$ipa_extract_directory"

exported_app_candidates=("$ipa_extract_directory"/Payload/*.app)
if [[ ${#exported_app_candidates[@]} -ne 1 ]]; then
  echo \
    "Expected one exported app in the IPA, found ${#exported_app_candidates[@]}." \
    >&2
  exit 1
fi

app_bundle="${exported_app_candidates[0]}"
widget_bundle="$app_bundle/PlugIns/VinscentWidgets.appex"
test -d "$widget_bundle"
test -s "$app_bundle/PrivacyInfo.xcprivacy"
test -s "$widget_bundle/PrivacyInfo.xcprivacy"
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
exported_version="$(
  read_plist_value "$app_bundle/Info.plist" CFBundleShortVersionString
)"
exported_build_number="$(
  read_plist_value "$app_bundle/Info.plist" CFBundleVersion
)"
kakao_url_scheme="$(
  read_plist_value \
    "$app_bundle/Info.plist" \
    "CFBundleURLTypes:0:CFBundleURLSchemes:0"
)"

require_equal "Runner bundle ID" "$runner_bundle_id" "com.vinscent.vinscent"
require_equal \
  "Widget bundle ID" \
  "$widget_bundle_id" \
  "com.vinscent.vinscent.widgets"
require_equal "Exported version" "$exported_version" "$app_version"
require_equal "Exported build number" "$exported_build_number" "$build_number"

if [[ "$kakao_url_scheme" != "kakao${DANJJAN_KAKAO_NATIVE_APP_KEY}" ]]; then
  echo "Exported Kakao URL scheme does not match the configured key." >&2
  exit 1
fi

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
runner_team_id="$(
  read_plist_value \
    "$runner_entitlements" \
    "com.apple.developer.team-identifier"
)"
widget_team_id="$(
  read_plist_value \
    "$widget_entitlements" \
    "com.apple.developer.team-identifier"
)"
runner_application_identifier="$(
  read_plist_value "$runner_entitlements" application-identifier
)"
widget_application_identifier="$(
  read_plist_value "$widget_entitlements" application-identifier
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
require_equal "Runner Team ID" "$runner_team_id" "$DANJJAN_APPLE_TEAM_ID"
require_equal "Widget Team ID" "$widget_team_id" "$DANJJAN_APPLE_TEAM_ID"
require_equal \
  "Runner application identifier" \
  "$runner_application_identifier" \
  "${DANJJAN_APPLE_TEAM_ID}.${runner_bundle_id}"
require_equal \
  "Widget application identifier" \
  "$widget_application_identifier" \
  "${DANJJAN_APPLE_TEAM_ID}.${widget_bundle_id}"

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

"$source_verifier" "$expected_commit_sha"

mkdir -p "$evidence_parent"
staged_evidence="$(
  mktemp -d "$evidence_parent/.ios-build-${build_number}.XXXXXX"
)"
trap 'rm -rf "$temporary_evidence" "$staged_evidence"' EXIT

ipa_output="$staged_evidence/danjjan-ios-build-${build_number}.ipa"
archive_output="$staged_evidence/danjjan-ios-build-${build_number}.xcarchive.zip"
cp "$ipa_path" "$ipa_output"
ditto -c -k --sequesterRsrc --keepParent \
  "$archive_path" \
  "$archive_output"
cp "$runner_entitlements" "$staged_evidence/"
cp "$widget_entitlements" "$staged_evidence/"
cp "$privacy_manifest_list" "$staged_evidence/"

created_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

{
  printf 'commit_sha=%s\n' "$source_commit_sha"
  printf 'app_version=%s\n' "$app_version"
  printf 'build_number=%s\n' "$build_number"
  printf 'xcode_version=%s\n' "$xcode_version"
  printf 'iphoneos_sdk_version=%s\n' "$iphoneos_sdk_version"
  printf 'export_method=%s\n' "$export_method"
  printf 'runner_bundle_id=%s\n' "$runner_bundle_id"
  printf 'widget_bundle_id=%s\n' "$widget_bundle_id"
  printf 'team_id=%s\n' "$runner_team_id"
  printf 'team_id_verification=verified\n'
  printf 'runner_application_identifier=%s\n' \
    "$runner_application_identifier"
  printf 'widget_application_identifier=%s\n' \
    "$widget_application_identifier"
  printf 'push_environment=%s\n' "$push_environment"
  printf 'app_group=%s\n' "$runner_app_group"
  printf 'kakao_url_scheme_verification=verified\n'
  printf 'created_at=%s\n' "$created_at"
} > "$staged_evidence/metadata.txt"

(
  cd "$staged_evidence"
  shasum -a 256 \
    "$(basename "$ipa_output")" \
    "$(basename "$archive_output")" \
    "$(basename "$runner_entitlements")" \
    "$(basename "$widget_entitlements")" \
    "$(basename "$privacy_manifest_list")" \
    > SHA256SUMS
)

rm -rf "$temporary_evidence"
mv "$staged_evidence" "$evidence_directory"
trap - EXIT

echo "iOS release candidate created at ${evidence_directory}"
