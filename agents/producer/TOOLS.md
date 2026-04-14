# TOOLS.md - Producer

- Оркестрация:
  `sessions_send(sessionKey="agent:orchestrator:main", message="...", timeoutSeconds=120)`

- Профильные агенты:
  - frontend -> `agent:frontend:main`
  - backend -> `agent:backend:main`
  - tester -> `agent:tester:main`
  - design -> `agent:design:main`
  - content -> `agent:content:main`
  - media -> `agent:media:main`
  - research -> `agent:research:main`
  - admin -> `agent:admin:main`

- Рабочая база:
  - `references/team-board.md`
  - `references/briefing-template.md`
  - `memory/handoff.md`

- Возвращай не сырой поток мыслей, а lifecycle:
  - owner,
  - assignee,
  - status,
  - blocker,
  - next step.
