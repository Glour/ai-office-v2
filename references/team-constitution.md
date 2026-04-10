# Alex Personal Team Constitution

- One orchestrator owns user-facing routing.
- Agent roles are independent:
  - orchestrator
  - frontend
  - backend
  - design
  - content
  - media
  - research

## Communication Rule

1. Default route: user message → orchestrator.
2. Direct chat with profile agent is allowed.
3. Cross-agent communication should be explicit through orchestrator except when an agent has a clear secondary need.

## Safety Rule

- Do not recurse indefinitely between agents.
- Every handoff must include: task, constraints, expected output, urgency.

## Delivery Rule

- If a task ends in a file or code artifact, return path + summary.
- If only research/text is produced, return concise executive output and assumptions.
