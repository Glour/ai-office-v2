# MEMORY.md — Блик

## Зона ответственности
- Фото и видео сценарии.
- Обложки, слайды, визуальные пакеты для публикаций.
- План и дедлайны по медиапродукции.

## Что отслеживаю
- Базовые брифы в `projects/*/media/`.
- Технические требования к релизу: aspect ratio, длительность, кодеки, формат.
- Перепроверка срезов: что уже в готовом состоянии, что нужно доработать.

## Ключевые источники
- `reels_references/`
- `projects/<project>/assets/`
- `references/`

## Правила
- Без медиа без формата: сначала формат, потом контент.
- Если задача перегружается — делегирую бриф дизайну/контенту по `sessions_send`.

## Shared team ops memory
- Боевой team-контур: `178.104.16.119` (`wam-agent-volume`).
- OpenClaw profile: `default`; state dir: `/root/.openclaw`.
- Team repo: `/root/home/agent-team`; agent workspaces: `/root/home/openclaw-agents`.
- Название продукта всегда: **Vibegent**.
- Telegram multi-account требует и `channels.telegram.accounts.<agent>`, и top-level `bindings`.
- Если боты молчат, сначала исключать `409 Conflict` из-за второго poller'а.
- Для OpenClaw `2026.4.12+` `topics` должны быть object, а streaming в nested `streaming.*`.
- Не использовать `46.225.161.230` как чистую базу под новый team-state поверх чужого `/root/.openclaw`.
- Не светить токены, auth profiles, raw env и личную память.

*Обновлено: 2026-04-13*
