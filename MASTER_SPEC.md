# Claudarity — Master Specification

**Status:** RETIRED (May 2026). Last active commit February 8, 2026. Likely superseded by the maturing MCP ecosystem and Claude Code's built-in memory features.

**One-liner:** A persistent memory and reinforcement-learning layer for AI coding assistants — first as a bash-hook system bolted onto Claude Code CLI (v1.0, 2024), then as an in-progress cross-platform TypeScript rewrite ("Claudarity 2.0") targeting Kiro via steering files and an MCP server (v2.0.0-alpha, paused at ~25% complete).

**Original repo:** `https://github.com/husky2466-codo/Claudarity`
**Pre-wipe history tag:** `pre-wipe-final` (preserves the entire codebase, docs, and ADRs as they existed on retirement).

---

## 1. Why this existed

Before Claude Code (and other AI coding assistants) had built-in cross-session memory, every conversation was a blank slate. You'd teach the assistant your coding style on Monday, restart on Tuesday, and start over. Claudarity's premise was simple: instrument Claude Code's lifecycle hooks, detect when the user gives natural-language feedback ("nice work" / "this is wrong"), persist that signal to a local SQLite database, and use it to bias future sessions toward patterns the user has approved.

The author called this "context engineering." In modern terminology it overlaps heavily with: persistent agent memory, reinforcement learning from user feedback (RLUF), prompt augmentation, and what the MCP (Model Context Protocol) ecosystem is now standardizing as memory servers.

## 2. Original vision (legacy v1, 2024)

A drop-in `~/.claude/` augmentation that gave Claude Code CLI three capabilities:

1. **Cross-session memory** — conversations, preferences, decisions, and code patterns persisted to a local SQLite DB and recalled automatically next session.
2. **Reinforcement learning from natural feedback** — a multi-armed bandit detected praise/criticism via regex patterns (~77% F1 without ML), tracked win/loss rates, recalculated confidence scores per pattern, and biased future suggestions accordingly.
3. **Template evolution** — code-generation templates were treated as living artifacts; weights adjusted by feedback; low-confidence templates archived; high-confidence ones promoted.

Critically, **all processing was non-blocking**: hooks forked to background within ~15 ms, never making the user wait.

### Confidence scoring formula (legacy)

```
Score = Usage (30%) + WinRate (40%) + Recency (10%) + Maturity (20%)
```

### Legacy directory layout (when installed in `~/.claude/`)

```
~/.claude/
├── hooks/             # Bash event hooks (UserPromptSubmit, Stop, SessionStart, etc.)
├── scripts/           # Confidence calc, context recall, DB init, template evolver
├── commands/          # Slash command definitions (Markdown-with-frontmatter)
├── config/            # feedback-patterns.template.json, settings.template.json
├── claudarity.db      # SQLite + FTS5 (auto-created)
├── logs/              # Session logs
└── settings.json      # Claude Code hook registration
```

## 3. v2.0 vision — Kiro/TypeScript rewrite

In January 2026 the author started a complete rewrite — ostensibly because Kiro (the modern Claude Code IDE branded by Amazon) became the new target, and the bash system was Mac/Linux-only with hardcoded paths. The rewrite was stated to be:

- Cross-platform (Windows PowerShell, macOS/Linux bash/zsh)
- Kiro-native (write to `.kiro/steering/*.md` instead of bash hooks)
- Property-tested (fast-check; 64 correctness properties identified)
- Privacy-first local-only
- Spec-driven (15 numbered requirements, design.md, tasks.md with 21 top-level tasks)

**It never reached usable state.** As of February 8, 2026 (last push):
- Platform abstraction layer: complete
- SQLite Memory Store + migrations + export/import: ~90% (export/import property tests pending — Task 2.8)
- Configuration management, pattern matcher, feedback detector, learning engine, template evolver, context injector, MCP server, migration tool: all 0%
- Test count: 47 passing (5 property tests + 42 unit tests)
- Source LOC: ~1,500; test LOC: ~1,200

## 4. Target users

- Power users of Claude Code CLI (legacy) or Kiro (v2.0) who wanted the assistant to "remember them."
- Privacy-conscious developers who would not use a cloud-synced memory product.
- Tinkerers comfortable installing bash hooks into `~/.claude/` and editing their own `settings.json`.

It was never published to npm, never had a CLI/binary entry point in v2.0, and the v1 install path was "clone and copy into `~/.claude/`."

## 5. Public API surface

### Legacy v1 — slash commands (Claude Code CLI)

Defined as Markdown files in `commands/`:

| Command | Purpose |
|---|---|
| `/baseline` | Show all-time win/loss feedback statistics |
| `/gomemory <query>` | Search SQLite FTS5 memory and inject results into the session |
| `/prefs <query>` | Query learned code preferences |
| `/sa <query>` | Structure a raw query for subagent analysis |
| `/sab <query>` | Execute a pre-structured subagent query |
| `/audit [focus]` | Comprehensive project audit via subagents |
| `/template-stats` | Template usage / evolution / effectiveness metrics |
| `/review-templates` | Review pending template-evolution proposals |
| `/new-project` | Initialize a new project with Claudarity context |
| `/goplaywright`, `/ruby` | Project-specific helpers (legacy artifacts) |

### Legacy v1 — hooks (registered in `~/.claude/settings.json`)

| Event | Hook | Function |
|---|---|---|
| `UserPromptSubmit` | `log-feedback.sh` | Detect feedback patterns, log to SQLite |
| `UserPromptSubmit` | `auto-create-todos-from-plan.sh` | Auto-todo from planning responses |
| `SessionStart` | `session-start.sh`, `context-aware-start.sh` | Init session row, inject relevant context |
| `Stop` | `backup-session-log.sh`, `stop-plan-sab.sh` | Archive logs |
| (continuous) | `context-detector.sh`, `context-search.sh`, `build-context-index.sh` | Maintain searchable context index |

### v2.0 — planned MCP server tools

```typescript
queryMemory({contextType?, filePattern?, timeRange?, limit?})
reviewFeedback({sessionId?, limit?})
correctFeedback({feedbackId, correctedType})
inspectTemplates({category?, minConfidence?})
exportMemory({outputPath, includeArchived?})
importMemory({sourcePath, mergeStrategy: 'merge' | 'replace'})
refreshContext({force?})
clearSteeringFiles()
healthCheck()
getConfig()
```

None of the above were implemented in v2.0 — only the `MemoryStore` and `PlatformAbstraction` classes were, and they were unwired from any user-facing surface.

## 6. Data model (SQLite, both v1 and v2)

Eight tables (v2 added `template_history` and `schema_version`):

| Table | Key columns | Purpose |
|---|---|---|
| `feedback_log` | id, session_id, timestamp, feedback_type ∈ {positive,negative,neutral}, confidence, text_content, code_snippet, file_path, suggestion_type, language, operation, matched_patterns, corrected, corrected_type | Every detected feedback event with full context |
| `context_memory` | id, session_id, timestamp, context_type ∈ {code_pattern,preference,solution}, content, file_path, language, tags, relevance_score, usage_count, last_used | Reusable context snippets — the actual "memory" |
| `code_preferences` | id, category ∈ {error_handling,naming,structure,testing}, preference_key, preference_value, confidence, evidence_count, last_updated | Learned coding preferences (UNIQUE per category+key) |
| `session_log` | id, start_time, end_time, project_path, activity_summary, feedback_count, context_injections | Session boundaries |
| `template_evolution` | id, category, pattern, confidence, alpha, beta, usage_count, last_used, archived, created_at, updated_at | Multi-armed bandit state per template (alpha/beta = Beta-distribution params) |
| `template_history` | id, template_id, timestamp, confidence_before, confidence_after, feedback_type | Template evolution audit log |
| `terminal_activity` | id, session_id, timestamp, command, exit_code, duration_ms | Optional shell command history |
| `schema_version` | version, applied_at | Migration tracking |

v1 also used FTS5 virtual tables for full-text search; v2 had not yet ported FTS5.

## 7. Key design decisions (legacy ADRs 001–008)

1. **Reinforcement learning via win/loss feedback** with binary classification, not sentiment ML. Trade-off: simple and fast, but plateaued at ~77% F1.
2. **SQLite as primary storage** — ACID, FTS5, no daemon, zero ops.
3. **Bash hooks for the event system** — native Claude Code CLI integration, no daemon, but Mac/Linux-only and brittle on path assumptions.
4. **Pattern-based feedback detection** with a JSON-configurable phrase/word library (see `config/feedback-patterns.template.json` — ~35 praise phrases, ~50 praise words, 30+ loss phrases, 47+ loss words; short-message filter ≤5 words / ≤50 chars to avoid catching commentary).
5. **Template evolution** — Beta-distribution (alpha/beta) bandit per template; archive when confidence falls below threshold.
6. **Dual storage** — SQLite for fast queries + Markdown cache files for human readability and trivial backup.
7. **Multi-factor confidence score** — 30% usage, 40% win rate, 10% recency, 20% maturity (avoids new-template cold-start dominance).
8. **Background fork-and-forget processing** — hooks return in <15 ms; heavy work runs detached.

v2 retained decisions 1, 2, 4, 5, 6, 7 and replaced decisions 3 (bash → TS+MCP) and 8 (fork-and-forget → async/await with non-blocking writes).

## 8. Relation to MCP and why this is being retired

When v1 was built (2024), MCP did not exist; persistent agent memory was DIY. By the time v2 began (Jan 2026), MCP was rapidly maturing and Anthropic + community had begun publishing official memory MCP servers (e.g., the various `@modelcontextprotocol/server-memory` / knowledge-graph implementations). Claude Code itself shipped built-in memory primitives (`/memory` command, `CLAUDE.md` project context).

The v2 rewrite acknowledged this directly — its own steering doc says "Claudarity 2.0 explores advanced reinforcement learning and template evolution that go beyond basic memory" — but never reached a point where the RL/template features it claimed to differentiate on were actually built. What was built (a SQLite store, a platform abstraction) is now table-stakes available off-the-shelf in any number of MCP memory servers.

**The unique IP of Claudarity was the RL feedback loop and template evolution.** That was the part that did not get rewritten. Without it, v2 is "yet another local SQLite memory store wrapped in TypeScript," which is a solved problem.

## 9. Tech stack

**Legacy v1:** bash 4.0+, sqlite3 CLI (with FTS5), jq, Python 3.8+ (for `template-evolver.py`), Claude Code CLI hook system.

**v2.0-alpha:** TypeScript 5.3+, Node.js 20+, `better-sqlite3` 12.x, Vitest 1.x, fast-check 3.x, ESLint 8.x, target ES2020 / CommonJS.

## 10. Known issues / limitations carried at retirement

**v1 (acknowledged in repo):**
- Hardcoded paths (e.g., `/Volumes/DevDrive/Backups/...` in `.env.example`) — non-portable.
- Template evolution workflow never completed end-to-end.
- No automated tests.
- Background processes could fail silently with no surfacing to the user.
- Pattern-detection accuracy plateaued ~77% F1; no ML augmentation path.
- Mac/Linux only.

**v2.0-alpha (paused state):**
- Only ~25% complete overall; database-layer property tests for export/import never landed (Task 2.8).
- No user-facing surface — no MCP server, no CLI, nothing to install.
- No migration tool from v1 → v2 (planned but not built).
- No way to actually use it on Kiro despite "Kiro-native" branding.

## 11. Lessons learned

- **Domain that was moving faster than the project.** The author identified a real gap (cross-session memory), shipped a working v1, then lost the race when the platform matured. Anyone rebuilding in 2026+ should start by surveying MCP memory servers and only build custom if they have a differentiator that can't be expressed as an MCP tool.
- **The differentiator was the RL loop, not the storage.** v2 got the architectural rewrite right but front-loaded the boring layer (storage + platform abstraction) and never reached the interesting layer (bandit + template evolution). If rebuilding, port the RL/feedback logic *first*, on top of an existing MCP memory server, so the differentiator exists from day 1.
- **Pattern-based feedback detection has a ceiling.** ~77% F1 with a hand-tuned phrase/word library is decent for a weekend project but not for a product. A modern rebuild would use a small classifier or even a few-shot prompt to a fast model (Haiku/Flash-class) for feedback classification, eliminating the regex maintenance burden.
- **Spec-driven development needs execution discipline.** 15 requirements, 64 properties, 100+ subtasks is an excellent spec. It does not, however, write itself.
- **Hardcoded paths are a tax you pay forever.** v1's `/Volumes/DevDrive/...` defaults are why portability became the first item on the v2 rewrite.

## 12. Rebuild guidance (if anyone resumes this)

1. **Don't rebuild the storage layer.** Pick an existing MCP memory server (knowledge-graph or vector-based) and write Claudarity as a *thin layer on top* that adds the RL feedback loop and template-confidence scoring.
2. **Port the bandit/confidence math first.** That is the actual product. The schema in section 6 (especially `template_evolution` with its alpha/beta Beta-distribution columns) is reusable.
3. **Replace regex feedback detection with an LLM classifier** — feed the user's last N messages plus the assistant's last response to a small, cheap model and ask "did the user just praise, criticize, or give neutral commentary?" Calibrate against the ~77% F1 baseline.
4. **Expose everything as MCP tools, not slash commands.** The legacy slash-command surface (`/baseline`, `/gomemory`, `/prefs`, `/template-stats`) maps cleanly to the v2 planned tools listed in section 5.
5. **Skip the multi-OS shell abstraction.** If you build on top of MCP, the platform layer is the host's problem, not yours.
6. **Keep dual storage (SQLite + Markdown) only if you need human-readable backups.** Otherwise drop it; modern dev tooling reads SQLite fine.

## 13. References (preserved in `pre-wipe-final` tag)

- Root `README.md` — high-level v1+v2 overview
- `PROJECT_STATUS.md` — detailed v2 progress as of retirement
- `CHANGELOG.md` — full version history (v1 → v2.0 → v2.0.0-alpha)
- `docs/adr/001-008-*.md` — eight Architecture Decision Records
- `docs/REINFORCEMENT_LEARNING.md` — full math/explanation of the RL approach
- `docs/ARCHITECTURE.md`, `docs/DIAGRAMS.md`, `docs/MERMAID_DIAGRAMS.md` — system design
- `.kiro/specs/claudarity-modernization/{requirements,design,tasks}.md` — the v2 spec triple
- `Claudarity-2.0/src/database/{schema,types,MemoryStore}.ts` — the only real code that landed
- `Claudarity-2.0/src/platform/PlatformAbstraction.ts` — cross-platform helpers
- `config/feedback-patterns.template.json` — the hand-tuned praise/loss phrase library
- `commands/`, `hooks/`, `scripts/` — the entire v1 bash implementation

## 14. License

MIT — see `LICENSE`.

---

**Final state at retirement:** v1 archived and functional in bash; v2.0-alpha paused at foundation layer; zero open issues, zero open PRs, zero external dependents (no npm publication, no installations beyond the author's). No users will be broken by this retirement.
