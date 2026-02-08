# Claudarity 2.0

**Status**: Active Development (Foundation Layer 90% Complete)

Memory and reinforcement learning system for [Kiro](https://www.kiro.ai/), modernized from the legacy bash-based system with cross-platform TypeScript implementation.

## Overview

Claudarity 2.0 brings persistent memory and reinforcement learning to Kiro through:
- **Feedback Detection**: Learns from user praise and criticism
- **Context Injection**: Automatically provides relevant historical context via steering files
- **Template Evolution**: Adapts code patterns based on success rates
- **Multi-Armed Bandit Learning**: Optimizes suggestions using Thompson Sampling
- **Privacy-First**: All data stored locally, no external transmission

## Current Status (February 2026)

### ✅ Completed
- Platform abstraction layer (Windows/macOS/Linux support)
- Database schema and Memory Store with migrations
- Property-based testing infrastructure
- 47 tests passing (5 property tests, 42 unit tests)

### ⏳ In Progress
- Export/import property tests (Task 2.8)

### 📋 Next Up
- Configuration management
- Pattern matcher and feedback detector
- Learning engine with multi-armed bandit
- Context injector with steering file generation

See [PROJECT_STATUS.md](../PROJECT_STATUS.md) for detailed progress.

## Features

- Cross-platform support (Windows, macOS, Linux)
- Feedback detection and learning
- Context injection via steering files
- Template evolution
- Privacy-first local-only operation

## Installation

```bash
cd Claudarity-2.0
npm install
```

## Usage

### Development

```bash
npm test              # Run all tests once
npm run test:watch    # Watch mode for development
npm run build         # Compile TypeScript to dist/
npm run lint          # Lint TypeScript files
```

### Project Structure

```
src/
├── database/         # ✅ Memory store, migrations, schema (90% complete)
│   ├── MemoryStore.ts
│   ├── MemoryStore.test.ts
│   ├── MemoryStore.property.test.ts
│   ├── schema.ts
│   ├── migrations.ts
│   └── types.ts
├── platform/         # ✅ Cross-platform abstractions (complete)
│   ├── PlatformAbstraction.ts
│   ├── PlatformAbstraction.test.ts
│   └── types.ts
└── index.ts          # Main exports
```

## Architecture

Claudarity 2.0 follows a layered architecture:

```
┌─────────────────────────────────────┐
│   Integration Layer (MCP Server)    │  ⏳ Not Started
├─────────────────────────────────────┤
│   Application Layer                 │  ⏳ Not Started
│   (Learning, Feedback, Context)     │
├─────────────────────────────────────┤
│   Data Layer (Memory Store)         │  ✅ 90% Complete
├─────────────────────────────────────┤
│   Platform Layer (Abstraction)      │  ✅ Complete
└─────────────────────────────────────┘
```

### Key Components

- **Platform Abstraction**: OS detection, path handling, shell operations
- **Memory Store**: SQLite database with 7 tables for feedback, context, preferences, sessions, templates
- **Database Migrations**: Version tracking and sequential migration system
- **Export/Import**: Portable database backups with merge/replace strategies

## Testing

### Property-Based Testing

Claudarity 2.0 uses property-based testing with [fast-check](https://github.com/dubzzz/fast-check) to validate universal correctness properties:

```bash
npm test  # Runs both property tests and unit tests
```

**Completed Properties**:
- Property 1: Platform Detection and Configuration ✅
- Property 2: Path Portability ✅
- Property 25: Database Initialization ✅
- Property 26: Configurable Database Location ✅
- Property 30: Database Migration ✅

**Total Properties**: 64 identified across all requirements

### Test Coverage

- Platform Layer: ~85%
- Database Layer: ~80%
- Overall: ~25% (early stage)

## Documentation

- [Project Status](../PROJECT_STATUS.md) - Current progress and next steps
- [Requirements](.../.kiro/specs/claudarity-modernization/requirements.md) - 15 requirements with acceptance criteria
- [Design](.../.kiro/specs/claudarity-modernization/design.md) - Architecture and 64 correctness properties
- [Tasks](.../.kiro/specs/claudarity-modernization/tasks.md) - Implementation plan with 100+ subtasks

## Installation

## Technical Stack

- **Language**: TypeScript 5.3+
- **Runtime**: Node.js 20+
- **Database**: better-sqlite3 (SQLite with Node bindings)
- **Testing**: Vitest + fast-check (property-based testing)
- **Build**: TypeScript compiler (tsc)
- **Linting**: ESLint with TypeScript plugin

## Requirements

- Node.js 20+
- npm or yarn
- Windows 10+, macOS 12+, or Linux (Ubuntu 20.04+)

## Build

```bash
npm run build
```

## Test

```bash
npm test
```

## Development

```bash
npm run test:watch
```


## Contributing

This project follows a spec-driven development approach. Before contributing:

1. Review the [requirements](.../.kiro/specs/claudarity-modernization/requirements.md)
2. Check the [design document](.../.kiro/specs/claudarity-modernization/design.md)
3. Find an open task in [tasks.md](.../.kiro/specs/claudarity-modernization/tasks.md)
4. Write property tests before implementation
5. Ensure all tests pass before submitting

## License

MIT License - see [LICENSE](../LICENSE) for details.

---

**Modernization Started**: January 2026  
**Current Phase**: Foundation Layer (90% complete)  
**Next Milestone**: Configuration Management and Feedback Detection
