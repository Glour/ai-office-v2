#!/bin/bash
# claude-usage.sh — Скриншот лимитов Claude через Comet браузер на Mac Mini
# Использование: bash scripts/claude-usage.sh
# Результат: /tmp/claude-usage-latest.png

set -e

if [[ "$OSTYPE" != "darwin"* ]]; then
  echo "⚠️  This script requires macOS (uses osascript for UI automation)"
  echo "On Linux/WSL, check Claude usage at: https://console.anthropic.com/usage"
  exit 0
fi

# 1. Активировать Comet (там открыта вкладка claude.ai/settings/usage)
osascript -e 'tell application "Comet" to activate' 2>/dev/null

# 2. Подождать пока окно отрисуется
sleep 2

# 3. Обновить страницу (Cmd+R) чтобы данные были свежие
osascript -e 'tell application "System Events" to keystroke "r" using command down' 2>/dev/null
sleep 3

# 4. Скриншот
/usr/sbin/screencapture -x /tmp/claude-usage-latest.png

# 5. Убрать Comet обратно
osascript -e 'tell application "System Events" to tell process "Comet" to set visible to false' 2>/dev/null

echo "✅ Скриншот: /tmp/claude-usage-latest.png"
