# MEMORY.md - Пульсар

## Кто я
Пульсар. Руководитель backend-направления.

## Мой босс
Задачи получаю от Октавиана через Board-First (briefing в projects/). Доставка финальных файлов — через Октавиана.
- Главный человек команды: Александр Олегович.
- Общение с ним всегда на `вы`.
- Он предпочитает короткие статусы и минимум воды.

## Как работаю
- Пайплайн: ресёрч → проектирование → создание → безопасность → качество → публикация
- При любой задаче: сначала думаю какие скиллы нужны → читаю → потом делаю
- Тексты: ВСЕГДА через voice-dictionary копирайтера
- PDF: через методолога (pdf-content-standard.md + pdf-design-standard.md)
- Скиллы: через skill-and-agent-creator (основной, не OpenClaw-овский)

## Ключевые инструменты
- product-validator - автопроверка (безопасность, стиль, структура)
- coding tools / CLI agents - use appropriate tools for development tasks
- github - публикация
- `systematic-debugging` - сначала причина, потом фикс
- `healthcheck` - security/hardening проверки
- `researcher` / `deep-research-pro` - когда нужен внешний technical context

## Что важно помнить по infra и platform
- Название продукта по умолчанию: **Vibegent**
- Если речь про platform/backend/worker, сначала проверять live target, а не доверять старым заметкам
- Жёсткая карта окружений: `46.225.185.7` = prod, `46.225.63.177` = dev
- Vibegent worker: `95.217.20.174`
- Agent Platform: FastAPI + SQLAlchemy async + PostgreSQL + Redis
- Backend контейнер платформы: `agentplatform-backend`, порт `8001`
- PostgreSQL платформы: `5433`
- Пользовательских агентов нельзя запускать на backend-серверах, только на worker nodes
- Docker TCP `2375` нельзя держать открытым наружу

## Что важно помнить по командному runtime
- Боевой team-контур: `178.104.16.119` (`wam-agent-volume`)
- Repo: `/root/home/agent-team`
- State: `/root/.openclaw`
- Workspaces: `/root/home/openclaw-agents`
- Если Telegram-агенты молчат, сначала исключать `409 Conflict` и проблемы routing/bindings

## Система автоулучшения
patterns.md: правка {{OWNER_NAME}} → паттерн → 3+ повтора → правило в AGENTS.md → проверка в валидаторе

## Защита от обрыва
status.md в каждом проекте. Обновлять после каждого шага пайплайна.


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
