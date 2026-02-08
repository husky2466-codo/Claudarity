/**
 * Tests for database schema initialization
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import Database from 'better-sqlite3';
import { initializeSchema, getCurrentSchemaVersion, verifySchema } from './schema';
import { tmpdir } from 'os';
import { join } from 'path';
import { unlinkSync, existsSync } from 'fs';

describe('Database Schema', () => {
  let db: Database.Database;
  let dbPath: string;

  beforeEach(() => {
    // Create a temporary database for testing
    dbPath = join(tmpdir(), `claudarity-test-${Date.now()}.db`);
    db = new Database(dbPath);
  });

  afterEach(() => {
    // Clean up
    if (db) {
      db.close();
    }
    if (existsSync(dbPath)) {
      unlinkSync(dbPath);
    }
  });

  describe('initializeSchema', () => {
    it('should create all required tables', () => {
      initializeSchema(db);

      const tables = db.prepare(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
      ).all() as { name: string }[];

      const tableNames = tables.map(t => t.name);
      
      expect(tableNames).toContain('feedback_log');
      expect(tableNames).toContain('context_memory');
      expect(tableNames).toContain('code_preferences');
      expect(tableNames).toContain('session_log');
      expect(tableNames).toContain('template_evolution');
      expect(tableNames).toContain('template_history');
      expect(tableNames).toContain('terminal_activity');
      expect(tableNames).toContain('schema_version');
    });

    it('should create all required indexes', () => {
      initializeSchema(db);

      const indexes = db.prepare(
        "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%' ORDER BY name"
      ).all() as { name: string }[];

      const indexNames = indexes.map(i => i.name);
      
      // Check for some key indexes
      expect(indexNames).toContain('idx_feedback_log_session');
      expect(indexNames).toContain('idx_feedback_log_timestamp');
      expect(indexNames).toContain('idx_context_memory_session');
      expect(indexNames).toContain('idx_context_memory_timestamp');
      expect(indexNames).toContain('idx_session_log_start_time');
      expect(indexNames).toContain('idx_template_evolution_category');
    });

    it('should initialize schema version to 1', () => {
      initializeSchema(db);

      const version = getCurrentSchemaVersion(db);
      expect(version).toBe(1);
    });

    it('should enable foreign key constraints', () => {
      initializeSchema(db);

      const result = db.pragma('foreign_keys', { simple: true });
      expect(result).toBe(1);
    });

    it('should be idempotent (can be called multiple times)', () => {
      initializeSchema(db);
      initializeSchema(db);
      initializeSchema(db);

      expect(verifySchema(db)).toBe(true);
      expect(getCurrentSchemaVersion(db)).toBe(1);
    });
  });

  describe('verifySchema', () => {
    it('should return false for empty database', () => {
      expect(verifySchema(db)).toBe(false);
    });

    it('should return true after schema initialization', () => {
      initializeSchema(db);
      expect(verifySchema(db)).toBe(true);
    });

    it('should return false if a table is missing', () => {
      initializeSchema(db);
      
      // Drop one table
      db.exec('DROP TABLE terminal_activity');
      
      expect(verifySchema(db)).toBe(false);
    });
  });

  describe('getCurrentSchemaVersion', () => {
    it('should return 0 for uninitialized database', () => {
      expect(getCurrentSchemaVersion(db)).toBe(0);
    });

    it('should return 1 after initialization', () => {
      initializeSchema(db);
      expect(getCurrentSchemaVersion(db)).toBe(1);
    });
  });

  describe('Table Constraints', () => {
    beforeEach(() => {
      initializeSchema(db);
    });

    it('should enforce feedback_type CHECK constraint', () => {
      const sessionId = 'test-session';
      db.prepare('INSERT INTO session_log (id, start_time) VALUES (?, ?)').run(sessionId, Date.now());

      // Valid feedback type should work
      expect(() => {
        db.prepare(`
          INSERT INTO feedback_log (id, session_id, timestamp, feedback_type, confidence)
          VALUES (?, ?, ?, ?, ?)
        `).run('test-1', sessionId, Date.now(), 'positive', 0.9);
      }).not.toThrow();

      // Invalid feedback type should fail
      expect(() => {
        db.prepare(`
          INSERT INTO feedback_log (id, session_id, timestamp, feedback_type, confidence)
          VALUES (?, ?, ?, ?, ?)
        `).run('test-2', sessionId, Date.now(), 'invalid', 0.9);
      }).toThrow();
    });

    it('should enforce confidence range CHECK constraint', () => {
      const sessionId = 'test-session';
      db.prepare('INSERT INTO session_log (id, start_time) VALUES (?, ?)').run(sessionId, Date.now());

      // Valid confidence should work
      expect(() => {
        db.prepare(`
          INSERT INTO feedback_log (id, session_id, timestamp, feedback_type, confidence)
          VALUES (?, ?, ?, ?, ?)
        `).run('test-1', sessionId, Date.now(), 'positive', 0.5);
      }).not.toThrow();

      // Confidence > 1 should fail
      expect(() => {
        db.prepare(`
          INSERT INTO feedback_log (id, session_id, timestamp, feedback_type, confidence)
          VALUES (?, ?, ?, ?, ?)
        `).run('test-2', sessionId, Date.now(), 'positive', 1.5);
      }).toThrow();

      // Confidence < 0 should fail
      expect(() => {
        db.prepare(`
          INSERT INTO feedback_log (id, session_id, timestamp, feedback_type, confidence)
          VALUES (?, ?, ?, ?, ?)
        `).run('test-3', sessionId, Date.now(), 'positive', -0.1);
      }).toThrow();
    });

    it('should enforce category CHECK constraint in code_preferences', () => {
      // Valid category should work
      expect(() => {
        db.prepare(`
          INSERT INTO code_preferences (id, category, preference_key, preference_value, confidence, last_updated)
          VALUES (?, ?, ?, ?, ?, ?)
        `).run('test-1', 'error_handling', 'key1', 'value1', 0.8, Date.now());
      }).not.toThrow();

      // Invalid category should fail
      expect(() => {
        db.prepare(`
          INSERT INTO code_preferences (id, category, preference_key, preference_value, confidence, last_updated)
          VALUES (?, ?, ?, ?, ?, ?)
        `).run('test-2', 'invalid_category', 'key2', 'value2', 0.8, Date.now());
      }).toThrow();
    });

    it('should enforce UNIQUE constraint on code_preferences (category, preference_key)', () => {
      db.prepare(`
        INSERT INTO code_preferences (id, category, preference_key, preference_value, confidence, last_updated)
        VALUES (?, ?, ?, ?, ?, ?)
      `).run('test-1', 'naming', 'camelCase', 'true', 0.9, Date.now());

      // Duplicate (category, preference_key) should fail
      expect(() => {
        db.prepare(`
          INSERT INTO code_preferences (id, category, preference_key, preference_value, confidence, last_updated)
          VALUES (?, ?, ?, ?, ?, ?)
        `).run('test-2', 'naming', 'camelCase', 'false', 0.8, Date.now());
      }).toThrow();
    });

    it('should enforce alpha and beta positive CHECK constraints', () => {
      // Valid alpha and beta should work
      expect(() => {
        db.prepare(`
          INSERT INTO template_evolution (id, category, pattern, confidence, alpha, beta, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `).run('test-1', 'testing', 'pattern1', 0.5, 1.0, 1.0, Date.now(), Date.now());
      }).not.toThrow();

      // Alpha = 0 should fail
      expect(() => {
        db.prepare(`
          INSERT INTO template_evolution (id, category, pattern, confidence, alpha, beta, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `).run('test-2', 'testing', 'pattern2', 0.5, 0, 1.0, Date.now(), Date.now());
      }).toThrow();

      // Beta < 0 should fail
      expect(() => {
        db.prepare(`
          INSERT INTO template_evolution (id, category, pattern, confidence, alpha, beta, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `).run('test-3', 'testing', 'pattern3', 0.5, 1.0, -1.0, Date.now(), Date.now());
      }).toThrow();
    });

    it('should enforce foreign key constraint on feedback_log', () => {
      // Insert without valid session should fail (with foreign keys enabled)
      expect(() => {
        db.prepare(`
          INSERT INTO feedback_log (id, session_id, timestamp, feedback_type, confidence)
          VALUES (?, ?, ?, ?, ?)
        `).run('test-1', 'nonexistent-session', Date.now(), 'positive', 0.9);
      }).toThrow();

      // Insert with valid session should work
      const sessionId = 'valid-session';
      db.prepare('INSERT INTO session_log (id, start_time) VALUES (?, ?)').run(sessionId, Date.now());
      
      expect(() => {
        db.prepare(`
          INSERT INTO feedback_log (id, session_id, timestamp, feedback_type, confidence)
          VALUES (?, ?, ?, ?, ?)
        `).run('test-2', sessionId, Date.now(), 'positive', 0.9);
      }).not.toThrow();
    });
  });

  describe('Index Performance', () => {
    beforeEach(() => {
      initializeSchema(db);
    });

    it('should use index for feedback_log timestamp queries', () => {
      const sessionId = 'test-session';
      db.prepare('INSERT INTO session_log (id, start_time) VALUES (?, ?)').run(sessionId, Date.now());

      // Insert some test data
      for (let i = 0; i < 10; i++) {
        db.prepare(`
          INSERT INTO feedback_log (id, session_id, timestamp, feedback_type, confidence)
          VALUES (?, ?, ?, ?, ?)
        `).run(`test-${i}`, sessionId, Date.now() + i, 'positive', 0.9);
      }

      // Query with ORDER BY timestamp should use index
      const explain = db.prepare(`
        EXPLAIN QUERY PLAN
        SELECT * FROM feedback_log ORDER BY timestamp DESC LIMIT 5
      `).all();

      const explainText = JSON.stringify(explain);
      expect(explainText).toContain('idx_feedback_log_timestamp');
    });

    it('should use index for session_id lookups', () => {
      const sessionId = 'test-session';
      db.prepare('INSERT INTO session_log (id, start_time) VALUES (?, ?)').run(sessionId, Date.now());

      db.prepare(`
        INSERT INTO feedback_log (id, session_id, timestamp, feedback_type, confidence)
        VALUES (?, ?, ?, ?, ?)
      `).run('test-1', sessionId, Date.now(), 'positive', 0.9);

      // Query by session_id should use index
      const explain = db.prepare(`
        EXPLAIN QUERY PLAN
        SELECT * FROM feedback_log WHERE session_id = ?
      `).all(sessionId);

      const explainText = JSON.stringify(explain);
      expect(explainText).toContain('idx_feedback_log_session');
    });
  });
});
