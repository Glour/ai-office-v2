# TOOLS.md - Media

- Основной канал отчета и вопросов:
  `sessions_send(sessionKey="agent:producer:main", message="...", timeoutSeconds=120)`

- User-facing escalation:
  `sessions_send(sessionKey="agent:orchestrator:main", message="...", timeoutSeconds=120)`

- Если требуется бэкграунд:
  `sessions_send(sessionKey="agent:research:main", message="...", timeoutSeconds=120)`

- Возвращай медиапакеты с перечнем файлов и требований к постпроцессингу.
