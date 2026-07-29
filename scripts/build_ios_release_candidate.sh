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

  if [[ "$value" != https://* ||
        "$value" == *"?"* ||
        "$value" == *"#"* ||
        "$value" == *"@"* ]]; then
    echo "${variable_name} must be an HTTPS URL without user info, query, or fragment." >&2
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

mkdir -p "$evidence_directory"

ipa_output="$evidence_directory/danjjan-ios-build-${build_number}.ipa"
archive_output="$evidence_directory/danjjan-ios-build-${build_number}.xcarchive.zip"
cp "${ipa_candidates[0]}" "$ipa_output"
ditto -c -k --sequesterRsrc --keepParent \
  "${archive_candidates[0]}" \
  "$archive_output"

commit_sha="$(git -C "$repository_root" rev-parse HEAD)"
created_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

{
  printf 'commit_sha=%s\n' "$commit_sha"
  printf 'app_version=%s\n' "$app_version"
  printf 'build_number=%s\n' "$build_number"
  printf 'created_at=%s\n' "$created_at"
} > "$evidence_directory/metadata.txt"

(
  cd "$evidence_directory"
  shasum -a 256 \
    "$(basename "$ipa_output")" \
    "$(basename "$archive_output")" \
    > SHA256SUMS
)

echo "iOS release candidate created at ${evidence_directory}"
