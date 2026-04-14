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
