#!/usr/bin/env bash
# github-actions-deploy.sh — apply already-synced repo state on the remote team host

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

BRANCH="main"
TARGET_SHA=""

usage() {
  cat <<'EOF'
Usage: bash scripts/github-actions-deploy.sh [--branch main] [--sha <commit>]

Options:
  --branch NAME     Branch to deploy (default: main)
  --sha COMMIT      Exact commit SHA for logging/traceability
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --branch)
      BRANCH="$2"
      shift 2
      ;;
    --sha)
      TARGET_SHA="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "❌ Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

cd "$REPO_DIR"

command -v openclaw >/dev/null 2>&1 || {
  echo "❌ openclaw not found"
  exit 1
}

if [ ! -f "$REPO_DIR/.env" ]; then
  echo "❌ .env missing in $REPO_DIR"
  echo "   CI deploy expects the server to keep its own .env with real runtime values."
  exit 1
fi

if [ ! -f "$REPO_DIR/team-config.sh" ] || [ ! -f "$REPO_DIR/scripts/setup.sh" ]; then
  echo "❌ Repo payload is incomplete in $REPO_DIR"
  echo "   CI deploy expects the workflow to sync the repository contents to the server first."
  exit 1
fi

echo "🚀 GitHub Actions deploy"
echo "================================"
echo "Repo:   $REPO_DIR"
echo "Branch: $BRANCH"
if [ -n "$TARGET_SHA" ]; then
  echo "Target: $TARGET_SHA"
fi
echo ""

if [ -n "$TARGET_SHA" ]; then
  printf '%s\n' "$TARGET_SHA" > "$REPO_DIR/.github-actions-last-deploy"
fi

echo ""
echo "🧪 Repository smoke"
bash scripts/smoke-test.sh

echo ""
echo "🧩 Applying repo -> runtime sync"
bash scripts/setup.sh

echo ""
echo "🚀 Ensuring gateway is running"
bash scripts/start-team.sh

echo ""
echo "🔎 Post-deploy validation"
bash scripts/post-update-check.sh

echo ""
if [ -n "$TARGET_SHA" ]; then
  echo "✅ Deploy complete: $TARGET_SHA"
else
  echo "✅ Deploy complete"
fi
