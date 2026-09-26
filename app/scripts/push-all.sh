#!/usr/bin/env bash
# Compatibility entry point. This is ONE repository, not a backend submodule.
# Do not auto-stage every file: review and commit deliberately at the root.
set -euo pipefail
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$ROOT"
printf '%s\n' 'app/ and backend/ belong to the same repository.' \
  'Review and commit at the root, then push your current working branch:'
git status --short
printf '  git push origin %q\n' "$(git branch --show-current)"
