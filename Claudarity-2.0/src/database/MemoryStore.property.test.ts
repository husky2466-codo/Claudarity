/**
 * Simplified Property Test for Database Initialization
 * Testing Property 25: Database Initialization
 * 
 * Feature: claudarity-modernization
 * **Validates: Requirements 4.3**
 */

import { describe, it, expect, afterEach } from 'vitest';
import * as fc from 'fast-check';
import { MemoryStoreImpl } from './MemoryStore';
import { verifySchema } from './schema';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import Database from 'better-sqlite3';

describe('Memory Store - Property 25: Database Initialization', () => {
  const createdDatabases: string[] = [];

  afterEach(() => {
    for (const dbPath of createdDatabases) {
      try {
        if (fs.existsSync(dbPath)) {
          fs.unlinkSync(dbPath);
        }
      } catch (error) {
        // Ignore
      }
    }
    createdDatabases.length = 0;
  });

  /**
   * Property 25: Database Initialization
   * For any non-existent database file at the configured path,
   * the Memory_Store should create it with the complete schema
   * (all required tables and indexes).
   */
  it('should create database with complete schema for any valid path', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.array(
          fc.stringOf(
            fc.constantFrom('a', 'b', 'c', 'd', 'e', '1', '2', '3'),
            { minLength: 3, maxLength: 8 }
          ),
          { minLength: 1, maxLength: 2 }
        ),
        (pathSegments) => {
          const tempDir = os.tmpdir();
          const dbName = `test-db-${pathSegments.join('-')}-${Date.now()}.db`;
          const dbPath = path.join(tempDir, dbName);
          
          createdDatabases.push(dbPath);
          
          if (fs.existsSync(dbPath)) {
            fs.unlinkSync(dbPath);
          }
          
          expect(fs.existsSync(dbPath)).toBe(false);
          
          const memoryStore = new MemoryStoreImpl(dbPath);
          
          expect(fs.existsSync(dbPath)).toBe(true);
          
          const db = new Database(dbPath);
          const schemaValid = verifySchema(db);
          db.close();
          
          expect(schemaValid).toBe(true);
          
          memoryStore.close();
        }
      ),
      { numRuns: 3 }
    );
  });

  it('should create all required tables', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const dbPath = path.join(tempDir, `test-tables-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(dbPath);
          
          if (fs.existsSync(dbPath)) {
            fs.unlinkSync(dbPath);
          }
          
          const memoryStore = new MemoryStoreImpl(dbPath);
          
          const db = new Database(dbPath);
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
            
            expect(result).toBeDefined();
            expect((result as any).name).toBe(tableName);
          }
          
          db.close();
          memoryStore.close();
        }
      ),
      { numRuns: 3 }
    );
  });

  it('should create indexes for optimization', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const dbPath = path.join(tempDir, `test-indexes-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(dbPath);
          
          if (fs.existsSync(dbPath)) {
            fs.unlinkSync(dbPath);
          }
          
          const memoryStore = new MemoryStoreImpl(dbPath);
          
          const db = new Database(dbPath);
          const indexes = db.prepare(
            "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%'"
          ).all() as Array<{ name: string }>;
          
          expect(indexes.length).toBeGreaterThan(0);
          
          const indexNames = indexes.map(idx => idx.name);
          expect(indexNames).toContain('idx_feedback_log_session');
          expect(indexNames).toContain('idx_context_memory_session');
          expect(indexNames).toContain('idx_session_log_start_time');
          
          db.close();
          memoryStore.close();
        }
      ),
      { numRuns: 3 }
    );
  });

  it('should initialize schema version', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const dbPath = path.join(tempDir, `test-version-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(dbPath);
          
          if (fs.existsSync(dbPath)) {
            fs.unlinkSync(dbPath);
          }
          
          const memoryStore = new MemoryStoreImpl(dbPath);
          
          const db = new Database(dbPath);
          const versionResult = db.prepare(
            'SELECT version FROM schema_version ORDER BY version DESC LIMIT 1'
          ).get() as { version: number } | undefined;
          
          expect(versionResult).toBeDefined();
          expect(versionResult!.version).toBe(1);
          
          db.close();
          memoryStore.close();
        }
      ),
      { numRuns: 3 }
    );
  });

  it('should enable foreign key constraints', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const dbPath = path.join(tempDir, `test-fk-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(dbPath);
          
          if (fs.existsSync(dbPath)) {
            fs.unlinkSync(dbPath);
          }
          
          const memoryStore = new MemoryStoreImpl(dbPath);
          
          const db = new Database(dbPath);
          const fkResult = db.pragma('foreign_keys', { simple: true });
          
          expect(fkResult).toBe(1);
          
          db.close();
          memoryStore.close();
        }
      ),
      { numRuns: 3 }
    );
  });

  it('should create functional database accepting data operations', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const dbPath = path.join(tempDir, `test-functional-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(dbPath);
          
          if (fs.existsSync(dbPath)) {
            fs.unlinkSync(dbPath);
          }
          
          const memoryStore = new MemoryStoreImpl(dbPath);
          
          const sessionId = `session-${seed}`;
          memoryStore.createSession({
            id: sessionId,
            start_time: Date.now(),
          });
          
          const sessions = memoryStore.querySession({ limit: 1 });
          expect(sessions.length).toBe(1);
          expect(sessions[0].id).toBe(sessionId);
          
          memoryStore.storeFeedback({
            id: `feedback-${seed}`,
            session_id: sessionId,
            timestamp: Date.now(),
            feedback_type: 'positive',
            confidence: 0.9,
          });
          
          const feedback = memoryStore.queryFeedback({ session_id: sessionId });
          expect(feedback.length).toBe(1);
          expect(feedback[0].feedback_type).toBe('positive');
          
          memoryStore.close();
        }
      ),
      { numRuns: 3 }
    );
  });

  it('should enforce table constraints', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const dbPath = path.join(tempDir, `test-constraints-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(dbPath);
          
          if (fs.existsSync(dbPath)) {
            fs.unlinkSync(dbPath);
          }
          
          const memoryStore = new MemoryStoreImpl(dbPath);
          
          const db = new Database(dbPath);
          
          // Test invalid feedback_type
          let constraintViolated = false;
          try {
            db.prepare(`
              INSERT INTO feedback_log (id, session_id, timestamp, feedback_type, confidence)
              VALUES ('test', 'session', 123, 'invalid_type', 0.5)
            `).run();
          } catch (error) {
            constraintViolated = true;
          }
          expect(constraintViolated).toBe(true);
          
          // Test invalid confidence range
          constraintViolated = false;
          try {
            db.prepare(`
              INSERT INTO feedback_log (id, session_id, timestamp, feedback_type, confidence)
              VALUES ('test', 'session', 123, 'positive', 1.5)
            `).run();
          } catch (error) {
            constraintViolated = true;
          }
          expect(constraintViolated).toBe(true);
          
          db.close();
          memoryStore.close();
        }
      ),
      { numRuns: 3 }
    );
  });
});

describe('Memory Store - Property 26: Configurable Database Location', () => {
  const createdDatabases: string[] = [];

  afterEach(() => {
    for (const dbPath of createdDatabases) {
      try {
        if (fs.existsSync(dbPath)) {
          fs.unlinkSync(dbPath);
        }
      } catch (error) {
        // Ignore
      }
    }
    createdDatabases.length = 0;
  });

  /**
   * Property 26: Configurable Database Location
   * For any configured database path in the configuration file,
   * the Memory_Store should use that path for all database operations.
   * 
   * **Validates: Requirements 4.2**
   */
  it('should use configured database path for all operations', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.record({
          dirSegments: fc.array(
            fc.stringOf(
              fc.constantFrom('a', 'b', 'c', 'd', 'e', '1', '2', '3'),
              { minLength: 3, maxLength: 8 }
            ),
            { minLength: 1, maxLength: 3 }
          ),
          fileName: fc.stringOf(
            fc.constantFrom('a', 'b', 'c', 'd', 'e', '1', '2', '3', '-', '_'),
            { minLength: 5, maxLength: 15 }
          )
        }),
        ({ dirSegments, fileName }) => {
          const tempDir = os.tmpdir();
          const customDir = path.join(tempDir, ...dirSegments);
          const dbPath = path.join(customDir, `${fileName}-${Date.now()}.db`);
          
          createdDatabases.push(dbPath);
          
          // Ensure directory exists
          if (!fs.existsSync(customDir)) {
            fs.mkdirSync(customDir, { recursive: true });
          }
          
          // Remove database if it exists
          if (fs.existsSync(dbPath)) {
            fs.unlinkSync(dbPath);
          }
          
          // Create MemoryStore with configured path
          const memoryStore = new MemoryStoreImpl(dbPath);
          
          // Verify database was created at the configured path
          expect(fs.existsSync(dbPath)).toBe(true);
          
          // Perform operations and verify they use the configured path
          const sessionId = `session-${Date.now()}`;
          memoryStore.createSession({
            id: sessionId,
            start_time: Date.now(),
          });
          
          // Close and reopen to verify persistence at configured path
          memoryStore.close();
          
          // Verify database file still exists at configured path
          expect(fs.existsSync(dbPath)).toBe(true);
          
          // Reopen and verify data persisted
          const memoryStore2 = new MemoryStoreImpl(dbPath);
          const sessions = memoryStore2.querySession({ limit: 1 });
          
          expect(sessions.length).toBe(1);
          expect(sessions[0].id).toBe(sessionId);
          
          memoryStore2.close();
          
          // Clean up directory
          try {
            fs.rmdirSync(customDir, { recursive: true });
          } catch (error) {
            // Ignore cleanup errors
          }
        }
      ),
      { numRuns: 3 }
    );
  });

  it('should handle absolute paths correctly', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const absolutePath = path.resolve(tempDir, `test-absolute-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(absolutePath);
          
          if (fs.existsSync(absolutePath)) {
            fs.unlinkSync(absolutePath);
          }
          
          // Create MemoryStore with absolute path
          const memoryStore = new MemoryStoreImpl(absolutePath);
          
          // Verify database was created at the absolute path
          expect(fs.existsSync(absolutePath)).toBe(true);
          expect(path.isAbsolute(absolutePath)).toBe(true);
          
          // Perform operation
          const sessionId = `session-${seed}`;
          memoryStore.createSession({
            id: sessionId,
            start_time: Date.now(),
          });
          
          const sessions = memoryStore.querySession({ limit: 1 });
          expect(sessions.length).toBe(1);
          expect(sessions[0].id).toBe(sessionId);
          
          memoryStore.close();
        }
      ),
      { numRuns: 3 }
    );
  });

  it('should handle relative paths correctly', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const relativePath = `test-relative-${seed}-${Date.now()}.db`;
          const absolutePath = path.resolve(relativePath);
          
          createdDatabases.push(absolutePath);
          
          if (fs.existsSync(absolutePath)) {
            fs.unlinkSync(absolutePath);
          }
          
          // Create MemoryStore with relative path
          const memoryStore = new MemoryStoreImpl(relativePath);
          
          // Verify database was created (relative path resolved to absolute)
          expect(fs.existsSync(absolutePath)).toBe(true);
          
          // Perform operation
          const sessionId = `session-${seed}`;
          memoryStore.createSession({
            id: sessionId,
            start_time: Date.now(),
          });
          
          const sessions = memoryStore.querySession({ limit: 1 });
          expect(sessions.length).toBe(1);
          expect(sessions[0].id).toBe(sessionId);
          
          memoryStore.close();
        }
      ),
      { numRuns: 3 }
    );
  });

  it('should handle nested directory paths', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.array(
          fc.stringOf(
            fc.constantFrom('a', 'b', 'c', 'd', 'e', '1', '2', '3'),
            { minLength: 3, maxLength: 8 }
          ),
          { minLength: 2, maxLength: 4 }
        ),
        (pathSegments) => {
          const tempDir = os.tmpdir();
          const nestedDir = path.join(tempDir, ...pathSegments);
          const dbPath = path.join(nestedDir, `test-nested-${Date.now()}.db`);
          
          createdDatabases.push(dbPath);
          
          // Ensure nested directory exists
          if (!fs.existsSync(nestedDir)) {
            fs.mkdirSync(nestedDir, { recursive: true });
          }
          
          if (fs.existsSync(dbPath)) {
            fs.unlinkSync(dbPath);
          }
          
          // Create MemoryStore with nested path
          const memoryStore = new MemoryStoreImpl(dbPath);
          
          // Verify database was created in nested directory
          expect(fs.existsSync(dbPath)).toBe(true);
          
          // Verify parent directory structure
          expect(fs.existsSync(nestedDir)).toBe(true);
          
          // Perform operation
          const sessionId = `session-${Date.now()}`;
          memoryStore.createSession({
            id: sessionId,
            start_time: Date.now(),
          });
          
          const sessions = memoryStore.querySession({ limit: 1 });
          expect(sessions.length).toBe(1);
          
          memoryStore.close();
          
          // Clean up nested directory
          try {
            fs.rmdirSync(nestedDir, { recursive: true });
          } catch (error) {
            // Ignore cleanup errors
          }
        }
      ),
      { numRuns: 3 }
    );
  });

  it('should persist data to configured location across multiple operations', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.record({
          seed: fc.integer({ min: 1, max: 100000 }),
          operationCount: fc.integer({ min: 2, max: 5 })
        }),
        ({ seed, operationCount }) => {
          const tempDir = os.tmpdir();
          const dbPath = path.join(tempDir, `test-persist-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(dbPath);
          
          if (fs.existsSync(dbPath)) {
            fs.unlinkSync(dbPath);
          }
          
          // Create MemoryStore with configured path
          const memoryStore = new MemoryStoreImpl(dbPath);
          
          // Perform multiple operations
          const sessionIds: string[] = [];
          for (let i = 0; i < operationCount; i++) {
            const sessionId = `session-${seed}-${i}`;
            sessionIds.push(sessionId);
            memoryStore.createSession({
              id: sessionId,
              start_time: Date.now() + i,
            });
          }
          
          // Verify all operations persisted
          const sessions = memoryStore.querySession({ limit: operationCount });
          expect(sessions.length).toBe(operationCount);
          
          // Verify all session IDs are present
          const retrievedIds = sessions.map(s => s.id);
          for (const sessionId of sessionIds) {
            expect(retrievedIds).toContain(sessionId);
          }
          
          memoryStore.close();
          
          // Reopen and verify data still persisted at configured path
          const memoryStore2 = new MemoryStoreImpl(dbPath);
          const sessions2 = memoryStore2.querySession({ limit: operationCount });
          expect(sessions2.length).toBe(operationCount);
          
          memoryStore2.close();
        }
      ),
      { numRuns: 3 }
    );
  });

  it('should handle platform-specific path separators', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          // Use platform-specific path separator
          const dbPath = path.join(tempDir, 'test-sep', `db-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(dbPath);
          
          // Ensure directory exists
          const dir = path.dirname(dbPath);
          if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
          }
          
          if (fs.existsSync(dbPath)) {
            fs.unlinkSync(dbPath);
          }
          
          // Create MemoryStore with platform-specific path
          const memoryStore = new MemoryStoreImpl(dbPath);
          
          // Verify database was created
          expect(fs.existsSync(dbPath)).toBe(true);
          
          // Verify path uses correct separator for platform
          const normalizedPath = path.normalize(dbPath);
          expect(fs.existsSync(normalizedPath)).toBe(true);
          
          memoryStore.close();
          
          // Clean up
          try {
            fs.rmdirSync(dir, { recursive: true });
          } catch (error) {
            // Ignore cleanup errors
          }
        }
      ),
      { numRuns: 3 }
    );
  });
});
