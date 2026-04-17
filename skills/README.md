# Skills Library

42 shared skills available to all agents.

## How Skills Work

1. Agent receives a task
2. Scans skill descriptions for the best match
3. Reads `SKILL.md` for step-by-step instructions
4. Executes following the skill's protocol

## Source of Truth

- Baseline catalog: this `README.md`
- Installed skills: one folder per skill under this directory
- For imported ClawHub skills, install by slug directory name and keep package files together

## Current Catalog

| Skill | Description |
|---|---|
| `agent-doctor` | Комплексная самодиагностика OpenClaw агента: память, кроны, конфиг, gateway, система и безопасность. |
| `audit-website` | Аудит веб-сайтов и лендингов по SEO, производительности, безопасности, контенту, доступности. Используй когда нужно проверить сайт, найти проблемы, подготовить чеклист для улучшения. Триггеры: 'проверь сайт', 'аудит сайта', 'audit website', 'что не так с сайтом', 'SEO проверка', 'проверь лендинг'. |
| `blogwatcher` | Monitor blogs and RSS/Atom feeds for updates using the blogwatcher CLI. Use when user wants to track blog updates, check RSS feeds, monitor websites for new posts. Triggers on 'блог', 'rss', 'feed', 'новые посты', 'мониторинг блога'. |
| `brainstorming` | Структурированный мозговой штурм перед любой творческой работой. Используй ПЕРЕД созданием контента, скилов, автоматизаций, проектов. Триггеры: 'давай подумаем', 'мозговой штурм', 'brainstorm', 'придумай', 'нужна идея', 'как лучше сделать', 'варианты'. |
| `browser-use-api` | Cloud browser automation via Browser Use API. Use when you need AI-driven web browsing, scraping, form filling, or multi-step web tasks without local browser control. Triggers on "browser use", "cloud browser", "scrape website", "automate web task", or when local browser isn't available/suitable. |
| `byterover` | Manages project knowledge using ByteRover context tree. Provides two operations: query (retrieve knowledge) and curate (store knowledge). Invoke when user requests information lookup, pattern discovery, or knowledge persistence. Developed by ByteRover Inc. (https://byterover.dev/) |
| `channel-analyzer` | Анализатор Telegram каналов через юзербот. Посты, комментарии, реакции, просмотры, выводы. Triggers: 'проанализируй канал', 'что в платной группе', 'что пишут подписчики', 'посмотри канал', 'анализ канала', 'что нового в канале', 'комментарии в канале'. |
| `cursor-agent` | A comprehensive skill for using the Cursor CLI agent for various software engineering tasks (updated for 2026 features, includes tmux automation guide). Use when user wants to run Cursor agent, code with Cursor, or automate development tasks via Cursor CLI. |
| `deep-research-pro` | Multi-source deep research agent. Searches the web, synthesizes findings, and delivers cited reports. |
| `excalidraw` | Создание схем и диаграмм в Excalidraw для Obsidian. Use when user says 'сделай схему', 'нарисуй диаграмму', 'excalidraw', 'схема в obsidian', 'визуализация'. |
| `excel-xlsx` | Create, inspect, and edit Microsoft Excel workbooks and XLSX files with reliable formulas, dates, types, formatting, recalculation, and template preservation. Use when (1) the task is about Excel, `.xlsx`, `.xlsm`, `.xls`, `.csv`, or `.tsv`, (2) formulas, formatting, workbook structure, or compatibility matter, (3) the file must stay reliable after edits. |
| `frontend-design-3` | Create distinctive, production-grade frontend interfaces with high design quality. Use this skill when building web components, pages, or applications. Generates creative, polished code that avoids generic AI aesthetics. |
| `frontend-design-ultimate` | Create distinctive, production-grade static sites with React, Tailwind CSS, and shadcn/ui, no mockups needed. Generates bold, memorable designs from plain text requirements with anti-AI-slop aesthetics, mobile-first responsive patterns, and single-file bundling. Supports both Vite and Next.js workflows. |
| `gemini` | Gemini CLI for one-shot Q&A, summaries, and generation. Use when user mentions 'gemini', 'ask gemini', 'gemini cli', or needs a quick answer from Google's model. |
| `github-publisher` | Публикация проектов на GitHub в едином стиле. README (EN+RU), чеклист, валидация файлов. Используй ВСЕГДА при создании/обновлении GitHub-репозиториев. Triggers: 'github', 'опубликуй', 'создай репо', 'readme', 'выложи на гитхаб'. |
| `gog` | Google Workspace CLI for Gmail, Calendar, Drive, Contacts, Sheets, and Docs. Use when user asks about email, calendar events, Google Drive files, contacts, spreadsheets. Triggers on 'почта', 'gmail', 'календарь', 'calendar', 'google drive', 'контакты', 'таблица', 'sheets'. |
| `graphic-design` | Support design understanding from basic visuals to professional production and theory. |
| `healthcheck` | Host security hardening and system health checks for OpenClaw deployments. |
| `landing-builder` | Генератор одностраничных HTML лендингов на Tailwind CSS с продающей структурой и готовым output без сборки. |
| `last30days` | Research a topic from the last 30 days on Reddit + X + Web, become an expert, and write copy-paste-ready prompts for the user's target tool. |
| `minimax-docx` | Professional DOCX document creation, editing, and formatting using OpenXML SDK (.NET). Covers creating new documents, editing existing ones, and applying template formatting with validation. |
| `minimax-pdf` | PDF generation, filling, and reformatting when visual quality and design identity matter. Best for polished, client-ready, print-ready PDF output. |
| `minimax-xlsx` | Open, create, read, analyze, edit, or validate Excel and spreadsheet files (.xlsx, .xlsm, .csv, .tsv), including formula recalculation and professional formatting standards. |
| `n8n-workflow-automation` | Designs and outputs n8n workflow JSON with robust triggers, idempotency, error handling, logging, retries, and human-in-the-loop review queues. Use when you need an auditable automation that won’t silently fail. |
| `nano-pdf` | Edit PDFs with natural-language instructions using the nano-pdf CLI. |
| `pptx-generator` | Generate, edit, and read PowerPoint presentations. Create from scratch with PptxGenJS, edit existing PPTX via XML workflows, or extract text with markitdown. |
| `presentation` | Create presentations from text or outline using Marp (Markdown to slides). Use when user asks for a presentation, slides, or pitch deck. |
| `product-validator` | Автоматическая проверка продуктов перед сдачей: безопасность, стиль, структура, пути. Три типа: скилл, материал для группы, GitHub-проект. |
| `quality-check` | Отдел контроля качества (ОТК). Обязательная проверка любого материала перед сдачей. Режимы: контент, GitHub публикация, Telegram пост. |
| `reddit` | Browse, search, post, and moderate Reddit. Read-only works without auth, posting and moderation require OAuth. |
| `researcher` | Универсальный ресёрчер. Поиск информации, анализ конкурентов, мониторинг трендов, разбор ссылок. Объединяет все инструменты поиска в один скилл. |
| `ru-text` | Russian text quality and editing reference for typography, info-style, editorial, UX writing, and business correspondence. Auto-activates on Russian text output. |
| `safeskillmonitor` | Безопасный мониторинг скиллов OpenClaw без выполнения shell-кода. |
| `self-improving` | Self-reflection, self-criticism, self-learning, and self-organizing memory. Installed as the main package for the team. Compatibility alias `self-improvement` points to it. |
| `skill-and-agent-creator` | Создание, улучшение и аудит скиллов и агентов OpenClaw. Три режима: создание скилла, создание агента, улучшение существующего. |
| `swipe-file` | Анализ чужого контента (YouTube, Telegram, подкасты) для извлечения полезных идей, паттернов и улучшений. |
| `systematic-debugging` | Систематическая отладка при любых багах, ошибках и неожиданном поведении. Используй перед предложением фиксов. |
| `tubescribe` | YouTube video summarizer with speaker detection, formatted documents, and audio output. Use when user sends a YouTube URL or asks to summarize or transcribe a YouTube video. |
| `tweet-writer` | Write viral, persuasive, engaging tweets and threads using web research and proven formulas. |
| `weather` | Get current weather and forecasts with no API key required. |
| `word-docx` | Create, inspect, and edit Microsoft Word documents and DOCX files with reliable styles, numbering, tracked changes, tables, sections, and compatibility checks. |
| `writing-plans` | Создание пошаговых планов реализации для технических, контентных и организационных задач. |
