/**
 * Memory Store Implementation
 * Provides CRUD operations for the Claudarity database
 */

import Database from 'better-sqlite3';
import { initializeSchema, getCurrentSchemaVersion, verifySchema } from './schema';
import { existsSync, copyFileSync, unlinkSync } from 'fs';
import { dirname } from 'path';
import { mkdirSync } from 'fs';
import type {
  MemoryStore,
  FeedbackEntry,
  FeedbackFilter,
  ContextEntry,
  ContextFilter,
  PreferenceEntry,
  PreferenceFilter,
  Session,
  SessionFilter,
  Template,
  TemplateFilter,
  ExportResult,
  ImportResult
} from './types';

export class MemoryStoreImpl implements MemoryStore {
  private db: Database.Database;

  constructor(dbPath: string) {
    this.db = new Database(dbPath);
    initializeSchema(this.db);
  }

  // ==================== Feedback Operations ====================

  storeFeedback(feedback: FeedbackEntry): void {
    const stmt = this.db.prepare(`
      INSERT INTO feedback_log (
        id, session_id, timestamp, feedback_type, confidence,
        text_content, code_snippet, file_path, suggestion_type,
        language, operation, matched_patterns, corrected, corrected_type
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      feedback.id,
      feedback.session_id,
      feedback.timestamp,
      feedback.feedback_type,
      feedback.confidence,
      feedback.text_content ?? null,
      feedback.code_snippet ?? null,
      feedback.file_path ?? null,
      feedback.suggestion_type ?? null,
      feedback.language ?? null,
      feedback.operation ?? null,
      feedback.matched_patterns ?? null,
      feedback.corrected ?? 0,
      feedback.corrected_type ?? null
    );
  }

  queryFeedback(filter: FeedbackFilter): FeedbackEntry[] {
    let query = 'SELECT * FROM feedback_log WHERE 1=1';
    const params: any[] = [];

    if (filter.session_id) {
      query += ' AND session_id = ?';
      params.push(filter.session_id);
    }

    if (filter.feedback_type) {
      query += ' AND feedback_type = ?';
      params.push(filter.feedback_type);
    }

    if (filter.file_path) {
      query += ' AND file_path = ?';
      params.push(filter.file_path);
    }

    if (filter.start_time) {
      query += ' AND timestamp >= ?';
      params.push(filter.start_time);
    }

    if (filter.end_time) {
      query += ' AND timestamp <= ?';
      params.push(filter.end_time);
    }

    query += ' ORDER BY timestamp DESC';

    if (filter.limit) {
      query += ' LIMIT ?';
      params.push(filter.limit);
    }

    const stmt = this.db.prepare(query);
    return stmt.all(...params) as FeedbackEntry[];
  }

  // ==================== Context Operations ====================

  storeContext(context: ContextEntry): void {
    const stmt = this.db.prepare(`
      INSERT INTO context_memory (
        id, session_id, timestamp, context_type, content,
        file_path, language, tags, relevance_score,
        usage_count, last_used
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      context.id,
      context.session_id,
      context.timestamp,
      context.context_type,
      context.content,
      context.file_path ?? null,
      context.language ?? null,
      context.tags ?? null,
      context.relevance_score ?? 0.5,
      context.usage_count ?? 0,
      context.last_used ?? null
    );
  }

  queryContext(filter: ContextFilter): ContextEntry[] {
    let query = 'SELECT * FROM context_memory WHERE 1=1';
    const params: any[] = [];

    if (filter.session_id) {
      query += ' AND session_id = ?';
      params.push(filter.session_id);
    }

    if (filter.context_type) {
      query += ' AND context_type = ?';
      params.push(filter.context_type);
    }

    if (filter.file_path) {
      query += ' AND file_path = ?';
      params.push(filter.file_path);
    }

    if (filter.language) {
      query += ' AND language = ?';
      params.push(filter.language);
    }

    if (filter.min_relevance !== undefined) {
      query += ' AND relevance_score >= ?';
      params.push(filter.min_relevance);
    }

    if (filter.start_time) {
      query += ' AND timestamp >= ?';
      params.push(filter.start_time);
    }

    if (filter.end_time) {
      query += ' AND timestamp <= ?';
      params.push(filter.end_time);
    }

    query += ' ORDER BY relevance_score DESC, timestamp DESC';

    if (filter.limit) {
      query += ' LIMIT ?';
      params.push(filter.limit);
    }

    const stmt = this.db.prepare(query);
    return stmt.all(...params) as ContextEntry[];
  }

  // ==================== Preference Operations ====================

  storePreference(pref: PreferenceEntry): void {
    const stmt = this.db.prepare(`
      INSERT INTO code_preferences (
        id, category, preference_key, preference_value,
        confidence, evidence_count, last_updated
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(category, preference_key) DO UPDATE SET
        preference_value = excluded.preference_value,
        confidence = excluded.confidence,
        evidence_count = excluded.evidence_count,
        last_updated = excluded.last_updated
    `);

    stmt.run(
      pref.id,
      pref.category,
      pref.preference_key,
      pref.preference_value,
      pref.confidence,
      pref.evidence_count ?? 1,
      pref.last_updated
    );
  }

  queryPreferences(filter: PreferenceFilter): PreferenceEntry[] {
    let query = 'SELECT * FROM code_preferences WHERE 1=1';
    const params: any[] = [];

    if (filter.category) {
      query += ' AND category = ?';
      params.push(filter.category);
    }

    if (filter.preference_key) {
      query += ' AND preference_key = ?';
      params.push(filter.preference_key);
    }

    if (filter.min_confidence !== undefined) {
      query += ' AND confidence >= ?';
      params.push(filter.min_confidence);
    }

    query += ' ORDER BY confidence DESC';

    if (filter.limit) {
      query += ' LIMIT ?';
      params.push(filter.limit);
    }

    const stmt = this.db.prepare(query);
    return stmt.all(...params) as PreferenceEntry[];
  }

  // ==================== Session Operations ====================

  createSession(session: Session): string {
    const stmt = this.db.prepare(`
      INSERT INTO session_log (
        id, start_time, end_time, project_path,
        activity_summary, feedback_count, context_injections
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      session.id,
      session.start_time,
      session.end_time ?? null,
      session.project_path ?? null,
      session.activity_summary ?? null,
      session.feedback_count ?? 0,
      session.context_injections ?? 0
    );

    return session.id;
  }

  updateSession(sessionId: string, updates: Partial<Session>): void {
    const fields: string[] = [];
    const params: any[] = [];

    if (updates.end_time !== undefined) {
      fields.push('end_time = ?');
      params.push(updates.end_time);
    }

    if (updates.project_path !== undefined) {
      fields.push('project_path = ?');
      params.push(updates.project_path);
    }

    if (updates.activity_summary !== undefined) {
      fields.push('activity_summary = ?');
      params.push(updates.activity_summary);
    }

    if (updates.feedback_count !== undefined) {
      fields.push('feedback_count = ?');
      params.push(updates.feedback_count);
    }

    if (updates.context_injections !== undefined) {
      fields.push('context_injections = ?');
      params.push(updates.context_injections);
    }

    if (fields.length === 0) {
      return; // No updates to apply
    }

    params.push(sessionId);
    const query = `UPDATE session_log SET ${fields.join(', ')} WHERE id = ?`;
    const stmt = this.db.prepare(query);
    stmt.run(...params);
  }

  querySession(filter: SessionFilter): Session[] {
    let query = 'SELECT * FROM session_log WHERE 1=1';
    const params: any[] = [];

    if (filter.project_path) {
      query += ' AND project_path = ?';
      params.push(filter.project_path);
    }

    if (filter.start_time) {
      query += ' AND start_time >= ?';
      params.push(filter.start_time);
    }

    if (filter.end_time) {
      query += ' AND start_time <= ?';
      params.push(filter.end_time);
    }

    query += ' ORDER BY start_time DESC';

    if (filter.limit) {
      query += ' LIMIT ?';
      params.push(filter.limit);
    }

    const stmt = this.db.prepare(query);
    return stmt.all(...params) as Session[];
  }

  // ==================== Template Operations ====================

  storeTemplate(template: Template): void {
    const stmt = this.db.prepare(`
      INSERT INTO template_evolution (
        id, category, pattern, confidence, alpha, beta,
        usage_count, last_used, archived, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      template.id,
      template.category,
      template.pattern,
      template.confidence,
      template.alpha,
      template.beta,
      template.usage_count ?? 0,
      template.last_used ?? null,
      template.archived ? 1 : 0,
      template.created_at,
      template.updated_at
    );
  }

  updateTemplate(templateId: string, updates: Partial<Template>): void {
    const fields: string[] = [];
    const params: any[] = [];

    if (updates.pattern !== undefined) {
      fields.push('pattern = ?');
      params.push(updates.pattern);
    }

    if (updates.confidence !== undefined) {
      fields.push('confidence = ?');
      params.push(updates.confidence);
    }

    if (updates.alpha !== undefined) {
      fields.push('alpha = ?');
      params.push(updates.alpha);
    }

    if (updates.beta !== undefined) {
      fields.push('beta = ?');
      params.push(updates.beta);
    }

    if (updates.usage_count !== undefined) {
      fields.push('usage_count = ?');
      params.push(updates.usage_count);
    }

    if (updates.last_used !== undefined) {
      fields.push('last_used = ?');
      params.push(updates.last_used);
    }

    if (updates.archived !== undefined) {
      fields.push('archived = ?');
      params.push(updates.archived ? 1 : 0);
    }

    if (updates.updated_at !== undefined) {
      fields.push('updated_at = ?');
      params.push(updates.updated_at);
    }

    if (fields.length === 0) {
      return; // No updates to apply
    }

    params.push(templateId);
    const query = `UPDATE template_evolution SET ${fields.join(', ')} WHERE id = ?`;
    const stmt = this.db.prepare(query);
    stmt.run(...params);
  }

  queryTemplates(filter: TemplateFilter): Template[] {
    let query = 'SELECT * FROM template_evolution WHERE 1=1';
    const params: any[] = [];

    if (filter.category) {
      query += ' AND category = ?';
      params.push(filter.category);
    }

    if (filter.min_confidence !== undefined) {
      query += ' AND confidence >= ?';
      params.push(filter.min_confidence);
    }

    if (filter.archived !== undefined) {
      query += ' AND archived = ?';
      params.push(filter.archived ? 1 : 0);
    }

    query += ' ORDER BY confidence DESC';

    if (filter.limit) {
      query += ' LIMIT ?';
      params.push(filter.limit);
    }

    const stmt = this.db.prepare(query);
    return stmt.all(...params) as Template[];
  }

  // ==================== Database Management ====================

  /**
   * Export the database to a portable backup file
   * Creates a complete copy of the database at the specified path
   * 
   * @param path - Destination path for the exported database
   * @returns ExportResult with success status and metadata
   */
  exportDatabase(path: string): ExportResult {
    try {
      // Ensure the destination directory exists
      const dir = dirname(path);
      if (!existsSync(dir)) {
        mkdirSync(dir, { recursive: true });
      }

      // Check if database is open
      if (!this.db.open) {
        return {
          success: false,
          path,
          recordCount: 0,
          error: 'Database connection is not open'
        };
      }

      // Use SQLite's VACUUM INTO for a clean export
      // This creates a complete, optimized copy of the database
      this.db.prepare(`VACUUM INTO ?`).run(path);

      // Count total records across all tables
      const tables = [
        'feedback_log',
        'context_memory',
        'code_preferences',
        'session_log',
        'template_evolution',
        'template_history',
        'terminal_activity'
      ];

      let totalRecords = 0;
      for (const table of tables) {
        const result = this.db.prepare(`SELECT COUNT(*) as count FROM ${table}`).get() as { count: number };
        totalRecords += result.count;
      }

      return {
        success: true,
        path,
        recordCount: totalRecords
      };
    } catch (error) {
      return {
        success: false,
        path,
        recordCount: 0,
        error: error instanceof Error ? error.message : String(error)
      };
    }
  }

  /**
   * Import data from a backup database file
   * Supports both merge (add new data) and replace (clear and import) strategies
   * 
   * @param path - Source path of the database to import
   * @param strategy - 'merge' to add data, 'replace' to clear and import
   * @returns ImportResult with success status and statistics
   */
  importDatabase(path: string, strategy: 'merge' | 'replace'): ImportResult {
    const errors: string[] = [];
    let recordsImported = 0;
    let recordsSkipped = 0;

    try {
      // Validate source database exists
      if (!existsSync(path)) {
        return {
          success: false,
          recordsImported: 0,
          recordsSkipped: 0,
          errors: [`Source database not found: ${path}`]
        };
      }

      // Open source database
      const sourceDb = new Database(path, { readonly: true });

      try {
        // Validate schema compatibility
        const sourceVersion = getCurrentSchemaVersion(sourceDb);
        const targetVersion = getCurrentSchemaVersion(this.db);

        if (sourceVersion > targetVersion) {
          return {
            success: false,
            recordsImported: 0,
            recordsSkipped: 0,
            errors: [
              `Schema version mismatch: source version ${sourceVersion} is newer than target version ${targetVersion}. ` +
              `Please upgrade the target database first.`
            ]
          };
        }

        // Verify source database has valid schema
        if (!verifySchema(sourceDb)) {
          return {
            success: false,
            recordsImported: 0,
            recordsSkipped: 0,
            errors: ['Source database has invalid or incomplete schema']
          };
        }

        // If replace strategy, clear all data first
        if (strategy === 'replace') {
          this.clearAllData();
        }

        // Import data from each table in dependency order
        const importOrder = [
          'session_log',           // No dependencies
          'feedback_log',          // Depends on session_log
          'context_memory',        // Depends on session_log
          'terminal_activity',     // Depends on session_log
          'code_preferences',      // No dependencies
          'template_evolution',    // No dependencies
          'template_history'       // Depends on template_evolution
        ];

        // Begin transaction for atomic import
        const transaction = this.db.transaction(() => {
          for (const tableName of importOrder) {
            try {
              const result = this.importTable(sourceDb, tableName, strategy);
              recordsImported += result.imported;
              recordsSkipped += result.skipped;
              if (result.errors.length > 0) {
                errors.push(...result.errors);
              }
            } catch (error) {
              const errorMsg = `Failed to import table ${tableName}: ${error instanceof Error ? error.message : String(error)}`;
              errors.push(errorMsg);
            }
          }
        });

        transaction();

        return {
          success: errors.length === 0,
          recordsImported,
          recordsSkipped,
          errors
        };
      } finally {
        sourceDb.close();
      }
    } catch (error) {
      return {
        success: false,
        recordsImported,
        recordsSkipped,
        errors: [error instanceof Error ? error.message : String(error)]
      };
    }
  }

  /**
   * Clear all data from the database (used for replace strategy)
   * Preserves schema and indexes
   */
  private clearAllData(): void {
    const tables = [
      'template_history',
      'terminal_activity',
      'feedback_log',
      'context_memory',
      'code_preferences',
      'template_evolution',
      'session_log'
    ];

    for (const table of tables) {
      this.db.prepare(`DELETE FROM ${table}`).run();
    }
  }

  /**
   * Import data from a single table
   * 
   * @param sourceDb - Source database to import from
   * @param tableName - Name of the table to import
   * @param strategy - Import strategy (merge or replace)
   * @returns Statistics about the import operation
   */
  private importTable(
    sourceDb: Database.Database,
    tableName: string,
    strategy: 'merge' | 'replace'
  ): { imported: number; skipped: number; errors: string[] } {
    let imported = 0;
    let skipped = 0;
    const errors: string[] = [];

    try {
      // Get all rows from source table
      const rows = sourceDb.prepare(`SELECT * FROM ${tableName}`).all();

      if (rows.length === 0) {
        return { imported: 0, skipped: 0, errors: [] };
      }

      // Get column names from first row
      const columns = Object.keys(rows[0]);
      const placeholders = columns.map(() => '?').join(', ');
      const columnList = columns.join(', ');

      // Prepare insert statement
      let insertSql: string;
      if (strategy === 'merge') {
        // For merge, use INSERT OR IGNORE to skip duplicates
        insertSql = `INSERT OR IGNORE INTO ${tableName} (${columnList}) VALUES (${placeholders})`;
      } else {
        // For replace, use INSERT OR REPLACE to overwrite duplicates
        insertSql = `INSERT OR REPLACE INTO ${tableName} (${columnList}) VALUES (${placeholders})`;
      }

      const insertStmt = this.db.prepare(insertSql);

      // Import each row
      for (const row of rows) {
        try {
          const values = columns.map(col => (row as any)[col]);
          const result = insertStmt.run(...values);
          
          if (result.changes > 0) {
            imported++;
          } else {
            skipped++;
          }
        } catch (error) {
          skipped++;
          errors.push(
            `Failed to import row in ${tableName}: ${error instanceof Error ? error.message : String(error)}`
          );
        }
      }
    } catch (error) {
      errors.push(
        `Failed to import table ${tableName}: ${error instanceof Error ? error.message : String(error)}`
      );
    }

    return { imported, skipped, errors };
  }

  close(): void {
    this.db.close();
  }
}
