#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Local iOS verification must run on macOS." >&2
  exit 1
fi

for command_name in flutter dart pod; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command is unavailable: $command_name" >&2
    exit 1
  fi
done

flutter_version="$(flutter --version | awk 'NR == 1 { print $2 }')"
if [[ "$flutter_version" != "3.41.9" ]]; then
  echo "Flutter 3.41.9 is required; found ${flutter_version:-unknown}." >&2
  exit 1
fi

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "$script_directory/.." && pwd)"
cd "$repository_root/apps/mobile"

flutter pub get
(
  cd ios
  pod install --deployment
)
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub
flutter test --no-pub
flutter build ios --simulator --debug --no-codesign --no-pub

printf 'Local iOS verification passed.\n'
