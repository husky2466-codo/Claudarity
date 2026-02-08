/**
 * Database schema definitions and initialization for Claudarity Memory Store
 * 
 * This module defines the SQLite database schema with all required tables
 * for storing feedback, context, preferences, sessions, templates, and activity.
 */

import Database from 'better-sqlite3';

/**
 * SQL statements for creating all required tables
 */
export const SCHEMA_STATEMENTS = {
  // Feedback log: stores all detected feedback with context
  feedback_log: `
    CREATE TABLE IF NOT EXISTS feedback_log (
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      feedback_type TEXT NOT NULL CHECK(feedback_type IN ('positive', 'negative', 'neutral')),
      confidence REAL NOT NULL CHECK(confidence >= 0 AND confidence <= 1),
      text_content TEXT,
      code_snippet TEXT,
      file_path TEXT,
      suggestion_type TEXT,
      language TEXT,
      operation TEXT,
      matched_patterns TEXT,
      corrected BOOLEAN DEFAULT 0,
      corrected_type TEXT CHECK(corrected_type IN ('positive', 'negative', 'neutral') OR corrected_type IS NULL),
      FOREIGN KEY (session_id) REFERENCES session_log(id)
    )
  `,

  // Context memory: stores reusable context snippets
  context_memory: `
    CREATE TABLE IF NOT EXISTS context_memory (
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      context_type TEXT NOT NULL CHECK(context_type IN ('code_pattern', 'preference', 'solution')),
      content TEXT NOT NULL,
      file_path TEXT,
      language TEXT,
      tags TEXT,
      relevance_score REAL DEFAULT 0.5 CHECK(relevance_score >= 0 AND relevance_score <= 1),
      usage_count INTEGER DEFAULT 0,
      last_used INTEGER,
      FOREIGN KEY (session_id) REFERENCES session_log(id)
    )
  `,

  // Code preferences: stores learned coding preferences
  code_preferences: `
    CREATE TABLE IF NOT EXISTS code_preferences (
      id TEXT PRIMARY KEY,
      category TEXT NOT NULL CHECK(category IN ('error_handling', 'naming', 'structure', 'testing')),
      preference_key TEXT NOT NULL,
      preference_value TEXT NOT NULL,
      confidence REAL NOT NULL CHECK(confidence >= 0 AND confidence <= 1),
      evidence_count INTEGER DEFAULT 1,
      last_updated INTEGER NOT NULL,
      UNIQUE(category, preference_key)
    )
  `,

  // Session log: tracks user sessions
  session_log: `
    CREATE TABLE IF NOT EXISTS session_log (
      id TEXT PRIMARY KEY,
      start_time INTEGER NOT NULL,
      end_time INTEGER,
      project_path TEXT,
      activity_summary TEXT,
      feedback_count INTEGER DEFAULT 0,
      context_injections INTEGER DEFAULT 0
    )
  `,

  // Template evolution: tracks code template learning
  template_evolution: `
    CREATE TABLE IF NOT EXISTS template_evolution (
      id TEXT PRIMARY KEY,
      category TEXT NOT NULL CHECK(category IN ('error_handling', 'naming', 'structure', 'testing')),
      pattern TEXT NOT NULL,
      confidence REAL NOT NULL CHECK(confidence >= 0 AND confidence <= 1),
      alpha REAL NOT NULL CHECK(alpha > 0),
      beta REAL NOT NULL CHECK(beta > 0),
      usage_count INTEGER DEFAULT 0,
      last_used INTEGER,
      archived BOOLEAN DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  `,

  // Template history: tracks template evolution over time
  template_history: `
    CREATE TABLE IF NOT EXISTS template_history (
      id TEXT PRIMARY KEY,
      template_id TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      confidence_before REAL NOT NULL CHECK(confidence_before >= 0 AND confidence_before <= 1),
      confidence_after REAL NOT NULL CHECK(confidence_after >= 0 AND confidence_after <= 1),
      feedback_type TEXT NOT NULL CHECK(feedback_type IN ('positive', 'negative', 'neutral')),
      FOREIGN KEY (template_id) REFERENCES template_evolution(id)
    )
  `,

  // Terminal activity: stores terminal command patterns (optional)
  terminal_activity: `
    CREATE TABLE IF NOT EXISTS terminal_activity (
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      command TEXT NOT NULL,
      exit_code INTEGER,
      duration_ms INTEGER,
      FOREIGN KEY (session_id) REFERENCES session_log(id)
    )
  `,

  // Schema version tracking
  schema_version: `
    CREATE TABLE IF NOT EXISTS schema_version (
      version INTEGER PRIMARY KEY,
      applied_at INTEGER NOT NULL
    )
  `
};

/**
 * Index definitions for optimizing common queries
 */
export const INDEX_STATEMENTS = {
  // Feedback log indexes
  feedback_log_session_idx: `
    CREATE INDEX IF NOT EXISTS idx_feedback_log_session 
    ON feedback_log(session_id)
  `,
  feedback_log_timestamp_idx: `
    CREATE INDEX IF NOT EXISTS idx_feedback_log_timestamp 
    ON feedback_log(timestamp DESC)
  `,
  feedback_log_type_idx: `
    CREATE INDEX IF NOT EXISTS idx_feedback_log_type 
    ON feedback_log(feedback_type)
  `,
  feedback_log_file_idx: `
    CREATE INDEX IF NOT EXISTS idx_feedback_log_file 
    ON feedback_log(file_path)
  `,

  // Context memory indexes
  context_memory_session_idx: `
    CREATE INDEX IF NOT EXISTS idx_context_memory_session 
    ON context_memory(session_id)
  `,
  context_memory_timestamp_idx: `
    CREATE INDEX IF NOT EXISTS idx_context_memory_timestamp 
    ON context_memory(timestamp DESC)
  `,
  context_memory_type_idx: `
    CREATE INDEX IF NOT EXISTS idx_context_memory_type 
    ON context_memory(context_type)
  `,
  context_memory_relevance_idx: `
    CREATE INDEX IF NOT EXISTS idx_context_memory_relevance 
    ON context_memory(relevance_score DESC)
  `,
  context_memory_file_idx: `
    CREATE INDEX IF NOT EXISTS idx_context_memory_file 
    ON context_memory(file_path)
  `,

  // Code preferences indexes
  code_preferences_category_idx: `
    CREATE INDEX IF NOT EXISTS idx_code_preferences_category 
    ON code_preferences(category)
  `,
  code_preferences_confidence_idx: `
    CREATE INDEX IF NOT EXISTS idx_code_preferences_confidence 
    ON code_preferences(confidence DESC)
  `,

  // Session log indexes
  session_log_start_time_idx: `
    CREATE INDEX IF NOT EXISTS idx_session_log_start_time 
    ON session_log(start_time DESC)
  `,
  session_log_project_idx: `
    CREATE INDEX IF NOT EXISTS idx_session_log_project 
    ON session_log(project_path)
  `,

  // Template evolution indexes
  template_evolution_category_idx: `
    CREATE INDEX IF NOT EXISTS idx_template_evolution_category 
    ON template_evolution(category)
  `,
  template_evolution_confidence_idx: `
    CREATE INDEX IF NOT EXISTS idx_template_evolution_confidence 
    ON template_evolution(confidence DESC)
  `,
  template_evolution_archived_idx: `
    CREATE INDEX IF NOT EXISTS idx_template_evolution_archived 
    ON template_evolution(archived)
  `,

  // Template history indexes
  template_history_template_idx: `
    CREATE INDEX IF NOT EXISTS idx_template_history_template 
    ON template_history(template_id)
  `,
  template_history_timestamp_idx: `
    CREATE INDEX IF NOT EXISTS idx_template_history_timestamp 
    ON template_history(timestamp DESC)
  `,

  // Terminal activity indexes
  terminal_activity_session_idx: `
    CREATE INDEX IF NOT EXISTS idx_terminal_activity_session 
    ON terminal_activity(session_id)
  `,
  terminal_activity_timestamp_idx: `
    CREATE INDEX IF NOT EXISTS idx_terminal_activity_timestamp 
    ON terminal_activity(timestamp DESC)
  `
};

/**
 * Initialize the database schema
 * Creates all tables and indexes if they don't exist
 * 
 * @param db - Better-sqlite3 database instance
 */
export function initializeSchema(db: Database.Database): void {
  // Enable foreign key constraints
  db.pragma('foreign_keys = ON');

  // Create all tables
  for (const [tableName, statement] of Object.entries(SCHEMA_STATEMENTS)) {
    try {
      db.exec(statement);
    } catch (error) {
      throw new Error(`Failed to create table ${tableName}: ${error}`);
    }
  }

  // Create all indexes
  for (const [indexName, statement] of Object.entries(INDEX_STATEMENTS)) {
    try {
      db.exec(statement);
    } catch (error) {
      throw new Error(`Failed to create index ${indexName}: ${error}`);
    }
  }

  // Initialize schema version if not exists
  const versionCheck = db.prepare('SELECT version FROM schema_version ORDER BY version DESC LIMIT 1').get() as { version: number } | undefined;
  
  if (!versionCheck) {
    // Insert initial schema version
    const now = Math.floor(Date.now() / 1000);
    db.prepare('INSERT INTO schema_version (version, applied_at) VALUES (?, ?)').run(1, now);
  }
}

/**
 * Get the current schema version
 * 
 * @param db - Better-sqlite3 database instance
 * @returns Current schema version number
 */
export function getCurrentSchemaVersion(db: Database.Database): number {
  try {
    const result = db.prepare('SELECT version FROM schema_version ORDER BY version DESC LIMIT 1').get() as { version: number } | undefined;
    return result?.version ?? 0;
  } catch (error) {
    // Table doesn't exist yet
    return 0;
  }
}

/**
 * Verify that all required tables exist
 * 
 * @param db - Better-sqlite3 database instance
 * @returns true if all tables exist, false otherwise
 */
export function verifySchema(db: Database.Database): boolean {
  const requiredTables = [
    'feedback_log',
    'context_memory',
    'code_preferences',
    'session_log',
    'template_evolution',
    'template_history',
    'terminal_activity',
    'schema_version'
  ];

  for (const tableName of requiredTables) {
    const result = db.prepare(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?"
    ).get(tableName);
    
    if (!result) {
      return false;
    }
  }

  return true;
}
