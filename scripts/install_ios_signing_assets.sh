#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS signing assets can only be installed on macOS." >&2
  exit 1
fi

required_variables=(
  GITHUB_ENV
  RUNNER_TEMP
  DANJJAN_IOS_DISTRIBUTION_CERTIFICATE_BASE64
  DANJJAN_IOS_DISTRIBUTION_CERTIFICATE_PASSWORD
  DANJJAN_IOS_RUNNER_PROFILE_BASE64
  DANJJAN_IOS_WIDGET_PROFILE_BASE64
  DANJJAN_APPLE_TEAM_ID
)

for variable_name in "${required_variables[@]}"; do
  if [[ -z "${!variable_name:-}" ]]; then
    echo "Missing required environment variable: ${variable_name}" >&2
    exit 1
  fi
done

if [[ ! "$DANJJAN_APPLE_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "DANJJAN_APPLE_TEAM_ID must be a 10-character Team ID." >&2
  exit 1
fi

certificate_path="$RUNNER_TEMP/danjjan-distribution.p12"
certificate_pem_path="$RUNNER_TEMP/danjjan-distribution.pem"
keychain_path="$RUNNER_TEMP/danjjan-signing.keychain-db"
runner_profile_source="$RUNNER_TEMP/danjjan-runner.mobileprovision"
widget_profile_source="$RUNNER_TEMP/danjjan-widget.mobileprovision"
runner_profile_plist="$RUNNER_TEMP/danjjan-runner-profile.plist"
widget_profile_plist="$RUNNER_TEMP/danjjan-widget-profile.plist"
export_options_path="$RUNNER_TEMP/danjjan-export-options.plist"
profile_directory="$HOME/Library/MobileDevice/Provisioning Profiles"
runner_profile_path=""
widget_profile_path=""
keychain_password="$(openssl rand -hex 32)"

cleanup_on_error() {
  local status=$?
  if (( status == 0 )); then
    return
  fi

  security delete-keychain "$keychain_path" >/dev/null 2>&1 || true
  rm -f \
    "$certificate_path" \
    "$certificate_pem_path" \
    "$runner_profile_source" \
    "$widget_profile_source" \
    "$runner_profile_plist" \
    "$widget_profile_plist" \
    "$export_options_path"
  if [[ -n "$runner_profile_path" ]]; then
    rm -f "$runner_profile_path"
  fi
  if [[ -n "$widget_profile_path" ]]; then
    rm -f "$widget_profile_path"
  fi
  exit "$status"
}
trap cleanup_on_error EXIT

decode_base64() {
  local value="$1"
  local output_path="$2"

  if ! printf '%s' "$value" | base64 --decode > "$output_path" 2>/dev/null; then
    printf '%s' "$value" | base64 -D > "$output_path"
  fi
  test -s "$output_path"
  chmod 600 "$output_path"
}

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

decode_base64 \
  "$DANJJAN_IOS_DISTRIBUTION_CERTIFICATE_BASE64" \
  "$certificate_path"
decode_base64 "$DANJJAN_IOS_RUNNER_PROFILE_BASE64" "$runner_profile_source"
decode_base64 "$DANJJAN_IOS_WIDGET_PROFILE_BASE64" "$widget_profile_source"

security create-keychain -p "$keychain_password" "$keychain_path"
security set-keychain-settings -lut 21600 "$keychain_path"
security unlock-keychain -p "$keychain_password" "$keychain_path"
security import "$certificate_path" \
  -P "$DANJJAN_IOS_DISTRIBUTION_CERTIFICATE_PASSWORD" \
  -A \
  -t cert \
  -f pkcs12 \
  -k "$keychain_path"
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -k "$keychain_password" \
  "$keychain_path"
security list-keychains -d user -s "$keychain_path"

identity_output="$(security find-identity -v -p codesigning "$keychain_path")"
if ! grep -Fq "Apple Distribution" <<< "$identity_output"; then
  echo "The restored keychain does not contain an Apple Distribution identity." >&2
  exit 1
fi

openssl pkcs12 \
  -in "$certificate_path" \
  -clcerts \
  -nokeys \
  -passin env:DANJJAN_IOS_DISTRIBUTION_CERTIFICATE_PASSWORD \
  -out "$certificate_pem_path"
certificate_subject="$(
  openssl x509 -in "$certificate_pem_path" -noout -subject -nameopt RFC2253
)"
if [[ ! "$certificate_subject" =~ (^|,)OU=${DANJJAN_APPLE_TEAM_ID}(,|$) ]]; then
  echo "Apple Distribution certificate Team ID does not match." >&2
  exit 1
fi

security cms -D -i "$runner_profile_source" > "$runner_profile_plist"
security cms -D -i "$widget_profile_source" > "$widget_profile_plist"

validate_profile() {
  local label="$1"
  local plist_path="$2"
  local expected_bundle_id="$3"
  local expects_runner_capabilities="$4"
  local uuid
  local team_id
  local application_identifier
  local app_group

  uuid="$(read_plist_value "$plist_path" UUID)"
  team_id="$(read_plist_value "$plist_path" 'TeamIdentifier:0')"
  application_identifier="$(
    read_plist_value "$plist_path" 'Entitlements:application-identifier'
  )"
  app_group="$(
    read_plist_value \
      "$plist_path" \
      'Entitlements:com.apple.security.application-groups:0'
  )"

  if [[ ! "$uuid" =~ ^[0-9A-Fa-f-]{36}$ ]]; then
    echo "${label} profile UUID is invalid." >&2
    exit 1
  fi

  require_equal "${label} profile Team ID" "$team_id" "$DANJJAN_APPLE_TEAM_ID"
  require_equal \
    "${label} profile application identifier" \
    "$application_identifier" \
    "${DANJJAN_APPLE_TEAM_ID}.${expected_bundle_id}"
  require_equal \
    "${label} profile App Group" \
    "$app_group" \
    "group.com.vinscent.vinscent"

  if [[ "$expects_runner_capabilities" == "true" ]]; then
    require_equal \
      "Runner profile push environment" \
      "$(read_plist_value "$plist_path" 'Entitlements:aps-environment')" \
      "production"
    require_equal \
      "Runner profile Sign in with Apple" \
      "$(
        read_plist_value \
          "$plist_path" \
          'Entitlements:com.apple.developer.applesignin:0'
      )" \
      "Default"
  else
    if read_plist_value \
      "$plist_path" \
      'Entitlements:aps-environment' \
      >/dev/null 2>&1; then
      echo "Widget profile must not contain push notifications." >&2
      exit 1
    fi
    if read_plist_value \
      "$plist_path" \
      'Entitlements:com.apple.developer.applesignin:0' \
      >/dev/null 2>&1; then
      echo "Widget profile must not contain Sign in with Apple." >&2
      exit 1
    fi
  fi

  printf '%s' "$uuid"
}

runner_profile_uuid="$(
  validate_profile \
    "Runner" \
    "$runner_profile_plist" \
    "com.vinscent.vinscent" \
    "true"
)"
widget_profile_uuid="$(
  validate_profile \
    "Widget" \
    "$widget_profile_plist" \
    "com.vinscent.vinscent.widgets" \
    "false"
)"

mkdir -p "$profile_directory"
runner_profile_path="$profile_directory/${runner_profile_uuid}.mobileprovision"
widget_profile_path="$profile_directory/${widget_profile_uuid}.mobileprovision"
cp "$runner_profile_source" "$runner_profile_path"
cp "$widget_profile_source" "$widget_profile_path"
chmod 600 "$runner_profile_path" "$widget_profile_path"

cat > "$export_options_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
  <key>method</key>
  <string>app-store-connect</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>com.vinscent.vinscent</key>
    <string>${runner_profile_uuid}</string>
    <key>com.vinscent.vinscent.widgets</key>
    <string>${widget_profile_uuid}</string>
  </dict>
  <key>signingStyle</key>
  <string>manual</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>teamID</key>
  <string>${DANJJAN_APPLE_TEAM_ID}</string>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
EOF
chmod 600 "$export_options_path"

{
  printf 'DANJJAN_IOS_CERTIFICATE_PATH=%s\n' "$certificate_path"
  printf 'DANJJAN_IOS_KEYCHAIN_PATH=%s\n' "$keychain_path"
  printf 'DANJJAN_IOS_RUNNER_PROFILE_PATH=%s\n' "$runner_profile_path"
  printf 'DANJJAN_IOS_WIDGET_PROFILE_PATH=%s\n' "$widget_profile_path"
  printf 'DANJJAN_IOS_EXPORT_OPTIONS_PLIST=%s\n' "$export_options_path"
  printf 'DANJJAN_RUNNER_PROFILE_SPECIFIER=%s\n' "$runner_profile_uuid"
  printf 'DANJJAN_WIDGET_PROFILE_SPECIFIER=%s\n' "$widget_profile_uuid"
  printf 'FLUTTER_XCODE_DEVELOPMENT_TEAM=%s\n' "$DANJJAN_APPLE_TEAM_ID"
  printf 'FLUTTER_XCODE_DANJJAN_CODE_SIGN_STYLE=Manual\n'
  printf \
    'FLUTTER_XCODE_DANJJAN_RUNNER_PROFILE_SPECIFIER=%s\n' \
    "$runner_profile_uuid"
  printf \
    'FLUTTER_XCODE_DANJJAN_WIDGET_PROFILE_SPECIFIER=%s\n' \
    "$widget_profile_uuid"
} >> "$GITHUB_ENV"

rm -f \
  "$certificate_pem_path" \
  "$runner_profile_source" \
  "$widget_profile_source" \
  "$runner_profile_plist" \
  "$widget_profile_plist"
trap - EXIT

echo "iOS signing assets installed for Runner and VinscentWidgets."
