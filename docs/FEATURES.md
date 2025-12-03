# Claudarity Features

Comprehensive guide to Claudarity's capabilities.

## Core Features

### 1. Contextual Memory System

Claudarity maintains a searchable database of all conversations, allowing Claude to recall relevant past discussions.

**Key capabilities:**
- Full-text search across conversation history
- Semantic similarity matching
- Time-based context windowing
- Project-specific memory isolation

**Usage:**
```bash
/gomemory authentication implementation
```

### 2. Feedback Learning

Automatically detects and learns from user feedback to improve future responses.

**Detection methods:**
- Pattern matching (configurable phrases/words)
- Sentiment analysis
- Explicit teaching commands
- Win/loss tracking

**Feedback types:**
- Praise: "great job", "perfect", "exactly what I needed"
- Criticism: "wrong approach", "not what I wanted"
- Neutral: Logged but doesn't affect scoring

**Baseline tracking:**
```bash
/baseline  # View all-time statistics
```

### 3. Code Preferences Learning

Learns your coding style, patterns, and preferences from feedback and successful implementations.

**Learned preferences include:**
- Language-specific patterns
- Error handling approaches
- Testing strategies
- Documentation styles
- Naming conventions
- Architecture patterns

**Query preferences:**
```bash
/prefs error handling in TypeScript
```

### 4. Session Management

Tracks terminal activity and session state for complete context awareness.

**Captured data:**
- Shell commands executed
- Working directory changes
- Git operations
- File modifications
- Command exit codes
- Timestamps

**Session replay:**
```bash
~/.claude/scripts/replay-session.sh <session-id>
```

### 5. Template Evolution System

Machine learning-based template improvement system.

**How it works:**
1. Templates are used in responses
2. User feedback is associated with template usage
3. Python ML model analyzes successful patterns
4. Templates evolve based on what works
5. Low-performing templates are deprecated

**View statistics:**
```bash
/template-stats
```

**Review proposals:**
```bash
/review-templates
```

### 6. Automated Context Injection

Hooks automatically detect when historical context would be helpful and inject it.

**Triggers:**
- References to past work
- Similar problem patterns
- Project-specific keywords
- Continuation of previous tasks

**Manual control:**
```bash
/gomemory <query>
```

### 7. Structured Analysis with Subagents

Complex queries can be structured and analyzed by specialized subagents.

**Workflow:**
```bash
/sa <raw query>        # Structure the query
/sab <structured>      # Execute with subagents
```

**Use cases:**
- Multi-faceted problems
- Comprehensive audits
- Architectural decisions
- Security analysis

### 8. Project Auditing

Deep analysis of project health, progress, and issues.

```bash
/audit                 # General audit
/audit security        # Security-focused
/audit performance     # Performance analysis
```

**Audit includes:**
- Code quality metrics
- Test coverage
- Documentation completeness
- Security vulnerabilities
- Performance bottlenecks
- Technical debt

## Advanced Features

### Terminal Activity Capture

Comprehensive logging of terminal interactions:

```bash
~/.claude/scripts/capture-terminal-activity.sh
~/.claude/scripts/query-terminal-activity.sh "git commit"
```

### Confidence Scoring

Calculates confidence scores for responses based on:
- Available context
- Similar past successes
- Code preference alignment
- Template effectiveness

### Pattern Aggregation

Identifies recurring patterns across feedback:

```bash
~/.claude/hooks/aggregate-patterns.sh
```

### Session Summaries

Automatic generation of session summaries:

```bash
~/.claude/scripts/log-session-summary.sh
```

## Integration Features

### Git Integration

- Detects git operations
- Tracks commit patterns
- Associates code changes with feedback

### MCP Server Support

Extensible via Model Context Protocol:
- Custom tool integration
- External API access
- Third-party service connectivity

### IDE Integration

- File change detection
- Workspace awareness
- Build system integration

## Customization Features

### Configurable Patterns

Customize feedback detection patterns:
- Edit `~/.claude/config/feedback-patterns.json`
- Add your own phrases
- Tune sensitivity

### Custom Hooks

Create your own event-driven automation:
- Session lifecycle hooks
- Custom trigger conditions
- External script integration

### Custom Slash Commands

Add your own workflows:
- Create `.md` files in `commands/`
- Combine with shell scripts
- Project-specific commands

## Performance Features

### Efficient Database

- SQLite for fast queries
- Indexed searches
- Automatic compaction
- Journal cleanup

### Rate Limiting

Prevents overwhelming the system:

```bash
~/.claude/scripts/rate-limiter.sh
```

### Log Rotation

Automatic cleanup of old logs:

```bash
~/.claude/scripts/rotate-debug-log.sh
```

## Coming Soon

- Multi-user support
- Cloud sync capabilities
- Advanced analytics dashboard
- Cross-project learning
- Team collaboration features
