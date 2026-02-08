# Product Overview

Claudarity is a memory and reinforcement learning system for AI coding assistants. Originally built for Claude Code (archived), now being modernized as Claudarity 2.0 for Kiro.

## Core Purpose

Provides persistent memory and learning capabilities:
- Remember conversations, preferences, and coding patterns across sessions
- Learn from user feedback (praise/criticism) to improve future responses
- Automatically inject relevant historical context when needed
- Track and evolve code templates based on success patterns

## Key Principles

- **Privacy-first**: All data stored locally, no cloud sync
- **Non-blocking**: Background processing to maintain fast user experience
- **Cross-platform**: Windows, macOS, and Linux support
- **Event-driven**: Hook-based architecture for lifecycle automation

## Architecture

Two parallel implementations:
1. **Legacy (bash)**: Original system in root directory - hooks, scripts, commands
2. **Claudarity-2.0 (TypeScript)**: Modern rewrite with cross-platform support

The modernization effort focuses on porting bash-based functionality to TypeScript while maintaining the core learning loop and memory capabilities.
