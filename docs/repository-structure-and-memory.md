# Структура репозитория и память в agent-team

Этот файл отвечает на 4 практических вопроса:

1. Что хранится в repo
2. Что хранится только в live-runtime OpenClaw
3. Где лежит общая память команды
4. Как правильно переносить память, чтобы агенты перестали каждый раз узнавать всё заново

---

## Короткий ответ

Не совсем так: **не вся живая память агентов автоматически живёт в git-репозитории**.

Правильная картина такая:

- **repo `/root/home/agent-team`** хранит исходники команды:
  - роли агентов
  - шаблоны их файлов
  - общую safe-memory команды
  - scripts/setup/deploy/routing
  - skills
  - references

- **live-runtime OpenClaw** хранит уже установленную команду:
  - agent dirs в `~/.openclaw/agents/<agent>/agent`
  - live sessions в `~/.openclaw/agents/<agent>/sessions`
  - workspaces в `/root/home/openclaw-agents/<agent>`
  - runtime config в `~/.openclaw/openclaw.json`

То есть repo - это **source of truth для шаблонов и общей памяти**, а runtime - это **живая установленная команда**.

---

## Главная мысль

Если вы хотите, чтобы команда знала ваши проекты и контекст, то лучше всего держать это в **общем memory-layer в repo**, а потом раскатывать в установленную команду через `setup.sh`.

**Не надо** просто пытаться влить всю мою личную память как есть.
Нужен отдельный слой:

- безопасный
- operational
- project-aware
- без токенов, приватных переписок и лишнего мусора

---

# 1. Что где лежит

## 1.1. Корень repo

```text
/root/home/agent-team/
├── agents/
├── configs/
├── docs/
├── references/
├── scripts/
├── skills/
├── TEAM_MEMORY.md
├── TEAM_DECISIONS.md
├── TEAM_OPERATIONS.md
├── TEAM_INCIDENTS.md
├── team-config.sh
├── README.md
└── .env.example
```

---

## 1.2. `agents/` - шаблоны конкретных агентов

```text
agents/
├── orchestrator/
├── producer/
├── frontend/
├── backend/
├── tester/
├── design/
├── content/
├── media/
├── research/
└── admin/
```

В каждой папке агента лежат его исходные markdown-файлы.
Обычно это:

- `AGENTS.md` - как агент работает
- `SOUL.md` - характер и стиль
- `IDENTITY.md` - кто он такой
- `TOOLS.md` - локальные заметки и инструменты
- `MEMORY.md` - стартовая/долгая память агента
- `BOOTSTRAP.md` - что читать на старте
- `HEARTBEAT.md` - фоновые правила

Важно:
- это **шаблоны и repo-версия**
- после развёртывания они копируются в live-runtime

---

## 1.3. `TEAM_*.md` - общая память команды

Сейчас общий safe-layer уже заведён в repo:

- `TEAM_MEMORY.md`
- `TEAM_DECISIONS.md`
- `TEAM_OPERATIONS.md`
- `TEAM_INCIDENTS.md`

Это и есть правильное место для **общей памяти команды**.

### Что сюда класть

Сюда надо класть:
- ваши проекты
- продукты
- recurring-контекст
- принятые правила работы
- naming conventions
- инфраструктурные ориентиры без секретов
- принятые решения
- известные инциденты и грабли
- карту who-is-who

### Что сюда НЕ класть

Сюда нельзя класть:
- токены
- session strings
- auth profiles
- raw env
- SSH-ключи
- личные/private куски памяти, которые не надо видеть всей команде
- сырой мусор из всех диалогов подряд

То есть это должен быть **sanitized shared memory layer**.

---

## 1.4. `scripts/` - как repo раскатывается в живую команду

Главные файлы:

- `scripts/deploy-team.sh`
- `scripts/setup.sh`
- `scripts/render-openclaw-configs.sh`
- `scripts/configure-telegram-topics.sh`
- `scripts/start-team.sh`
- `scripts/stop-team.sh`

### Самое важное

#### `scripts/deploy-team.sh`
Создаёт live-workspaces в:

```text
/root/home/openclaw-agents/<agent>
```

И копирует туда agent markdown files из `agents/<agent>/`.

#### `scripts/setup.sh`
Регистрирует агентов в OpenClaw и копирует repo-файлы в:

```text
/root/.openclaw/agents/<agent>/agent
```

Также `setup.sh` копирует туда **весь `TEAM_*.md` pack**.

Это важно: значит shared-layer уже встроен в deploy-цепочку.

---

## 1.5. `team-config.sh` - единый состав команды

Это один из главных файлов repo.

Тут задаётся:
- список agent ids
- имена агентов
- orchestrator id
- базовые пути

Сейчас команда такая:

- `orchestrator` - Октавиан
- `producer` - Темп
- `frontend` - Лея
- `backend` - Пульсар
- `tester` - Калибр
- `design` - Сеть
- `content` - Глас
- `media` - Блик
- `research` - Радар
- `admin` - Баланс

Если вы добавляете новых агентов, почти всегда начинать надо отсюда.

---

## 1.6. `references/` - общие документы команды

Тут лежат общие reference-файлы.
Например:

- `team-constitution.md`
- `team-board.md.example`
- `briefing-template.md`
- `production-safety-standard.md`

Это не память в прямом смысле, а скорее общая нормативка и шаблоны работы.

---

## 1.7. `skills/` - общая библиотека навыков

Тут лежат shared skills команды.
Это не личная память, а библиотека поведения.

Если хотите, чтобы агент умел что-то делать, это чаще вопрос `skills/`.
Если хотите, чтобы агент **знал ваш контекст**, это чаще вопрос `TEAM_*.md` и `agents/*/MEMORY.md`.

На текущем `agent-team` это уже отдельный слой, и в repo есть библиотека из десятков shared skills.

## 1.8. Plugins и live capabilities

Тут важно не путать 2 вещи:

- `skills/` в repo - это поведенческий и procedural layer
- plugins/runtime capabilities в OpenClaw - это то, чем контур реально может пользоваться вживую

На практике у команды есть такие runtime-слои:
- Telegram multi-account
- group topic routing
- cross-agent delegation через `sessions_send`
- memory layer (`memory-core`)
- OpenAI/Codex runtime (`gpt-5.4`)

То есть:
- **skills** отвечают за то, как агент думает и выполняет задачу
- **plugins/runtime** отвечают за то, какие внешние и системные возможности у него вообще есть

---

# 2. Что лежит в live-runtime, а не в repo

После развёртывания команда живёт не только в repo.

## 2.1. Agent dirs OpenClaw

```text
~/.openclaw/agents/<agent>/agent
```

Там лежат установленные agent files, которые OpenClaw реально читает как agent-dir.

## 2.2. Live workspaces

```text
/root/home/openclaw-agents/<agent>
```

Там лежит workspace агента, который уже может меняться по ходу жизни.

## 2.3. Sessions

```text
~/.openclaw/agents/<agent>/sessions
```

Тут хранится живая история сессий, и это **не repo-слой**.

## 2.4. Runtime config

```text
~/.openclaw/openclaw.json
```

Это живой конфиг контура.
Он не равен repo 1:1, потому что часть вещей туда рендерится и может меняться runtime-ом.

---

# 3. Где именно сейчас общая память

Если говорить про **правильное место для общей памяти в agent-team**, то это:

```text
/root/home/agent-team/TEAM_MEMORY.md
/root/home/agent-team/TEAM_DECISIONS.md
/root/home/agent-team/TEAM_OPERATIONS.md
/root/home/agent-team/TEAM_INCIDENTS.md
```

Именно туда и нужно переносить общий проектный и операционный контекст.

Плюс:
- `BOOTSTRAP.md` агентов уже велит читать этот shared-layer
- `setup.sh` уже умеет этот shared-layer копировать в установленную команду

То есть база для общей памяти **уже сделана**.

---

# 4. Где изолированная память каждого агента

У каждого агента остаётся свой отдельный слой:

- `agents/<agent>/MEMORY.md` в repo как исходный шаблон
- live-копия в runtime после deploy/setup
- плюс сессии и локальные рабочие файлы агента

Это нужно, чтобы:
- backend не жил в памяти content
- tester не засорял память design
- orchestrator не смешивал всё в одну кучу

Общая память и изолированная память должны существовать одновременно.

---

# 5. Как правильно переносить память

Если коротко: **не копипастить всю личную память как есть**, а собрать её в 3 слоя.

## Слой 1. Shared team memory
Класть в `TEAM_*.md`.

Это то, что должны знать почти все:
- кто вы
- какие у вас проекты
- как называются продукты
- какие есть сервера/контуры
- какие приняты решения
- какие recurring-задачи важны
- как общаться и что считать приоритетом

## Слой 2. Role-specific memory
Класть в `agents/<agent>/MEMORY.md`.

Например:
- backend знает детали API, infra, DB, deploy
- content знает tone of voice, контентные форматы, рубрики
- tester знает acceptance criteria, чек-листы и known bugs

## Слой 3. Live operational memory
Остаётся в runtime и сессиях.

Это текущее живое состояние агента.
Оно не должно целиком жить в repo автоматически.

---

# 6. Практический ответ на ваш вопрос

## Да, в repo удобно настраивать:
- состав команды
- роли агентов
- общую память
- шаблоны их памяти
- bootstrap/read order
- skills
- references
- deploy/setup/routing

## Но нет, не вся живая память автоматом сидит в repo:
- live sessions не в repo
- runtime state не в repo
- часть локальных изменений после запуска тоже не в repo, пока вы специально их не синхронизируете

Поэтому правильная стратегия такая:

1. **делаем repo source-of-truth для общей памяти**
2. переносим туда нужный shared context в `TEAM_*.md`
3. при необходимости усиливаем `agents/*/MEMORY.md` роль-специфичными блоками
4. запускаем `setup.sh`, чтобы это раскатилось в установленную команду

---

# 7. Что лучше сделать прямо сейчас

Если ваша цель - чтобы команда перестала тупить и всё время спрашивать одно и то же, то следующий лучший шаг:

## Обязательно
1. привести `TEAM_MEMORY.md` в нормальный подробный вид
2. вынести в `TEAM_DECISIONS.md` все важные проектные решения
3. вынести в `TEAM_OPERATIONS.md` инфраструктуру и runbook
4. вынести в `TEAM_INCIDENTS.md` ключевые прошлые поломки и грабли

## Потом
5. дозаполнить `agents/backend/MEMORY.md`, `agents/content/MEMORY.md`, `agents/tester/MEMORY.md` профильными знаниями
6. прогнать `bash scripts/setup.sh`
7. проверить в новой сессии, что агенты реально подхватывают shared-layer

---

## 8.1. Похоже ли это на reference-команду

Да, по сути принцип тот же:
- есть входная точка
- есть профильные агенты
- есть общий слой памяти
- есть отдельная память по ролям
- есть runtime state, который живёт отдельно от repo

Но текущий `agent-team` не обязан быть 1:1 копией reference-репозитория.
Он уже адаптирован под production-работу.

Ключевые отличия сейчас такие:
- добавлен отдельный `producer` как coordination layer между входом и исполнителями
- добавлен отдельный `tester`
- добавлен отдельный `admin` под admin/finance/ops-контур
- часть best practices reference уже встроена, но не всё оформлено как board-first workflow
- некоторые reference-роли у нас схлопнуты в более практичные production-роли

Правильный подход такой:
- брать из reference принципы и best practices
- переносить в `agent-team` только то, что реально улучшает работу
- не копировать механически роли и структуру без необходимости

# 8. Самая короткая формула

Если совсем по-простому:

- **TEAM_*.md** = общая память команды
- **agents/*/MEMORY.md** = память по роли
- **~/.openclaw/agents/** и **/root/home/openclaw-agents/** = live установленная команда
- **sessions/** = живая история, не repo
- **repo** = место, где это удобно редактировать руками как source-of-truth

Именно так это и стоит использовать.
