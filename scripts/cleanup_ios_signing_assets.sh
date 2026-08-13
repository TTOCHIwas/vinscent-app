#!/usr/bin/env bash
set -u

if [[ "$(uname -s)" != "Darwin" ]]; then
  exit 0
fi

if [[ -n "${DANJJAN_IOS_KEYCHAIN_PATH:-}" ]]; then
  security delete-keychain "$DANJJAN_IOS_KEYCHAIN_PATH" >/dev/null 2>&1 || true
fi

private_paths=(
  "${DANJJAN_IOS_CERTIFICATE_PATH:-}"
  "${DANJJAN_IOS_RUNNER_PROFILE_PATH:-}"
  "${DANJJAN_IOS_WIDGET_PROFILE_PATH:-}"
  "${DANJJAN_IOS_EXPORT_OPTIONS_PLIST:-}"
  "${DANJJAN_ASC_API_PRIVATE_KEY_PATH:-}"
)

for private_path in "${private_paths[@]}"; do
  if [[ -n "$private_path" ]]; then
    rm -f "$private_path"
  fi
done
