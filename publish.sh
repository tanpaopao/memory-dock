#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

REPO_NAME="${1:-memory-dock}"
VISIBILITY="${2:-public}"

if ! command -v git >/dev/null 2>&1; then
  echo "git not found" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is not installed. Install it from https://cli.github.com/" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not signed in. Run: gh auth login" >&2
  exit 1
fi

if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
  echo "No commit yet." >&2
  exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  if gh repo view "$REPO_NAME" >/dev/null 2>&1; then
    echo "Repository $REPO_NAME already exists; refusing to overwrite its remote." >&2
    exit 1
  fi
  gh repo create "$REPO_NAME" "--$VISIBILITY" --source=. --remote=origin --push
else
  git push -u origin main
fi

echo "Published: $(git remote get-url origin)"
