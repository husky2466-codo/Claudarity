# Contributing to Claudarity

Thank you for your interest in contributing to Claudarity! This document provides guidelines for contributing to the modernization effort.

## Project Status

**Claudarity 2.0** is under active development. The legacy bash-based system (in the root directory) is archived. All new contributions should focus on the TypeScript modernization in `Claudarity-2.0/`.

See [PROJECT_STATUS.md](PROJECT_STATUS.md) for current progress and [DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md) for detailed development instructions.

## Getting Started

### For Claudarity 2.0 (Active Development)

1. Fork the repository
2. Clone your fork locally
3. Navigate to the Claudarity-2.0 directory
4. Install dependencies
5. Create a new branch for your feature or bugfix
6. Make your changes following the spec-driven approach
7. Test your changes thoroughly
8. Submit a pull request

### Development Setup

```bash
# Clone the repository
git clone <your-fork>
cd claudarity

# Navigate to Claudarity 2.0
cd Claudarity-2.0

# Install dependencies
npm install

# Run tests
npm test

# Watch mode for development
npm run test:watch
```

## Spec-Driven Development Approach

Claudarity 2.0 follows a rigorous spec-driven development methodology:

1. **Read the Requirements**: Review `.kiro/specs/claudarity-modernization/requirements.md`
2. **Understand the Design**: Study `.kiro/specs/claudarity-modernization/design.md`
3. **Pick a Task**: Choose from `.kiro/specs/claudarity-modernization/tasks.md`
4. **Write Property Tests First**: Implement property-based tests for universal correctness
5. **Implement the Feature**: Follow the design document interfaces
6. **Write Unit Tests**: Add specific examples and edge cases
7. **Update Task Status**: Mark tasks complete in `tasks.md`

See [DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md) for detailed workflow.

## Code Guidelines

### TypeScript (Claudarity 2.0)

- Follow TypeScript best practices
- Use strict type checking (enabled in tsconfig.json)
- Add JSDoc comments for public APIs
- Use descriptive variable and function names
- Keep functions small and focused
- Prefer composition over inheritance
- Use interfaces for contracts, types for data shapes

### Testing

**Property-Based Testing** (Required):
- Write property tests for universal correctness properties
- Use fast-check for property-based testing
- Test across many generated inputs
- Validate properties hold for all valid inputs

**Unit Testing** (Required):
- Write unit tests for specific examples
- Test edge cases (empty, null, boundary values)
- Test error conditions
- Use descriptive test names

**Example**:
```typescript
// Property test
describe('Property 27: Export Creates Valid Backup', () => {
  it('should create valid SQLite database for any input', () => {
    fc.assert(
      fc.property(fc.databaseState(), (state) => {
        const exported = exportDatabase(state);
        expect(isValidSQLite(exported)).toBe(true);
      })
    );
  });
});

// Unit test
describe('exportDatabase', () => {
  it('should export empty database', () => {
    const db = createEmptyDatabase();
    const exported = exportDatabase(db);
    expect(exported.size).toBeGreaterThan(0);
  });
});
```

### Documentation

- Update README.md if adding new features
- Add inline comments for complex logic
- Update specification documents if requirements change
- Include examples in documentation
- Keep PROJECT_STATUS.md updated with progress

## Testing Requirements

Before submitting a pull request:

1. **All tests must pass**: `npm test`
2. **Linting must pass**: `npm run lint`
3. **Build must succeed**: `npm run build`
4. **Property tests required**: For any new functionality
5. **Unit tests required**: For specific examples and edge cases
6. **Cross-platform testing**: Test on Windows, macOS, or Linux when possible

## Pull Request Process

1. **Branch naming**: Use descriptive names
   - `task/2.8-export-import-tests`
   - `feature/configuration-management`
   - `bugfix/database-migration-error`
   - `docs/update-development-guide`

2. **Commit messages**: Use clear, descriptive messages
   - Start with a verb (Add, Implement, Fix, Update, Remove)
   - Reference task numbers: "Implement Task 2.8: Export/Import Property Tests"
   - Keep first line under 72 characters
   - Add details in the body if needed

3. **PR description**: Use the PR template (auto-populated)
   - Reference the task from tasks.md
   - List requirements validated
   - List properties tested
   - Include test results
   - Describe any breaking changes

4. **Review process**:
   - PRs require at least one approval
   - Address all review comments
   - Keep PRs focused on a single task
   - Ensure CI passes on all platforms

## Reporting Bugs

Use the bug report template when reporting bugs. Include:

- Component affected (Platform, Database, Learning Engine, etc.)
- Claudarity version (e.g., 2.0.0-alpha)
- Operating system and version
- Node.js version
- Steps to reproduce
- Expected vs actual behavior
- Test output or error messages
- Related requirements or properties (if applicable)

## Feature Requests

Use the feature request template. Include:

- Clear description of the feature
- Problem statement (what problem does it solve?)
- Proposed solution
- Related requirements or tasks (if applicable)
- Implementation considerations
- Impact on users

## Task Implementation

Use the task implementation template to track work on specific tasks from `tasks.md`. This helps coordinate efforts and avoid duplicate work.

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Assume good intentions
- Follow the spec-driven approach
- Prioritize correctness over speed

## Questions?

- Open an issue for general questions
- Use discussions for broader topics
- Check existing issues/PRs first
- Review [DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md)
- Check [PROJECT_STATUS.md](PROJECT_STATUS.md) for current state

## Legacy System (Archived)

The legacy bash-based system in the root directory is archived and not accepting contributions. All development efforts should focus on Claudarity 2.0.

For historical context, see the legacy guidelines below.

---

## Legacy Guidelines (Archived - For Reference Only)

### Shell Scripts

- Use bash, not sh
- Include shebang: `#!/usr/bin/env bash`
- Use `set -euo pipefail` for error handling
- Add comments for complex logic
- Use descriptive variable names
- Quote variables to prevent word splitting
- Use `$HOME` instead of hardcoded paths

### Python Scripts

- Follow PEP 8 style guide
- Use Python 3.8+ features
- Add docstrings to functions
- Handle errors gracefully
- Use type hints where appropriate

### Documentation

- Update README.md if adding new features
- Add inline comments for complex code
- Update relevant docs in the `docs/` directory
- Include examples in slash command definitions

## Testing

Before submitting a pull request:

1. Test your scripts in isolation
2. Test integration with Claude Code
3. Verify database operations don't corrupt data
4. Check for hardcoded paths or personal information
5. Ensure scripts are executable (`chmod +x`)

## Pull Request Process

1. **Branch naming**: Use descriptive names
   - `feature/add-new-hook`
   - `bugfix/fix-context-search`
   - `docs/update-installation`

2. **Commit messages**: Use clear, descriptive messages
   - Start with a verb (Add, Fix, Update, Remove)
   - Keep first line under 72 characters
   - Add details in the body if needed

3. **PR description**: Include
   - What problem does this solve?
   - What changes were made?
   - How to test the changes?
   - Any breaking changes?

4. **Review process**:
   - PRs require at least one approval
   - Address all review comments
   - Keep PRs focused and reasonably sized

## Reporting Bugs

When reporting bugs, include:

- Claudarity version
- Operating system and version
- Steps to reproduce
- Expected behavior
- Actual behavior
- Relevant logs or error messages
- Database schema version (if relevant)

## Feature Requests

When suggesting features:

- Describe the use case
- Explain why it would be valuable
- Consider implementation complexity
- Check if it aligns with project goals

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Assume good intentions

## Questions?

- Open an issue for general questions
- Use discussions for broader topics
- Check existing issues/PRs first

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
