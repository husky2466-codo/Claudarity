# Claudarity 2.0 - Development Guide

Quick reference for developers working on the Claudarity modernization.

---

## Quick Start

```bash
# Navigate to the project
cd Claudarity-2.0

# Install dependencies
npm install

# Run tests
npm test

# Watch mode for development
npm run test:watch

# Build
npm run build

# Lint
npm run lint
```

---

## Project Structure

```
Claudarity-2.0/
├── src/
│   ├── database/          # ✅ Memory store, migrations, schema (90% complete)
│   │   ├── MemoryStore.ts              # Main database interface
│   │   ├── MemoryStore.test.ts         # Unit tests
│   │   ├── MemoryStore.property.test.ts # Property tests
│   │   ├── schema.ts                   # Database schema
│   │   ├── migrations.ts               # Migration system
│   │   ├── migrations.test.ts          # Migration tests
│   │   ├── migrations.property.test.ts # Migration property tests
│   │   ├── export-import.property.test.ts # ⏳ Next task
│   │   └── types.ts                    # Type definitions
│   ├── platform/          # ✅ Cross-platform abstractions (complete)
│   │   ├── PlatformAbstraction.ts      # Platform interface
│   │   ├── PlatformAbstraction.test.ts # Tests
│   │   └── types.ts                    # Type definitions
│   └── index.ts           # Main exports
├── examples/              # Usage examples
├── docs/                  # Documentation
├── dist/                  # Compiled output (gitignored)
├── node_modules/          # Dependencies (gitignored)
├── package.json           # NPM configuration
├── tsconfig.json          # TypeScript configuration
├── vitest.config.ts       # Test configuration
└── .eslintrc.json         # Linting rules
```

---

## Current Status

### ✅ Completed Components

#### Platform Abstraction Layer
- **Location**: `src/platform/`
- **Status**: Complete with tests passing
- **Features**:
  - OS detection (Windows/macOS/Linux)
  - Path normalization
  - Shell type detection (PowerShell/bash/zsh)
  - Config directory management
- **Tests**: Property tests for platform detection and path portability

#### Database Layer (90%)
- **Location**: `src/database/`
- **Status**: Core implementation complete, export/import tests pending
- **Features**:
  - Complete SQLite schema (7 tables)
  - Full CRUD operations
  - Database migration system
  - Export/import functionality
- **Tests**: Property tests for initialization, configuration, and migrations

### ⏳ Next Task: Task 2.8

**Implement property tests for export/import functionality**

File: `src/database/export-import.property.test.ts`

Properties to test:
- Property 27: Export Creates Valid Backup
- Property 28: Import Merges or Replaces
- Property 29: Schema Compatibility Validation

**Acceptance Criteria**:
- Export creates a valid SQLite database file
- Import with merge strategy preserves existing data
- Import with replace strategy clears existing data first
- Schema version validation prevents incompatible imports

---

## Development Workflow

### 1. Pick a Task

Tasks are organized in `.kiro/specs/claudarity-modernization/tasks.md`:
- Each task has a number (e.g., Task 2.8)
- Tasks reference specific requirements
- Property tests are identified with "Property X" notation

### 2. Read the Specification

Before implementing:
1. Read the relevant requirements in `requirements.md`
2. Review the design in `design.md` (component interfaces, data models)
3. Check the property definition in the design document

### 3. Write Property Tests First

Property-based tests validate universal correctness properties:

```typescript
import { describe, it, expect } from 'vitest';
import * as fc from 'fast-check';

describe('Property X: Description', () => {
  it('should validate universal property', () => {
    fc.assert(
      fc.property(
        fc.arbitraryInput(), // Define input generators
        (input) => {
          // Test the property
          const result = functionUnderTest(input);
          expect(result).toSatisfy(property);
        }
      )
    );
  });
});
```

### 4. Implement the Feature

Follow the design document interfaces and data models.

### 5. Write Unit Tests

Complement property tests with specific examples and edge cases:

```typescript
describe('FeatureName', () => {
  it('should handle specific case', () => {
    const result = functionUnderTest(specificInput);
    expect(result).toBe(expectedOutput);
  });
});
```

### 6. Run Tests

```bash
npm test                 # Run all tests once
npm run test:watch       # Watch mode for development
```

### 7. Update Task Status

Mark tasks as complete in `tasks.md` by changing `[ ]` to `[x]`.

---

## Testing Strategy

### Property-Based Testing

Claudarity 2.0 uses property-based testing to validate universal correctness properties.

**What is a property?**
A property is a characteristic that should hold true for all valid inputs, not just specific examples.

**Example**:
- Unit test: "Export of database with 5 entries creates a file with 5 entries"
- Property test: "For any database state, export creates a valid SQLite file that can be imported"

**Tools**:
- [fast-check](https://github.com/dubzzz/fast-check): Property-based testing library
- [Vitest](https://vitest.dev/): Test runner

**Property Test Structure**:
```typescript
fc.assert(
  fc.property(
    fc.arbitraryGenerator(), // Input generator
    (input) => {
      // Test universal property
      const result = functionUnderTest(input);
      expect(result).toSatisfy(property);
    }
  )
);
```

### Unit Testing

Traditional unit tests validate specific examples and edge cases:
- Specific input/output pairs
- Edge cases (empty, null, boundary values)
- Error conditions

### Test Coverage Goals

- Platform Layer: 85%+ (achieved)
- Database Layer: 80%+ (achieved for completed parts)
- Application Layer: 80%+ (pending)
- Integration Layer: 70%+ (pending)

---

## Key Design Principles

1. **Cross-Platform First**: Abstract all platform-specific operations
2. **Kiro Native**: Use steering files instead of bash hooks
3. **Privacy Preserved**: All data remains local, no external transmission
4. **Learning Continuity**: Maintain multi-armed bandit reinforcement learning
5. **Property-Based Correctness**: Formal verification through executable properties

---

## Architecture Layers

### Layer 1: Platform Abstraction (✅ Complete)
Abstracts OS-specific operations:
- OS detection
- Path handling
- Shell operations
- Config directories

### Layer 2: Data Layer (✅ 90% Complete)
SQLite database with migrations:
- Memory Store interface
- Schema management
- Export/import
- Migration system

### Layer 3: Application Layer (⏳ Not Started)
Core learning and feedback logic:
- Pattern Matcher
- Feedback Detector
- Multi-Armed Bandit
- Learning Engine
- Template Evolver
- Context Injector

### Layer 4: Integration Layer (⏳ Not Started)
Kiro integration:
- MCP Server
- Steering file generation
- Session management
- Configuration management

---

## Common Commands

### Development
```bash
npm test              # Run all tests
npm run test:watch    # Watch mode
npm run build         # Compile TypeScript
npm run lint          # Lint code
```

### Testing Specific Files
```bash
npm test MemoryStore.test.ts           # Run specific test file
npm test -- --reporter=verbose         # Verbose output
npm test -- --coverage                 # Coverage report
```

### Debugging
```bash
npm test -- --inspect-brk              # Debug tests
```

---

## Documentation References

### Specification Documents
- [Requirements](.kiro/specs/claudarity-modernization/requirements.md) - 15 requirements
- [Design](.kiro/specs/claudarity-modernization/design.md) - Architecture and 64 properties
- [Tasks](.kiro/specs/claudarity-modernization/tasks.md) - Implementation plan

### Project Documentation
- [PROJECT_STATUS.md](PROJECT_STATUS.md) - Current progress
- [README.md](README.md) - Project overview
- [CHANGELOG.md](CHANGELOG.md) - Version history

### Legacy Documentation
- [docs/](docs/) - Original Claudarity documentation
- [docs/adr/](docs/adr/) - Architecture Decision Records

---

## Troubleshooting

### Tests Failing
1. Check if dependencies are installed: `npm install`
2. Rebuild: `npm run build`
3. Clear cache: `rm -rf node_modules dist && npm install`

### TypeScript Errors
1. Check `tsconfig.json` configuration
2. Ensure all types are imported correctly
3. Run `npm run lint` to check for issues

### Database Issues
1. Check if SQLite is properly installed
2. Verify database path is writable
3. Check schema version compatibility

---

## Next Milestones

### Immediate (Task 2.8)
- Complete export/import property tests
- Validate database layer is 100% complete

### Short Term (Tasks 3-6)
- Configuration management
- Pattern matcher
- Feedback detector with >90% F1 score

### Medium Term (Tasks 7-12)
- Learning engine with multi-armed bandit
- Template evolver
- Context injector with steering files

### Long Term (Tasks 13-21)
- MCP server implementation
- Session management
- Privacy features
- Legacy migration tool
- Cross-platform validation

---

## Contributing Guidelines

1. **Follow the spec**: All work should align with requirements and design documents
2. **Write tests first**: Property tests before implementation
3. **Keep it minimal**: Write only the code needed to satisfy requirements
4. **Document as you go**: Update comments and documentation
5. **Test cross-platform**: Verify on Windows, macOS, and Linux when possible

---

## Contact and Support

For questions about the modernization:
1. Review specification documents in `.kiro/specs/claudarity-modernization/`
2. Check [PROJECT_STATUS.md](PROJECT_STATUS.md) for current progress
3. Refer to legacy documentation in `docs/` for historical context

---

**Last Updated**: February 8, 2026  
**Current Phase**: Foundation Layer (90% complete)  
**Next Task**: Task 2.8 - Export/Import Property Tests
