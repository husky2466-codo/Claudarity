# Technology Stack

## Claudarity 2.0 (Modern Implementation)

### Core Technologies
- **Language**: TypeScript 5.3+
- **Runtime**: Node.js 20+
- **Database**: better-sqlite3 (SQLite with Node bindings)
- **Testing**: Vitest with fast-check for property-based testing
- **Build**: TypeScript compiler (tsc)
- **Linting**: ESLint with TypeScript plugin

### Project Structure
```
Claudarity-2.0/
├── src/
│   ├── database/      # SQLite memory store, migrations, schema
│   ├── platform/      # Cross-platform abstractions (OS, paths, shell)
│   └── index.ts       # Main exports
├── dist/              # Compiled output
├── examples/          # Usage examples
└── docs/              # Documentation
```

### Common Commands

**Development**:
```bash
cd Claudarity-2.0
npm install              # Install dependencies
npm run build            # Compile TypeScript to dist/
npm test                 # Run all tests once
npm run test:watch       # Run tests in watch mode
npm run lint             # Lint TypeScript files
```

**Testing**:
- Unit tests: `*.test.ts` files co-located with source
- Property-based tests: `*.property.test.ts` using fast-check
- Test globals enabled (describe, it, expect available without imports)

### TypeScript Configuration
- Target: ES2020
- Module: CommonJS
- Strict mode enabled
- Declaration files generated
- Source maps enabled

## Legacy System (Bash)

### Technologies
- **Shell**: Bash 4.0+
- **Database**: SQLite3 CLI
- **Processing**: Shell scripts + Python 3.8+
- **Data**: JSON (jq for parsing)

### Structure
```
Root/
├── hooks/             # Event-driven bash hooks
├── scripts/           # Core processing scripts
├── commands/          # Slash command definitions (.md files)
└── config/            # Configuration templates
```

### Key Scripts
- `init-claudarity-db.sh`: Initialize SQLite database
- `auto-context-recall.sh`: Search and inject context
- `confidence-calculator.sh`: Calculate response confidence
- `template-evolver.py`: ML-based template evolution

## Database Schema

SQLite database with tables:
- `feedback_log`: User feedback (praise/criticism)
- `context_memory`: Conversation history
- `code_preferences`: Learned coding patterns
- `session_log`: Session tracking
- `template_evolution`: Template performance metrics
- `terminal_activity`: Shell command history

## Dependencies

**Production**:
- better-sqlite3: SQLite database access

**Development**:
- @types/node, @types/better-sqlite3: TypeScript definitions
- vitest: Test runner
- fast-check: Property-based testing library
- eslint + @typescript-eslint/*: Linting

## Platform Support

Cross-platform abstractions handle:
- OS detection (Windows/macOS/Linux)
- Path normalization (forward/backslash)
- Shell type detection (PowerShell/bash/zsh)
- Config directory locations
