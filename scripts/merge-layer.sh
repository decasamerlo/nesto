#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: merge-layer.sh <pr-number> [repo]" >&2
  echo "  repo defaults to the git remote of the current directory" >&2
  exit 1
fi

PR="$1"
if [ "$#" -ge 2 ]; then
  REPO="$2"
else
  REPO=$(git remote get-url origin | sed -E 's|.*github\.com[:/]([^/]+/[^/]+)(\.git)?$|\1|')
fi

if [ -z "${NESTO_BOT_TOKEN:-}" ]; then
  echo "NESTO_BOT_TOKEN is not set -- export the gatekeeper PAT from your keyring (see docs/conventions/stacked-prs.md)" >&2
  exit 1
fi

echo "==> gatekeeper approves $REPO#$PR"
GH_TOKEN="$NESTO_BOT_TOKEN" gh pr review "$PR" --repo "$REPO" --approve

echo "==> merging $REPO#$PR (async stack merge, squash)"
gh stack merge "$PR" --yes --squash

echo "==> syncing local branches after cascade rebase"
gh stack sync