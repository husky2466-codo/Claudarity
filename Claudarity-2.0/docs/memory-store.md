# Memory Store

The Memory Store is the data persistence layer for Claudarity, providing CRUD operations for all data types including feedback, context, preferences, sessions, and templates.

## Overview

The Memory Store uses SQLite for local-only data storage and provides a type-safe interface for all database operations. It integrates with the platform abstraction layer to ensure cross-platform compatibility.

## Architecture

```
┌─────────────────────────────────────┐
│      Application Layer              │
│  (Learning Engine, Context Injector)│
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│       Memory Store Interface        │
│  (MemoryStoreImpl)                  │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│         SQLite Database             │
│  (feedback, context, preferences,   │
│   sessions, templates)              │
└─────────────────────────────────────┘
```

## Data Models

### FeedbackEntry
Stores detected feedback with context:
- `id`: Unique identifier
- `session_id`: Associated session
- `timestamp`: Unix timestamp
- `feedback_type`: 'positive' | 'negative' | 'neutral'
- `confidence`: 0-1 confidence score
- `text_content`: Original feedback text
- `code_snippet`: Associated code
- `file_path`: File being edited
- `suggestion_type`: Type of suggestion
- `language`: Programming language
- `operation`: Operation type
- `matched_patterns`: JSON array of matched patterns
- `corrected`: Whether feedback was manually corrected
- `corrected_type`: Corrected feedback type

### ContextEntry
Stores reusable context snippets:
- `id`: Unique identifier
- `session_id`: Associated session
- `timestamp`: Unix timestamp
- `context_type`: 'code_pattern' | 'preference' | 'solution'
- `content`: Context content
- `file_path`: Associated file
- `language`: Programming language
- `tags`: JSON array of tags
- `relevance_score`: 0-1 relevance score
- `usage_count`: Number of times used
- `last_used`: Last usage timestamp

### PreferenceEntry
Stores learned coding preferences:
- `id`: Unique identifier
- `category`: 'error_handling' | 'naming' | 'structure' | 'testing'
- `preference_key`: Preference identifier
- `preference_value`: Preference value
- `confidence`: 0-1 confidence score
- `evidence_count`: Number of supporting examples
- `last_updated`: Last update timestamp

### Session
Tracks user sessions:
- `id`: Unique identifier
- `start_time`: Session start timestamp
- `end_time`: Session end timestamp (optional)
- `project_path`: Project directory
- `activity_summary`: Summary of session activity
- `feedback_count`: Number of feedback entries
- `context_injections`: Number of context injections

### Template
Tracks code template evolution:
- `id`: Unique identifier
- `category`: 'error_handling' | 'naming' | 'structure' | 'testing'
- `pattern`: Template pattern
- `confidence`: 0-1 confidence score
- `alpha`: Beta distribution alpha parameter
- `beta`: Beta distribution beta parameter
- `usage_count`: Number of times used
- `last_used`: Last usage timestamp
- `archived`: Whether template is archived
- `created_at`: Creation timestamp
- `updated_at`: Last update timestamp

## API Reference

### Feedback Operations

#### `storeFeedback(feedback: FeedbackEntry): void`
Stores a feedback entry in the database.

```typescript
memoryStore.storeFeedback({
  id: 'feedback-1',
  session_id: 'session-1',
  timestamp: Date.now(),
  feedback_type: 'positive',
  confidence: 0.9,
  text_content: 'looks good',
});
```

#### `queryFeedback(filter: FeedbackFilter): FeedbackEntry[]`
Queries feedback entries with optional filters.

```typescript
const feedback = memoryStore.queryFeedback({
  session_id: 'session-1',
  feedback_type: 'positive',
  start_time: Date.now() - 86400000, // Last 24 hours
  limit: 10,
});
```

**Filter Options:**
- `session_id`: Filter by session
- `feedback_type`: Filter by type
- `file_path`: Filter by file
- `start_time`: Minimum timestamp
- `end_time`: Maximum timestamp
- `limit`: Maximum results

### Context Operations

#### `storeContext(context: ContextEntry): void`
Stores a context entry in the database.

```typescript
memoryStore.storeContext({
  id: 'context-1',
  session_id: 'session-1',
  timestamp: Date.now(),
  context_type: 'code_pattern',
  content: 'Use early returns for error handling',
  relevance_score: 0.85,
});
```

#### `queryContext(filter: ContextFilter): ContextEntry[]`
Queries context entries with optional filters.

```typescript
const context = memoryStore.queryContext({
  context_type: 'code_pattern',
  min_relevance: 0.7,
  language: 'typescript',
  limit: 5,
});
```

**Filter Options:**
- `session_id`: Filter by session
- `context_type`: Filter by type
- `file_path`: Filter by file
- `language`: Filter by language
- `min_relevance`: Minimum relevance score
- `start_time`: Minimum timestamp
- `end_time`: Maximum timestamp
- `limit`: Maximum results

### Preference Operations

#### `storePreference(pref: PreferenceEntry): void`
Stores or updates a preference entry. Uses UPSERT logic based on (category, preference_key).

```typescript
memoryStore.storePreference({
  id: 'pref-1',
  category: 'error_handling',
  preference_key: 'use_early_returns',
  preference_value: 'true',
  confidence: 0.85,
  last_updated: Date.now(),
});
```

#### `queryPreferences(filter: PreferenceFilter): PreferenceEntry[]`
Queries preference entries with optional filters.

```typescript
const preferences = memoryStore.queryPreferences({
  category: 'error_handling',
  min_confidence: 0.8,
  limit: 10,
});
```

**Filter Options:**
- `category`: Filter by category
- `preference_key`: Filter by key
- `min_confidence`: Minimum confidence score
- `limit`: Maximum results

### Session Operations

#### `createSession(session: Session): string`
Creates a new session and returns its ID.

```typescript
const sessionId = memoryStore.createSession({
  id: 'session-1',
  start_time: Date.now(),
  project_path: '/path/to/project',
});
```

#### `updateSession(sessionId: string, updates: Partial<Session>): void`
Updates session fields.

```typescript
memoryStore.updateSession('session-1', {
  end_time: Date.now(),
  feedback_count: 5,
  activity_summary: 'Implemented feature X',
});
```

#### `querySession(filter: SessionFilter): Session[]`
Queries session entries with optional filters.

```typescript
const sessions = memoryStore.querySession({
  project_path: '/path/to/project',
  start_time: Date.now() - 604800000, // Last 7 days
  limit: 10,
});
```

**Filter Options:**
- `project_path`: Filter by project
- `start_time`: Minimum start time
- `end_time`: Maximum start time
- `limit`: Maximum results

### Template Operations

#### `storeTemplate(template: Template): void`
Stores a template entry in the database.

```typescript
memoryStore.storeTemplate({
  id: 'template-1',
  category: 'error_handling',
  pattern: 'try-catch with specific error types',
  confidence: 0.85,
  alpha: 17,
  beta: 3,
  created_at: Date.now(),
  updated_at: Date.now(),
});
```

#### `updateTemplate(templateId: string, updates: Partial<Template>): void`
Updates template fields.

```typescript
memoryStore.updateTemplate('template-1', {
  confidence: 0.9,
  alpha: 18,
  beta: 2,
  usage_count: 20,
  updated_at: Date.now(),
});
```

#### `queryTemplates(filter: TemplateFilter): Template[]`
Queries template entries with optional filters.

```typescript
const templates = memoryStore.queryTemplates({
  category: 'error_handling',
  min_confidence: 0.8,
  archived: false,
  limit: 10,
});
```

**Filter Options:**
- `category`: Filter by category
- `min_confidence`: Minimum confidence score
- `archived`: Filter by archived status
- `limit`: Maximum results

### Database Management

#### `close(): void`
Closes the database connection.

```typescript
memoryStore.close();
```

## Integration with Platform Abstraction

The Memory Store should be initialized with a database path obtained from the platform abstraction layer:

```typescript
import { PlatformAbstractionImpl } from './platform';
import { MemoryStoreImpl } from './database';

const platform = new PlatformAbstractionImpl();
const dataDir = platform.getDataDir();
const dbPath = platform.joinPath(dataDir, 'claudarity', 'memory.db');

// Ensure directory exists
await platform.createDirectory(platform.joinPath(dataDir, 'claudarity'));

// Initialize Memory Store
const memoryStore = new MemoryStoreImpl(dbPath);
```

This ensures:
- Windows: Database stored in `%APPDATA%\claudarity\memory.db`
- macOS: Database stored in `~/Library/Application Support/claudarity/memory.db`
- Linux: Database stored in `~/.local/share/claudarity/memory.db`

## Query Performance

All queries are optimized with appropriate indexes:

- **Feedback queries**: Indexed by session_id, timestamp, feedback_type, file_path
- **Context queries**: Indexed by session_id, timestamp, context_type, relevance_score, file_path
- **Preference queries**: Indexed by category, confidence
- **Session queries**: Indexed by start_time, project_path
- **Template queries**: Indexed by category, confidence, archived

## Foreign Key Relationships

The database enforces referential integrity:

- `feedback_log.session_id` → `session_log.id`
- `context_memory.session_id` → `session_log.id`
- `template_history.template_id` → `template_evolution.id`
- `terminal_activity.session_id` → `session_log.id`

## Error Handling

All database operations may throw errors. Recommended error handling:

```typescript
try {
  memoryStore.storeFeedback(feedback);
} catch (error) {
  console.error('Failed to store feedback:', error);
  // Handle error (retry, log, notify user)
}
```

Common errors:
- **SQLITE_CONSTRAINT**: Constraint violation (e.g., invalid feedback_type)
- **SQLITE_BUSY**: Database locked (retry with backoff)
- **SQLITE_CORRUPT**: Database corruption (restore from backup)

## Testing

The Memory Store includes comprehensive unit tests covering:
- All CRUD operations
- Filter combinations
- Ordering and limits
- Foreign key relationships
- Constraint enforcement
- Edge cases (empty queries, updates with no changes)

Run tests:
```bash
npm test -- MemoryStore.test.ts
```

## Requirements Validation

This implementation satisfies:
- **Requirement 4.2**: Configurable database location via platform abstraction
- **Requirement 4.3**: Database initialization with correct schema
- All CRUD operations specified in the design document
