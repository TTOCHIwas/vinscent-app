#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "$1" >&2
  exit 1
}

require_command() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 ||
    fail "Required command is unavailable: ${command_name}"
}

require_file() {
  local path="$1"
  [[ -s "$path" ]] || fail "Required file is missing or empty: ${path}"
}

require_text() {
  local path="$1"
  local expected="$2"
  local label="$3"
  grep -Fq "$expected" "$path" ||
    fail "${label} is missing from ${path}."
}

forbid_text() {
  local path="$1"
  local forbidden="$2"
  local label="$3"
  if grep -Fq "$forbidden" "$path"; then
    fail "${label} must not be present in ${path}."
  fi
}

if ! command -v uname >/dev/null 2>&1 || [[ "$(uname -s)" != "Darwin" ]]; then
  fail "The iOS release preflight must run on macOS."
fi

if [[ $# -ne 1 || ! "$1" =~ ^[0-9a-f]{40}$ ]]; then
  fail "Usage: scripts/check_ios_release_mac.sh <main-commit-sha>"
fi

required_commands=(
  git
  xcodebuild
  xcrun
  flutter
  dart
  pod
)
for command_name in "${required_commands[@]}"; do
  require_command "$command_name"
done

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "$script_directory/.." && pwd)"
ios_directory="$repository_root/apps/mobile/ios"
workspace_path="$ios_directory/Runner.xcworkspace"
workspace_data="$workspace_path/contents.xcworkspacedata"
project_file="$ios_directory/Runner.xcodeproj/project.pbxproj"
pod_lock="$ios_directory/Podfile.lock"
runner_entitlements="$ios_directory/Runner/Runner.entitlements"
widget_entitlements="$ios_directory/VinscentWidgets/VinscentWidgets.entitlements"
firebase_plist="$ios_directory/Runner/GoogleService-Info.plist"
expected_commit_sha="$1"
source_branch="$(git -C "$repository_root" branch --show-current)"

if [[ "$source_branch" != "main" && "${GITHUB_REF:-}" != "refs/heads/main" ]]; then
  fail "The iOS release preflight must run from main."
fi

"$repository_root/scripts/verify_release_source.sh" "$expected_commit_sha"

xcode_version="$(xcodebuild -version | awk 'NR == 1 { print $2 }')"
iphoneos_sdk_version="$(xcrun --sdk iphoneos --show-sdk-version)"
flutter_version="$(flutter --version | awk 'NR == 1 { print $2 }')"
cocoapods_version="$(pod --version)"

validate_minimum_major_version() {
  local tool_name="$1"
  local version="$2"
  local minimum_major="$3"
  local major="${version%%.*}"

  if [[ ! "$major" =~ ^[0-9]+$ ]] || (( major < minimum_major )); then
    fail "${tool_name} ${minimum_major} or later is required; found ${version:-unknown}."
  fi
}

validate_minimum_major_version "Xcode" "$xcode_version" 26
validate_minimum_major_version "iPhoneOS SDK" "$iphoneos_sdk_version" 26

if [[ "$flutter_version" != "3.41.9" ]]; then
  fail "Flutter 3.41.9 is required; found ${flutter_version:-unknown}."
fi

[[ -n "$cocoapods_version" ]] || fail "Unable to read the CocoaPods version."

require_file "$workspace_data"
require_file "$project_file"
require_file "$runner_entitlements"
require_file "$widget_entitlements"
require_file "$firebase_plist"

if [[ ! -s "$pod_lock" ]]; then
  fail \
    "Podfile.lock is missing. On the Mac, run 'flutter pub get' and then 'cd apps/mobile/ios && pod install', review the generated lock/workspace changes, commit them, and rerun this preflight."
fi

require_text \
  "$workspace_data" \
  "group:Pods/Pods.xcodeproj" \
  "The CocoaPods workspace reference"
require_text "$project_file" "com.vinscent.vinscent;" "Runner bundle ID"
require_text \
  "$project_file" \
  "com.vinscent.vinscent.widgets;" \
  "Widget bundle ID"
require_text \
  "$runner_entitlements" \
  "group.com.vinscent.vinscent" \
  "Runner App Group"
require_text \
  "$runner_entitlements" \
  "com.apple.developer.applesignin" \
  "Runner Sign in with Apple entitlement"
require_text \
  "$runner_entitlements" \
  "aps-environment" \
  "Runner push entitlement"
require_text \
  "$widget_entitlements" \
  "group.com.vinscent.vinscent" \
  "Widget App Group"
forbid_text \
  "$widget_entitlements" \
  "com.apple.developer.applesignin" \
  "Sign in with Apple entitlement"
forbid_text \
  "$widget_entitlements" \
  "aps-environment" \
  "Push entitlement"

firebase_bundle_id="$(
  /usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' "$firebase_plist" 2>/dev/null || true
)"
if [[ "$firebase_bundle_id" != "com.vinscent.vinscent" ]]; then
  fail \
    "GoogleService-Info.plist BUNDLE_ID must be com.vinscent.vinscent; found ${firebase_bundle_id:-missing}."
fi

workspace_listing="$(xcodebuild -workspace "$workspace_path" -list)"
if ! grep -Eq '^[[:space:]]+Runner[[:space:]]*$' <<<"$workspace_listing"; then
  fail "Runner scheme is unavailable in Runner.xcworkspace."
fi

printf 'iOS Mac preflight passed.\n'
printf '  commit: %s\n' "$expected_commit_sha"
printf '  Xcode: %s\n' "$xcode_version"
printf '  iPhoneOS SDK: %s\n' "$iphoneos_sdk_version"
printf '  Flutter: %s\n' "$flutter_version"
printf '  CocoaPods: %s\n' "$cocoapods_version"
