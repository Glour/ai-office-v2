# TEAM_INCIDENTS.md

Короткая память по важным инцидентам и already-paid lessons.

## Telegram polling conflict
- Симптом: агенты в Telegram перестают отвечать, хотя routing вроде настроен.
- Реальная причина, которая уже встречалась: второй живой контур поллит те же bot tokens и вызывает `409 Conflict: terminated by other getUpdates request`.
- Что проверять первым: нет ли конкурирующего OpenClaw/gateway на другом сервере или профиле.
- Исторический кейс: конфликт шёл не с `46.225.161.230`, а со старого personal-контура на `46.225.63.177`.

## OpenClaw 2026.4.12 config breakage
- Симптом: после апдейта config validation падает на Telegram `topics`.
- Реальная причина: исторически `topics` были сохранены как sparse list, а новая версия требует object.
- Что делать: мигрировать `topics` list -> object и после этого перепроверить routing.

## Team setup on upgraded OpenClaw
- Симптом: `configure-telegram-topics.sh` падает на config validation.
- Реальная причина, которая уже ловилась: script писал legacy scalar `streaming`, а не `streaming.mode`.
- Правильное состояние: использовать nested streaming keys и при необходимости запускать `doctor --fix` перед routing.

## Occupied host trap
- Симптом: кажется, что сервер подходит под новый deploy, потому что на нём есть OpenClaw.
- Реальная причина риска: на хосте уже может жить чужой state, workspace, sessions и Telegram routing.
- Исторический кейс: `46.225.161.230` (`wam-agent-dev`) оказался занятым WAM-контуром, поэтому reuse его `/root/.openclaw` признан опасным.

## Shared-memory drift
- Симптом: repo уже обновлён, но агенты продолжают вести себя так, как будто не знают новых фактов.
- Реальная причина: `TEAM_*.md` и `agents/*/MEMORY.md` обновлены только в repo, но live agent dirs не были пересинхронизированы.
- Что делать: после изменения curated memory прогонять `bash scripts/setup.sh`, а для критичных кейсов дополнительно перепроверять новые сессии у нужных агентов.

## Pairing required / stale device auth
- Симптом: `sessions_spawn`, `sessions_send` или межагентные операции падают с `pairing required`.
- Реальная причина, которая уже встречалась: stale device auth и урезанный scope set у локального `gateway-client`.
- Что помогало: обновить paired scope baseline, выпустить новый full-scope токен через `openclaw devices rotate`, синхронизировать `device-auth.json`, убрать stale pending repair.

## Dual workspace roots / stale main trap
- Симптом: диагностика показывает странный состав workspaces или лишнего агента.
- Реальная причина: на team host одновременно присутствуют `/root/openclaw-agents` и `/root/home/openclaw-agents`, плюс в `/root/.openclaw/agents` может болтаться stale `main`.
- Что делать: сначала разделять repo truth, state dir truth, workspace root truth и stale leftovers, иначе легко чинить не тот слой.

## Vibegent agent silence from sandbox/runtime mismatch
- Симптом: Vibegent-агенты молчат или падают, хотя routing вроде настроен.
- Реальная причина, которая уже ловилась: `sandbox.mode = all` внутри agent containers без нормального Docker/runtime окружения.
- Что делать: проверять runtime/sandbox/config, а не только routing.

## Telegram UX fragmentation
- Симптом: агент отвечает слишком длинно, плохо форматирует текст или дробит один ответ на несколько Telegram-сообщений.
- Реальная причина, которая уже встречалась: `partial` streaming плюс слабые output rules и session bloat.
- Что помогало: выключать `streaming` в `off`, добавлять Telegram Output Discipline, затем перезапускать контур и смотреть live logs.

## Owner-return gap after fire-and-forget delegation
- Симптом: профильный агент сделал результат, но пользователь не получил его автоматически и вынужден пинговать owner вручную.
- Реальная причина: owner отправил задачу через `sessions_send(..., timeoutSeconds=0)` и ожидал, что child completion сам вернётся в user thread. Этот path fire-and-forget и не даёт completion announce обратно владельцу/пользователю.
- Усиливающий фактор: stale live agent package в `/root/.openclaw/agents/<agent>/agent` может оставлять старые routing rules даже когда workspace уже обновлён.
- Что делать: для user-facing async handoff использовать `sessions_spawn(agentId="...")` или owner flow через `producer`; `sessions_send timeout=0` оставлять только для internal fire-and-forget. После изменения source-of-truth синхронизировать live agent dirs.
