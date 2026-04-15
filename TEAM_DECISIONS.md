# TEAM_DECISIONS.md

Ключевые рабочие решения команды. Только то, что влияет на действия агентов.

## Архитектурные решения
- Team-деплой работает на стандартном OpenClaw profile `default`, а не на `personal`.
- State dir team-контура: `/root/.openclaw`.
- Agent workspaces team-контура: `/root/home/openclaw-agents`.
- Default agent: `orchestrator`.
- Для новой установки не использовать занятый `/root/.openclaw` на `46.225.161.230` как базу под чистый team-deploy.

## Telegram routing
- Для multi-account Telegram обязательны и `channels.telegram.accounts.<agent>`, и top-level `bindings`.
- Если боты молчат, сначала проверять `409 Conflict` и второй polling-контур, а не только bindings.
- Для OpenClaw `2026.4.12+` хранить `topics` как object с string-key topic ids.
- Для `2026.4.12+` использовать новый nested-формат `streaming.*`, не legacy scalar `streaming`.

## Ops-решения
- На server/infra задачах сначала проверять `hostname` и публичный IP, только потом менять систему.
- На живом контуре сначала read-only диагностика, потом правки.
- Если удалённый файл мог дрейфовать, сначала читать/синхронизировать актуальное состояние, потом редактировать.
- Все проектные директории держать только в `/root/home/`.
- Принято team-wide правило 2 минут: если задача выглядит длиннее 2 минут или есть риск длинного синхронного зависания, user-facing агент обязан быстро дать стартовый ответ и вынести исполнение в subagent, background run или профильного owner-agent.
- Держать пользователя в молчаливом foreground-ожидании ради длинной проверки, аудита или оркестрации запрещено, если это можно сделать в фоне.

## Memory-sharing policy
- Команде можно давать только operational/project memory.
- Нельзя раздавать `SOUL.md`, чувствительные части `USER.md`, токены, auth profiles, raw env, chat ids и сырую личную память.
- Общий safe-layer команды хранить в `TEAM_*.md` файлах внутри agent workspaces.
- Source-of-truth для общей памяти команды — repo-layer `TEAM_*.md`, а не raw session history.
- Личную память переносить в команду только после sanitization и раскладывания по слоям: shared team memory, role-specific memory, live runtime memory.

## Repo and rollout policy
- Repo `/root/home/agent-team` считается главным местом для ручной правки общей памяти, ролей, skills и operational docs.
- После изменения общей памяти или role memory нужно прогонять `bash scripts/setup.sh`, чтобы curated слой гарантированно доехал в live agent dirs.
- `TEAM_*.md` — общий контекст для всех агентов, `agents/<agent>/MEMORY.md` — роль-специфичный контекст.
- Не пытаться использовать сырые `sessions/` как основной knowledge-base команды: это шумный runtime-слой, а не curated memory.

## Skills and capabilities
- Общая библиотека skills хранится в `skills/` внутри repo и считается shared capability layer для всей команды.
- Source-of-truth для shared skills: `/root/home/agent-team/skills`.
- Если задача матчится на skill, использование skill обязательно: просканировать descriptions, выбрать самый специфичный match, открыть `SKILL.md`, затем выполнять работу.
- Нельзя ограничиваться декларацией, что skill «учтён». Требуется фактическое использование по шагам skill.
- Самые важные capability-кластеры команды: research, docs, content, automation, quality/security, planning, browser/web work.
- При расширении команды сначала переносить знания в curated memory и skills layer, а уже потом добавлять новых агентов, иначе новые роли будут такими же "пустыми" по контексту.
- Для Vibegent core baseline skills: `ru-text` и self-improvement layer (исторически `self-improving-agent`, в team library сейчас `self-improvement`).
- Для хорошего Telegram UX нельзя полагаться только на skills, нужны ещё runtime/prompt rules: ранний ACK, компактный self-closing ответ, без простыней и без burst из нескольких сообщений.
