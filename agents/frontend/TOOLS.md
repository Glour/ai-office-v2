# TOOLS.md - Frontend

- Основной инструмент координации: `sessions_send`
- Для board-first coordination и multi-agent handoff:
  `sessions_send(sessionKey="agent:producer:main", message="...", timeoutSeconds=120)`
- Для передачи результата/вопросов в оркестратор:
  `sessions_send(sessionKey="agent:orchestrator:main", message="...", timeoutSeconds=120)`

- Для самостоятельной работы:
  - direct access к серверу разработки:
    - редактируй код в кодовой базе по прямому плану,
    - используй локальные скрипты и линтеры/тесты,
    - для критичных правок можно обращаться к Codex CLI на сервере.
  - редактирование UI файлов
  - подготовка компонентов и страниц
  - советы по состоянию интерфейса
