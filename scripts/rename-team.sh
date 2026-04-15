#!/usr/bin/env bash
# rename-team.sh — rename/migrate agent ids in repository artifacts
# Use:
#   bash scripts/rename-team.sh --plan
#   TEAM_RENAME_MAP='old1:new1,old2:new2' bash scripts/rename-team.sh --apply

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_DIR/team-config.sh"

AGENTS_DIR="$REPO_DIR/agents"
CONFIGS_DIR="$REPO_DIR/configs"
DRY_RUN=true
RENAME_CONFIGS=true
RENAME_DIRS=true
REWRITE_CONTENT=false
VERBOSE=true
APPLY=false

usage() {
  cat <<'EOF'
Usage:
  rename-team.sh [--plan|--apply] [--map "old:new,old2:new2"] [--no-configs] [--no-dirs]

Options:
  --plan        Show migration plan only (default)
  --apply       Perform filesystem renames
  --map         Comma-separated old->new mapping, e.g. "orchestrator:lead,frontend:ui"
                If omitted, TEAM_RENAME_MAP env var is used.
  --no-configs      Skip renaming config examples in configs/
  --no-dirs         Skip renaming agent folders in agents/
  --rewrite-content Rewrite AGENTS.md/TOOLS.md/README-like references by replacing old ids inside text files
  --quiet       Less output (still prints summary)
EOF
}

parse_args() {
  MAP_INPUT=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --plan)
        DRY_RUN=true
        APPLY=false
        shift
        ;;
      --apply)
        APPLY=true
        DRY_RUN=false
        shift
        ;;
      --map)
        MAP_INPUT="$2"
        shift 2
        ;;
      --no-configs)
        RENAME_CONFIGS=false
        shift
        ;;
      --no-dirs)
        RENAME_DIRS=false
        shift
        ;;
      --rewrite-content)
        REWRITE_CONTENT=true
        shift
        ;;
      --quiet)
        VERBOSE=false
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        echo "Unknown arg: $1"
        usage
        exit 1
        ;;
    esac
  done

  if [ -z "$MAP_INPUT" ] && [ -n "${TEAM_RENAME_MAP:-}" ]; then
    MAP_INPUT="$TEAM_RENAME_MAP"
  fi
}

log() {
  if [ "$VERBOSE" = true ]; then
    echo "$@"
  fi
}

split_pairs() {
  local src="$1"
  IFS=',' read -r -a PAIRS <<< "$src"
}

contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}

read_team_agents() {
  TARGET_AGENTS=()
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      TARGET_AGENTS+=("$line")
    fi
  done < <(team_agent_ids)
}

read_team_agents
TEAM_AGENT_COUNT_CONF="${#TARGET_AGENTS[@]}"

read_current_agents() {
  CURRENT_AGENTS=()
  for d in "$AGENTS_DIR"/*; do
    [ -d "$d" ] || continue
    CURRENT_AGENTS+=("$(basename "$d")")
  done
  local current_sorted=""
  local line
  current_sorted="$(printf '%s\n' "${CURRENT_AGENTS[@]}" | sort)"
  CURRENT_AGENTS=()
  while IFS= read -r line; do
    [ -n "$line" ] && CURRENT_AGENTS+=("$line")
  done <<< "$current_sorted"
}

check_id() {
  local candidate="$1"
  if [ -z "$candidate" ]; then
    return 1
  fi
  case "$candidate" in
    *" "*) return 1;;
  esac
  return 0
}

validate_current_config_match() {
  read_current_agents
  if [ "${#CURRENT_AGENTS[@]}" -eq 0 ]; then
    echo "❌ Нет папок в $AGENTS_DIR"
    return 1
  fi

  if [ "$VERBOSE" = true ]; then
    echo "📂 Текущие папки agents/: ${CURRENT_AGENTS[*]}"
  fi
}

build_default_map_if_possible() {
  if [ -n "$MAP_INPUT" ]; then
    return 1
  fi

  if [ "${#CURRENT_AGENTS[@]}" -ne "${#TARGET_AGENTS[@]}" ]; then
    return 1
  fi

  for agent in "${CURRENT_AGENTS[@]}"; do
    if ! contains "$agent" "${TARGET_AGENTS[@]}"; then
      return 1
    fi
  done

  # identity mapping when current equals target
  MAP_OLD=()
  MAP_NEW=()
  for agent in "${TARGET_AGENTS[@]}"; do
    MAP_OLD+=("$agent")
    MAP_NEW+=("$agent")
  done
  return 0
}

parse_rename_map() {
  if [ -z "$MAP_INPUT" ]; then
    echo "❌ Не задан маппинг. Передай --map или TEAM_RENAME_MAP."
    return 1
  fi

  split_pairs "$MAP_INPUT"

  MAP_OLD=()
  MAP_NEW=()
  DUP_CHECK=()

  for pair in "${PAIRS[@]}"; do
    [ -z "$pair" ] && continue
    old_id="$(printf '%s' "${pair%%:*}" | sed 's/^ *//;s/ *$//')"
    new_id="$(printf '%s' "${pair#*:}" | sed 's/^ *//;s/ *$//')"

    if [ "$old_id" = "$pair" ] || [ -z "$new_id" ]; then
      echo "❌ Неверный формат пары: $pair (нужно old:new)"
      return 1
    fi
    if ! check_id "$old_id" || ! check_id "$new_id"; then
      echo "❌ Некорректный id в паре: $pair"
      return 1
    fi

    MAP_OLD+=("$old_id")
    MAP_NEW+=("$new_id")
    DUP_CHECK+=("$new_id")
  done

  # target id collision check
  if [ "${#MAP_NEW[@]}" -ne "$(printf '%s\n' "${DUP_CHECK[@]}" | sort -u | wc -l | tr -d ' ')" ]; then
    echo "❌ Дубликаты целевых id в маппинге"
    return 1
  fi

  if [ "${#MAP_OLD[@]}" -eq 0 ]; then
    echo "❌ Пустой маппинг"
    return 1
  fi

  if [ "${#MAP_OLD[@]}" -ne "${#MAP_NEW[@]}" ]; then
    echo "❌ Несогласованные списки старых и новых id"
    return 1
  fi

  return 0
}

validate_map() {
  local i src dst
  local missing=0

  for i in "${!MAP_OLD[@]}"; do
    src="${MAP_OLD[$i]}"
    dst="${MAP_NEW[$i]}"

    if [ "$src" = "$dst" ]; then
      continue
    fi
    if ! contains "$src" "${CURRENT_AGENTS[@]}"; then
      echo "⚠️  Исходный id '$src' не найден в agents/."
      missing=$((missing + 1))
    fi
    if contains "$dst" "${TARGET_AGENTS[@]}"; then
      # allowed if this is final target id
      continue
    fi
    echo "⚠️  Целевой id '$dst' не входит в TEAM_AGENT_IDS"
  done

  if [ "$missing" -gt 0 ] && [ "$PLAN_ONLY" -eq 1 ]; then
    echo "❌ В map есть невалидные исходные id — применить нельзя."
    return 1
  fi
}

rename_entry() {
  local src_path="$1"
  local dst_path="$2"
  local name="$3"

  if [ ! -e "$src_path" ]; then
    echo "  ⏭️  skip: $src_path (not found)"
    return 0
  fi
  if [ "$src_path" = "$dst_path" ]; then
    echo "  ✅ keep: $name"
    return 0
  fi
  if [ -e "$dst_path" ]; then
    echo "  ⚠️  skip: $dst_path already exists"
    return 1
  fi

  if [ "$APPLY" = true ]; then
    mv "$src_path" "$dst_path"
    echo "  ✓ moved: $name"
  else
    echo "  - would move: $src_path -> $dst_path"
  fi
}

replace_file_contents() {
  local path="$1"
  local i

  for i in "${!MAP_OLD[@]}"; do
    local old_id="${MAP_OLD[$i]}"
    local new_id="${MAP_NEW[$i]}"
    if [ "$old_id" = "$new_id" ]; then
      continue
    fi
    sed -i '' "s/\\b$old_id\\b/$new_id/g" "$path" 2>/dev/null || \
    sed -i "s/\\b$old_id\\b/$new_id/g" "$path"
  done
}

update_contents() {
  local base_dir="$1"
  local include_globs="*.md"
  find "$base_dir" -type f -name "$include_globs" -print0 | while IFS= read -r -d '' f; do
    [ -f "$f" ] || continue
    replace_file_contents "$f"
  done
}

PLAN_ONLY=0
if [ "$DRY_RUN" = true ] && [ "$APPLY" = false ]; then
  PLAN_ONLY=1
fi

parse_args "$@"

validate_current_config_match

if ! build_default_map_if_possible; then
  if ! parse_rename_map; then
    echo ""
    echo "ℹ️  Текущие папки в agents/: ${CURRENT_AGENTS[*]}"
    echo "ℹ️  Конфиг TEAM_AGENT_IDS: ${TARGET_AGENTS[*]}"
    echo ""
    echo "Чтобы выполнить переименование, задай --map или TEAM_RENAME_MAP."
    echo "Пример: TEAM_RENAME_MAP='orchestrator:oktagon,frontend:leya' bash scripts/rename-team.sh --apply"
    exit 1
  fi
else
  MAP_OLD=("${TARGET_AGENTS[@]}")
  MAP_NEW=("${TARGET_AGENTS[@]}")
fi

if ! validate_map; then
  exit 1
fi

echo "🎯 Команда из config: ${TARGET_AGENTS[*]}"
if [ "$PLAN_ONLY" -eq 1 ]; then
  echo "📋 План:"
else
  echo "⚠️  Применение:"
fi

if [ "$RENAME_DIRS" = true ]; then
  for i in "${!MAP_OLD[@]}"; do
    src="${MAP_OLD[$i]}"
    dst="${MAP_NEW[$i]}"
    rename_entry "$AGENTS_DIR/$src" "$AGENTS_DIR/$dst" "agents/$src → agents/$dst"
  done
fi

if [ "$RENAME_CONFIGS" = true ]; then
  for i in "${!MAP_OLD[@]}"; do
    src="${MAP_OLD[$i]}"
    dst="${MAP_NEW[$i]}"
    rename_entry "$CONFIGS_DIR/${src}.openclaw.json.example" "$CONFIGS_DIR/${dst}.openclaw.json.example" "configs/${src}.openclaw.json.example → configs/${dst}.openclaw.json.example"
  done
fi

if [ "$PLAN_ONLY" -ne 1 ] && [ "$APPLY" = true ] && [ "$REWRITE_CONTENT" = true ]; then
  echo ""
  echo "🧹 Пробегаю тексты для замены id:"
  update_contents "$AGENTS_DIR"
  update_contents "$SCRIPT_DIR"
  update_contents "$CONFIGS_DIR"
  echo "  ✓ Replaced IDs in .md files under agents/, scripts/, configs/"
fi

echo ""
if [ "$PLAN_ONLY" -eq 1 ]; then
  echo "✅ План сформирован. Запусти с --apply для применения."
else
  echo "✅ rename-team завершён."
fi
