#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Usage: scripts/verify_release_source.sh <40-character-commit-sha>" >&2
  exit 1
fi

script_directory="$(cd "${BASH_SOURCE[0]%/*}" && pwd)"
repository_root="$(cd "$script_directory/.." && pwd)"
expected_commit_sha="$1"
current_commit_sha="$(git -C "$repository_root" rev-parse HEAD)"

if [[ "$current_commit_sha" != "$expected_commit_sha" ]]; then
  echo \
    "Release source commit must be '${expected_commit_sha}'; found '${current_commit_sha}'." \
    >&2
  exit 1
fi

if [[ -n "$(
  git -C "$repository_root" status --porcelain --untracked-files=all
)" ]]; then
  echo "Release source worktree must be clean." >&2
  exit 1
fi

echo "Release source verified at ${current_commit_sha}."
