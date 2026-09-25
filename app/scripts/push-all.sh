#!/usr/bin/env bash
#
# push-all.sh — push the weathergpt-app repo AND the linked weathergpt backend
# submodule in one step.
#
# This is the REQUIRED way to push changes for this repository (see README.md
# and AGENTS.md). A bare `git push` only updates weathergpt-app — it will leave
# unpushed backend commits inside the backend/ submodule and won't move the
# submodule pointer for you.
#
# Usage:
#   ./scripts/push-all.sh "your commit message"
#   ./scripts/push-all.sh                # message defaults to "chore: update"
#
# Behaviour, in order:
#   1. If backend/ is a fresh (uninitialised) submodule, check it out.
#      An already-checked-out backend is left exactly as-is — local commits
#      and edits are never reset.
#   2. Push the backend (omsenjalia/weathergpt): uncommitted backend changes
#      are committed with the same message, then all local commits are pushed
#      to the backend's branch (from .gitmodules/submodule.backend.branch,
#      default master).
#   3. Stage everything in weathergpt-app (source changes + the submodule
#      pointer), commit with the given message (skipped when nothing staged),
#      then push the current app branch to origin.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MSG="${1:-chore: update}"
BACKEND_DIR="$ROOT/backend"

log() { printf '\n==> %s\n' "$*"; }

# ---------------------------------------------------------------------------
# 1) Backend submodule (omsenjalia/weathergpt)
# ---------------------------------------------------------------------------
log "backend submodule (omsenjalia/weathergpt)"

# Only initialise on a fresh clone where the submodule has no working copy yet.
# `git submodule update` on an existing checkout would reset it and lose local
# commits, so we never run it when backend/ is already initialised.
if [ ! -e "$BACKEND_DIR/.git" ]; then
  git submodule update --init --recursive
  printf '    backend submodule initialised\n'
fi

sub_branch="$(git config -f "$ROOT/.gitmodules" submodule.backend.branch 2>/dev/null || echo master)"

if [ -d "$BACKEND_DIR/.git" ] || [ -f "$BACKEND_DIR/.git" ]; then
  cd "$BACKEND_DIR"

  # Commit any pending backend changes so they can be pushed.
  if ! git diff --quiet || ! git diff --cached --quiet; then
    printf '    committing pending backend changes\n'
    git add -A
    git commit -m "$MSG"
  fi

  # Determine which backend branch to push to.
  target="$sub_branch"
  cur="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
  if [ "$cur" != "HEAD" ]; then
    target="$cur"
  fi

  # How many local commits are not yet on origin's copy of that branch?
  git fetch origin -q >/dev/null 2>&1 || true
  ahead=0
  if git rev-parse --verify -q "origin/$target" >/dev/null 2>&1; then
    ahead="$(git rev-list --count "origin/$target..HEAD" 2>/dev/null || echo 0)"
  else
    ahead="$(git rev-list --count HEAD 2>/dev/null || echo 0)"
    [ "$ahead" -gt 0 ] && : || ahead=1
  fi

  if [ "$ahead" -gt 0 ]; then
    printf '    pushing %s commit(s) to omsenjalia/weathergpt (%s)\n' "$ahead" "$target"
    git push origin "HEAD:$target"
  else
    printf '    backend already in sync with origin/%s\n' "$target"
  fi

  cd "$ROOT"
else
  printf '    no backend working copy found — run: git submodule update --init\n'
fi

# ---------------------------------------------------------------------------
# 2) weathergpt-app repo (source changes + submodule pointer)
# ---------------------------------------------------------------------------
git add -A

if git diff --cached --quiet; then
  log "weathergpt-app: nothing to commit"
else
  log "committing weathergpt-app changes"
  git commit -m "$MSG"
fi

app_branch="$(git rev-parse --abbrev-ref HEAD)"
log "pushing weathergpt-app ($app_branch) to origin"
git push origin "$app_branch"

log "done — both repos are pushed"
