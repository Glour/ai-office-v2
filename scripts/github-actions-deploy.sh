#!/usr/bin/env bash
# github-actions-deploy.sh — deploy current repo state on the remote team host

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

BRANCH="main"
TARGET_SHA=""
ALLOW_DIRTY="false"

usage() {
  cat <<'EOF'
Usage: bash scripts/github-actions-deploy.sh [--branch main] [--sha <commit>] [--allow-dirty]

Options:
  --branch NAME     Branch to deploy (default: main)
  --sha COMMIT      Exact commit SHA to fast-forward to
  --allow-dirty     Continue even if the repo has local tracked changes
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
    --allow-dirty)
      ALLOW_DIRTY="true"
      shift
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

command -v git >/dev/null 2>&1 || {
  echo "❌ git not found"
  exit 1
}

command -v openclaw >/dev/null 2>&1 || {
  echo "❌ openclaw not found"
  exit 1
}

if [ ! -f "$REPO_DIR/.env" ]; then
  echo "❌ .env missing in $REPO_DIR"
  echo "   CI deploy expects the server to keep its own .env with real runtime values."
  exit 1
fi

if [ "$ALLOW_DIRTY" != "true" ] && [ -n "$(git status --porcelain)" ]; then
  echo "❌ Refusing to deploy: repo has local tracked changes."
  echo "   Commit/stash them on the server first, or rerun with --allow-dirty if you really want that behavior."
  git status --short
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

git fetch origin --prune
git checkout "$BRANCH" >/dev/null 2>&1 || git checkout -b "$BRANCH" "origin/$BRANCH"

if [ -n "$TARGET_SHA" ]; then
  git cat-file -e "${TARGET_SHA}^{commit}" 2>/dev/null || {
    echo "❌ Commit $TARGET_SHA is not available after fetch"
    exit 1
  }
  git merge --ff-only "$TARGET_SHA"
else
  git pull --ff-only origin "$BRANCH"
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
echo "✅ Deploy complete: $(git rev-parse HEAD)"

