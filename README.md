# Claudarity — RETIRED

A persistent memory and reinforcement-learning layer for AI coding assistants. Started in 2024 as a bash-hook system for Claude Code CLI, partially rewritten in TypeScript for Kiro starting January 2026, and retired in May 2026 — likely superseded by the maturing MCP (Model Context Protocol) memory-server ecosystem and Claude Code's built-in memory features.

This repository has been wiped down to its specification. See **[MASTER_SPEC.md](MASTER_SPEC.md)** for a thorough writeup of:

- What the project did and why
- The full data model and design decisions (8 ADRs distilled)
- Public API surface (slash commands, hooks, planned MCP tools)
- Why it's being retired and how it relates to MCP
- Lessons learned and rebuild guidance

## Full history

The complete pre-retirement codebase — all bash hooks, scripts, slash commands, the Claudarity-2.0 TypeScript scaffolding, all 8 Architecture Decision Records, the full `.kiro/specs/` triple, the legacy v1 README, CHANGELOG, and more — is preserved at the git tag **`pre-wipe-final`**.

```bash
git checkout pre-wipe-final
```

## License

MIT — see [LICENSE](LICENSE).
