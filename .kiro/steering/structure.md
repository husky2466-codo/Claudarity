# Project Structure

## Repository Organization

This is a dual-implementation repository with legacy bash system and modern TypeScript rewrite.

### Root Level

```
/
├── Claudarity-2.0/          # Modern TypeScript implementation
├── .kiro/                   # Kiro-specific files (specs, steering)
├── hooks/                   # Legacy bash event hooks
├── scripts/                 # Legacy processing scripts
├── commands/                # Legacy slash command definitions
├── config/                  # Legacy configuration templates
└── docs/                    # Comprehensive documentation
```

### Claudarity-2.0 (Active Development)

```
Claudarity-2.0/
├── src/
│   ├── database/
│   │   ├── MemoryStore.ts              # Main database interface
│   │   ├── MemoryStore.test.ts         # Unit tests
│   │   ├── MemoryStore.property.test.ts # Property-based tests
│   │   ├── schema.ts                   # Database schema definitions
│   │   ├── migrations.ts               # Schema migrations
│   │   └── types.ts                    # TypeScript interfaces
│   ├── platform/
│   │   ├── PlatformAbstraction.ts      # Cross-platform utilities
│   │   ├── PlatformAbstraction.test.ts
│   │   └── types.ts                    # Platform type definitions
│   └── index.ts                        # Main exports
├── examples/
│   └── memory-store-usage.ts           # Usage examples
├── docs/
│   └── memory-store.md                 # API documentation
├── dist/                               # Compiled JavaScript (gitignored)
├── node_modules/                       # Dependencies (gitignored)
├── package.json                        # NPM configuration
├── tsconfig.json                       # TypeScript configuration
├── vitest.config.ts                    # Test configuration
└── .eslintrc.json                      # Linting rules
```

### Legacy System (Archived)

**hooks/**: Event-driven automation
- `UserPromptSubmit`: Fires when user sends message
- `Stop`: Fires when session ends
- `SessionStart`: Fires at session start

**scripts/**: Core processing logic
- Data collection (capture-terminal-activity.sh)
- Analysis (analyze-code-patterns.sh, confidence-calculator.sh)
- Retrieval (auto-context-recall.sh, query-preferences.sh)
- Maintenance (cleanup-feedback-cache.sh, rotate-debug-log.sh)

**commands/**: Slash command definitions (markdown files)
- `/gomemory`: Search conversation history
- `/baseline`: View learning statistics
- `/prefs`: Query code preferences
- `/audit`: Project health analysis

**config/**: Configuration templates
- `feedback-patterns.template.json`: Feedback detection patterns
- `settings.template.json`: System settings

### Documentation

```
docs/
├── adr/                    # Architecture Decision Records (8 ADRs)
├── ARCHITECTURE.md         # System design overview
├── FEATURES.md             # Feature documentation
├── REINFORCEMENT_LEARNING.md # Learning approach details
├── SUMMARY.md              # Project summary
└── MIGRATION_PLAN.md       # Modernization roadmap
```

### Kiro Integration

```
.kiro/
├── specs/
│   └── claudarity-modernization/  # Active spec for TypeScript migration
│       ├── requirements.md
│       ├── design.md
│       └── tasks.md
└── steering/                      # AI assistant guidance (this file)
    ├── product.md
    ├── tech.md
    └── structure.md
```

## File Naming Conventions

- **Source files**: PascalCase for classes (MemoryStore.ts)
- **Test files**: `*.test.ts` for unit tests, `*.property.test.ts` for property-based tests
- **Type definitions**: `types.ts` in each module
- **Index files**: `index.ts` for module exports
- **Documentation**: kebab-case markdown files
- **Scripts**: kebab-case shell scripts

## Module Organization

Each module follows this pattern:
```
module/
├── index.ts           # Public exports
├── ModuleName.ts      # Implementation
├── ModuleName.test.ts # Unit tests
├── ModuleName.property.test.ts # Property tests (if applicable)
└── types.ts           # Type definitions
```

## Import/Export Patterns

- Use barrel exports in `index.ts` files
- Export types and interfaces from `types.ts`
- Co-locate tests with source files
- Avoid circular dependencies
