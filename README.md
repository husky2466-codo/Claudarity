# Claudarity

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Status](https://img.shields.io/badge/status-active--development-green.svg)
![Version](https://img.shields.io/badge/version-2.0.0--alpha-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-blue.svg)

> **Active Development:** Claudarity is being modernized from a bash-based system to a cross-platform TypeScript implementation for [Kiro](https://www.kiro.ai/). The legacy system (2024) is archived, but **Claudarity 2.0** is under active development. See [PROJECT_STATUS.md](PROJECT_STATUS.md) for current progress.

---

## What's Happening Now?

**Claudarity 2.0** is a complete rewrite in TypeScript, designed for [Kiro](https://www.kiro.ai/) with cross-platform support (Windows, macOS, Linux). The modernization follows a spec-driven development approach with:

- **Cross-platform architecture**: Abstracts OS-specific operations (PowerShell/bash/zsh)
- **Kiro-native integration**: Uses steering files instead of bash hooks
- **Property-based testing**: 64 correctness properties validated with fast-check
- **Privacy-first design**: All data remains local, no external transmission
- **Maintained learning**: Multi-armed bandit reinforcement learning preserved

### Current Status (February 2026)

**Foundation Layer: 90% Complete**
- ✅ Platform abstraction layer (OS detection, path handling, shell operations)
- ✅ Database schema and Memory Store (SQLite with migrations)
- ⏳ Export/import tests in progress
- 📋 Full specification with 15 requirements and 64 correctness properties

See [PROJECT_STATUS.md](PROJECT_STATUS.md) for detailed progress, architecture status, and next steps.

### Quick Start (Development)

```bash
cd Claudarity-2.0
npm install
npm test          # Run all tests
npm run build     # Compile TypeScript
```

---

## What Was This? (Legacy System)

Before Claude Code had built-in memory features, context management was entirely manual. Claudarity was an attempt to solve that problem -- a from-scratch memory layer built with bash hooks, SQLite, and pattern matching that sat on top of Claude Code and gave it the ability to:

- **Remember across sessions** -- conversations, preferences, coding patterns, and decisions were persisted to a local SQLite database and recalled automatically in future sessions.
- **Learn from feedback** -- a reinforcement learning loop detected user praise and criticism, tracked win/loss rates, and adjusted confidence scores so the system could evolve its behavior over time.
- **Evolve templates** -- project templates were treated as living artifacts that could be updated based on observed usage patterns and success rates across projects.

The core idea was simple: if you tell an AI "great job on the error handling" enough times, it should learn to prioritize that pattern. Claudarity implemented this through a multi-armed bandit approach with configurable feedback pattern detection (~77% F1 score without any ML models).

**It worked as a proof of concept.** The architecture -- non-blocking bash hooks, dual SQLite + Markdown storage, event-driven processing -- proved that persistent memory for AI coding assistants was both feasible and valuable.

### Why Modernize?

While Claude Code now has built-in memory features, Claudarity 2.0 explores advanced reinforcement learning and template evolution that go beyond basic memory. The modernization makes these capabilities:
- **Cross-platform**: Works on Windows, macOS, and Linux
- **Portable**: No hardcoded paths, configurable storage
- **Testable**: Property-based testing ensures correctness
- **Maintainable**: TypeScript with clear architecture
- **Kiro-native**: Integrates via steering files and MCP servers

The legacy bash system proved the concept; Claudarity 2.0 makes it production-ready.

---

## Legacy Architecture (Archived)

The original Claudarity (2024) consisted of four layers that hooked into Claude Code's lifecycle:

```
~/.claude/
├── hooks/              # Event-driven bash scripts (UserPromptSubmit, Stop, SessionStart)
├── scripts/            # Core processing (confidence calc, context recall, DB init)
├── commands/           # Slash commands (/baseline, /gomemory, /prefs, /review-templates)
├── config/             # Feedback patterns, settings templates
├── claudarity.db       # SQLite database with FTS5 (auto-created at runtime)
├── logs/               # Session logs (auto-generated)
└── settings.json       # Claude Code hook configuration
```

### How the Learning Loop Worked

1. User gives natural feedback ("great job on the error handling", "this is wrong")
2. `UserPromptSubmit` hook detects feedback via configurable regex patterns
3. Feedback classified as win/loss and stored in SQLite with project context
4. Confidence scores recalculated using a weighted formula:
   ```
   Score = Usage (30%) + Win Rate (40%) + Recency (10%) + Maturity (20%)
   ```
5. On next session start, relevant context and learned preferences injected automatically

All hook processing was non-blocking -- forked to background immediately so the user never waited.

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Storage | SQLite + Markdown dual write | Fast queries + human-readable backup |
| Event system | Bash hooks | Native Claude Code integration, no dependencies |
| Learning model | Multi-armed bandit | Simple, effective, no ML infrastructure needed |
| Processing | Background fork | Non-blocking, <15ms hook latency |
| Search | SQLite FTS5 | Full-text search without external services |

See [Architecture Decision Records](docs/adr/) for detailed rationale on each choice.

## What Worked and What Didn't

**Worked well:**
- Non-blocking background processing kept the user experience fast
- Dual storage (SQLite for queries, Markdown for readability) was a good tradeoff
- Pattern-based feedback detection reached ~77% F1 without any ML models
- Local-first design meant zero privacy concerns
- Event-driven hook architecture was clean and composable

**Limitations:**
- Hardcoded paths made it non-portable across machines
- Template evolution workflow was never completed
- No automated tests
- Background processes could fail silently
- Pattern detection accuracy plateaued without ML augmentation

## Documentation

### Claudarity 2.0 (Active Development)
- [Project Status](PROJECT_STATUS.md) -- Current progress, architecture status, next steps
- [Requirements Specification](.kiro/specs/claudarity-modernization/requirements.md) -- 15 requirements with acceptance criteria
- [Design Document](.kiro/specs/claudarity-modernization/design.md) -- Architecture, interfaces, 64 correctness properties
- [Implementation Tasks](.kiro/specs/claudarity-modernization/tasks.md) -- 21 tasks with 100+ subtasks
- [Claudarity 2.0 README](Claudarity-2.0/README.md) -- Quick start guide

### Legacy System (Archived)

This repository includes extensive documentation written during the cleanup phase:

- [Project Summary](docs/SUMMARY.md) -- Full project overview, metrics, and lessons learned
- [Architecture Overview](docs/ARCHITECTURE.md) -- System design and component interactions
- [Reinforcement Learning](docs/REINFORCEMENT_LEARNING.md) -- The learning approach explained in detail
- [Architecture Decision Records](docs/adr/) -- 8 ADRs covering all major design choices
- [Documentation Map](DOCUMENTATION_MAP.md) -- Quick reference to all docs

## Requirements

### Claudarity 2.0 (Active Development)
- Node.js 20+
- npm or yarn
- Windows 10+, macOS 12+, or Linux (Ubuntu 20.04+)

### Legacy System (If Running Locally)

- Claude Code CLI
- macOS or Linux
- bash 4.0+, sqlite3, jq
- Python 3.8+ (for template evolution)

## License

MIT License -- see [LICENSE](LICENSE) for details.

---

**Legacy system built**: 2024 | **Documented and archived**: February 2026  
**Claudarity 2.0 modernization started**: January 2026 | **Status**: Active Development
