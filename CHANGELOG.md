# Changelog

All notable changes to the Claudarity project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### In Progress - Claudarity 2.0 Modernization (Active Development)

#### Foundation Layer (90% Complete)
- ✅ Platform abstraction layer with cross-platform support
  - OS detection (Windows/macOS/Linux)
  - Path normalization and shell type detection
  - Property tests passing
- ✅ Database schema and Memory Store
  - Complete SQLite schema with 7 tables
  - Full CRUD operations
  - Database migration system
  - Export/import functionality (tests pending)
- ⏳ Export/import property tests (Task 2.8 - next up)

#### Specification Complete
- 15 comprehensive requirements with acceptance criteria
- Complete architecture design with component interfaces
- 64 correctness properties for property-based testing
- 21 tasks with 100+ subtasks organized by layer

#### Next Steps
- Complete database layer tests (Task 2.8)
- Implement configuration management (Task 4)
- Build pattern matcher and feedback detector (Tasks 5-6)
- Implement learning engine with multi-armed bandit (Tasks 7-8)

See [PROJECT_STATUS.md](PROJECT_STATUS.md) for detailed progress.

### Planned (Claudarity 2.0)
- Configuration management with YAML/JSON support
- Pattern-based feedback detection (>90% F1 score target)
- Multi-armed bandit learning engine with Thompson Sampling
- Template evolution with confidence scoring
- Context injection via Kiro steering files
- MCP server for Kiro integration
- Migration tool for legacy data
- Cross-platform testing and validation

## [2.0.0-alpha] - 2026-02-08

### Added - Claudarity 2.0 Modernization (Foundation Layer)

#### Platform Abstraction Layer
- Cross-platform OS detection (Windows/macOS/Linux)
- Path normalization with platform-specific separators
- Shell type detection (PowerShell/bash/zsh)
- Config directory management for each platform
- Property-based tests for platform detection and path portability

#### Database Layer
- Complete SQLite schema with 7 tables:
  - feedback_log: User feedback with context
  - context_memory: Reusable context snippets
  - code_preferences: Learned coding preferences
  - session_log: Session tracking
  - template_evolution: Code template learning
  - template_history: Template evolution tracking
  - terminal_activity: Command patterns (optional)
- Memory Store interface with full CRUD operations
- Database migration system with version tracking
- Export/import functionality for database portability
- Property-based tests for database operations

#### Specification Documents
- Requirements document with 15 comprehensive requirements
- Design document with complete architecture and 64 correctness properties
- Implementation tasks with 21 top-level tasks and 100+ subtasks
- Steering files for product, tech stack, and project structure

#### Testing Infrastructure
- Vitest test framework with fast-check integration
- Property-based testing approach with 64 identified properties
- 5 property tests passing (platform and database layer)
- 42 unit tests passing
- Test coverage: ~80% for completed components

#### Documentation
- PROJECT_STATUS.md with detailed progress tracking
- Updated README.md reflecting active development status
- Comprehensive specification documents in .kiro/specs/

### Changed
- Project status from "archived" to "active development"
- Platform support expanded to Windows, macOS, and Linux
- Architecture shifted from bash hooks to TypeScript with steering files
- Storage approach now uses configurable paths instead of hardcoded locations

### Technical Details
- Language: TypeScript 5.3+
- Runtime: Node.js 20+
- Database: better-sqlite3
- Testing: Vitest + fast-check
- Build: TypeScript compiler

## [2.0.0] - 2026-02-08

### Added - Documentation Phase
- **Architecture Decision Records**: 8 comprehensive ADRs documenting all major design decisions
  - ADR-001: Reinforcement Learning Approach
  - ADR-002: SQLite as Primary Storage
  - ADR-003: Bash Hooks for Event System
  - ADR-004: Pattern-Based Feedback Detection
  - ADR-005: Template Evolution System
  - ADR-006: Dual Storage Strategy
  - ADR-007: Confidence Score Calculation
  - ADR-008: Background Processing Model

- **Comprehensive Guides**:
  - Project Summary (docs/SUMMARY.md)
  - Cleanup Guide (docs/CLEANUP_GUIDE.md)
  - Migration Plan (docs/MIGRATION_PLAN.md)
  - Reinforcement Learning Explanation (docs/REINFORCEMENT_LEARNING.md)
  - System Diagrams (docs/DIAGRAMS.md)
  - Mermaid Diagrams (docs/MERMAID_DIAGRAMS.md)
  - Documentation Index (docs/INDEX.md)

- **Navigation Aids**:
  - Documentation Map (DOCUMENTATION_MAP.md)
  - Cleanup Completion Report (CLEANUP_COMPLETE.md)
  - Repository Audit (REPOSITORY_AUDIT.md)

- **Visual Documentation**:
  - 10+ text-based diagrams
  - 11 interactive Mermaid diagrams
  - System architecture visualizations
  - Workflow diagrams

### Changed
- Updated README.md with project status and experimental notice
- Enhanced CONTRIBUTING.md with clear guidelines
- Reorganized documentation structure

### Documented
- Complete reinforcement learning approach with mathematical formulations
- All design decisions with rationale and alternatives considered
- System architecture and component interactions
- Data flow and processing patterns
- Confidence scoring formula and tuning guidelines
- Template evolution workflow
- Background processing model
- Storage strategy and backup procedures

### Fixed
- Documentation organization and navigation
- Internal linking between documents
- Project status clarity

## [1.0.0] - 2024 (Estimated)

### Added - Initial Implementation
- **Core Features**:
  - Feedback learning system with win/loss tracking
  - Pattern-based feedback detection
  - Confidence score calculation
  - Context memory with SQLite storage
  - Full-text search (FTS5)
  - Template evolution system (partial)
  - Event hook system (bash-based)
  - Dual storage (SQLite + Markdown)

- **Hooks**:
  - UserPromptSubmit hook for feedback detection
  - SessionStart hook for initialization
  - Stop hook for session backup
  - Context detection and injection hooks

- **Scripts**:
  - confidence-calculator.sh
  - template-evolver.py
  - auto-context-recall.sh
  - init-claudarity-db.sh
  - 20+ utility scripts

- **Commands**:
  - /baseline - Win/loss statistics
  - /gomemory - Context search
  - /prefs - Query preferences
  - /review-templates - Template review
  - 10+ slash commands

- **Storage**:
  - SQLite database with FTS5
  - Markdown cache files
  - Session logging
  - Terminal activity capture

### Known Issues
- Hardcoded paths (not portable across systems)
- Template evolution workflow incomplete
- No automated testing
- Limited error handling in background processes
- Pattern detection accuracy ~77% (needs ML augmentation)

---

## Version History Summary

- **v2.0.0-alpha** (2026-02-08): Modernization in progress - Foundation layer 90% complete
- **v2.0.0** (2026-02-08): Documentation and cleanup phase - Legacy system archived
- **v1.0.0** (2024): Initial experimental implementation - Core features working

## Migration Notes

### From v2.0.0 to v2.0.0-alpha (Modernization)
- Legacy bash system remains in root directory (archived)
- New TypeScript implementation in Claudarity-2.0/ directory
- No migration path yet (migration tool planned for later tasks)
- Both systems can coexist during development

### From v1.0.0 to v2.0.0
- No breaking changes to functionality
- Added comprehensive documentation
- Identified issues and created improvement roadmap
- No code changes required for existing installations

### Future Breaking Changes (v2.0.0 Final Release)
- Legacy bash system will be fully deprecated
- Migration tool will convert legacy data to new format
- Configuration file format will be finalized
- MCP server integration will be required for Kiro usage

See [Migration Plan](docs/MIGRATION_PLAN.md) for detailed upgrade path.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to this project.

## Links

- [Documentation](docs/INDEX.md)
- [Architecture Decision Records](docs/adr/)
- [Migration Plan](docs/MIGRATION_PLAN.md)
- [Cleanup Guide](docs/CLEANUP_GUIDE.md)
