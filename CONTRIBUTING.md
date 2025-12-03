# Contributing to Claudarity

Thank you for your interest in contributing to Claudarity! This document provides guidelines for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Create a new branch for your feature or bugfix
4. Make your changes
5. Test your changes thoroughly
6. Submit a pull request

## Development Setup

1. Install dependencies:
   - bash 4.0+
   - sqlite3
   - Python 3.8+
   - jq

2. Set up your local instance:
   ```bash
   # Clone to ~/.claude for testing
   git clone <your-fork> ~/.claude-dev
   cd ~/.claude-dev
   ./scripts/init-claudarity-db.sh
   ```

3. Test your changes before submitting

## Code Guidelines

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
