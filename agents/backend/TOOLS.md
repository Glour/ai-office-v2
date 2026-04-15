# TOOLS.md - Backend

- Координация через `producer` для multi-step и board-first задач:
  `sessions_send(sessionKey="agent:producer:main", message="...", timeoutSeconds=120)`

- Прямая эскалация в оркестратор для single-hop случаев:
  `sessions_send(sessionKey="agent:orchestrator:main", message="...", timeoutSeconds=120)`

- Прямой ответ в Telegram-topic происходит автоматически только в topic-сессии Telegram.
- Во внутренней `main`-сессии не пытайся публиковать ответ в Telegram через `sessions_send`.

- У разработки backend-пути:
  - прямой доступ к коду разрешен,
  - допускается запуск сборки, тестов, миграций и проверок в workspace,
  - для сложных правок используем серверный Codex CLI по задаче и отдаём дифф/результат в отчёте.

- Передавай только:
  - технические ограничения,
  - зависимости,
  - ожидаемые артефакты.
