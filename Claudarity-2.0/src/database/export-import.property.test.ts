/**
 * Property Tests for Export/Import Functionality
 * Testing Properties 27, 28, 29
 * 
 * Feature: claudarity-modernization
 * **Validates: Requirements 4.4, 4.5, 4.6**
 */

import { describe, it, expect, afterEach } from 'vitest';
import * as fc from 'fast-check';
import { MemoryStoreImpl } from './MemoryStore';
import { getCurrentSchemaVersion, verifySchema } from './schema';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import Database from 'better-sqlite3';

describe('Memory Store - Property 27: Export Creates Valid Backup', () => {
  const createdDatabases: string[] = [];

  afterEach(() => {
    for (const dbPath of createdDatabases) {
      try {
        if (fs.existsSync(dbPath)) {
          fs.unlinkSync(dbPath);
        }
      } catch (error) {
        // Ignore cleanup errors
      }
    }
    createdDatabases.length = 0;
  });

  /**
   * Property 27: Export Creates Valid Backup
   * For any export operation, the resulting file should be a valid SQLite database
   * containing all data from the source database.
   * 
   * **Validates: Requirements 4.4**
   */
  it('should create valid SQLite database on export', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const sourcePath = path.join(tempDir, `source-${seed}-${Date.now()}.db`);
          const exportPath = path.join(tempDir, `export-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(sourcePath, exportPath);
          
          // Create source database
          const sourceStore = new MemoryStoreImpl(sourcePath);
          
          // Export database
          const result = sourceStore.exportDatabase(exportPath);
          
          // Verify export succeeded
          expect(result.success).toBe(true);
          expect(result.path).toBe(exportPath);
          
          // Verify exported file exists
          expect(fs.existsSync(exportPath)).toBe(true);
          
          // Verify exported file is a valid SQLite database
          let exportDb: Database.Database | null = null;
          try {
            exportDb = new Database(exportPath, { readonly: true });
            
            // Verify it's a valid database by querying sqlite_master
            const tables = exportDb.prepare(
              "SELECT name FROM sqlite_master WHERE type='table'"
            ).all();
            
            expect(tables.length).toBeGreaterThan(0);
          } finally {
            if (exportDb) {
              exportDb.close();
            }
          }
          
          sourceStore.close();
        }
      ),
      { numRuns: 5 }
    );
  });

  it('should export all data from source database', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.record({
          seed: fc.integer({ min: 1, max: 100000 }),
          sessionCount: fc.integer({ min: 1, max: 5 }),
          feedbackCount: fc.integer({ min: 1, max: 5 })
        }),
        ({ seed, sessionCount, feedbackCount }) => {
          const tempDir = os.tmpdir();
          const sourcePath = path.join(tempDir, `source-data-${seed}-${Date.now()}.db`);
          const exportPath = path.join(tempDir, `export-data-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(sourcePath, exportPath);
          
          // Create source database with data
          const sourceStore = new MemoryStoreImpl(sourcePath);
          
          // Add sessions
          const sessionIds: string[] = [];
          for (let i = 0; i < sessionCount; i++) {
            const sessionId = `session-${seed}-${i}`;
            sessionIds.push(sessionId);
            sourceStore.createSession({
              id: sessionId,
              start_time: Date.now() + i,
            });
          }
          
          // Add feedback for first session
          for (let i = 0; i < feedbackCount; i++) {
            sourceStore.storeFeedback({
              id: `feedback-${seed}-${i}`,
              session_id: sessionIds[0],
              timestamp: Date.now() + i,
              feedback_type: i % 2 === 0 ? 'positive' : 'negative',
              confidence: 0.8,
            });
          }
          
          // Export database
          const result = sourceStore.exportDatabase(exportPath);
          expect(result.success).toBe(true);
          
          // Verify exported database contains all data
          const exportDb = new Database(exportPath, { readonly: true });
          
          const exportedSessions = exportDb.prepare('SELECT * FROM session_log').all();
          expect(exportedSessions.length).toBe(sessionCount);
          
          const exportedFeedback = exportDb.prepare('SELECT * FROM feedback_log').all();
          expect(exportedFeedback.length).toBe(feedbackCount);
          
          exportDb.close();
          sourceStore.close();
        }
      ),
      { numRuns: 5 }
    );
  });

  it('should export database with valid schema', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const sourcePath = path.join(tempDir, `source-schema-${seed}-${Date.now()}.db`);
          const exportPath = path.join(tempDir, `export-schema-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(sourcePath, exportPath);
          
          // Create source database
          const sourceStore = new MemoryStoreImpl(sourcePath);
          
          // Export database
          const result = sourceStore.exportDatabase(exportPath);
          expect(result.success).toBe(true);
          
          // Verify exported database has valid schema
          const exportDb = new Database(exportPath, { readonly: true });
          const schemaValid = verifySchema(exportDb);
          
          expect(schemaValid).toBe(true);
          
          exportDb.close();
          sourceStore.close();
        }
      ),
      { numRuns: 5 }
    );
  });

  it('should export database with correct record count', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.record({
          seed: fc.integer({ min: 1, max: 100000 }),
          recordCount: fc.integer({ min: 0, max: 10 })
        }),
        ({ seed, recordCount }) => {
          const tempDir = os.tmpdir();
          const sourcePath = path.join(tempDir, `source-count-${seed}-${Date.now()}.db`);
          const exportPath = path.join(tempDir, `export-count-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(sourcePath, exportPath);
          
          // Create source database with data
          const sourceStore = new MemoryStoreImpl(sourcePath);
          
          // Add sessions
          for (let i = 0; i < recordCount; i++) {
            sourceStore.createSession({
              id: `session-${seed}-${i}`,
              start_time: Date.now() + i,
            });
          }
          
          // Export database
          const result = sourceStore.exportDatabase(exportPath);
          expect(result.success).toBe(true);
          
          // Verify record count is reported correctly
          // Note: recordCount includes all tables, not just sessions
          expect(result.recordCount).toBeGreaterThanOrEqual(recordCount);
          
          sourceStore.close();
        }
      ),
      { numRuns: 5 }
    );
  });

  it('should handle export to nested directory paths', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.array(
          fc.stringOf(
            fc.constantFrom('a', 'b', 'c', 'd', 'e', '1', '2', '3'),
            { minLength: 3, maxLength: 8 }
          ),
          { minLength: 1, max: 3 }
        ),
        (pathSegments) => {
          const tempDir = os.tmpdir();
          const sourcePath = path.join(tempDir, `source-nested-${Date.now()}.db`);
          const exportDir = path.join(tempDir, ...pathSegments);
          const exportPath = path.join(exportDir, `export-${Date.now()}.db`);
          
          createdDatabases.push(sourcePath, exportPath);
          
          // Create source database
          const sourceStore = new MemoryStoreImpl(sourcePath);
          
          // Export to nested directory (should create directory)
          const result = sourceStore.exportDatabase(exportPath);
          
          expect(result.success).toBe(true);
          expect(fs.existsSync(exportPath)).toBe(true);
          expect(fs.existsSync(exportDir)).toBe(true);
          
          sourceStore.close();
          
          // Clean up nested directory
          try {
            fs.rmdirSync(exportDir, { recursive: true });
          } catch (error) {
            // Ignore cleanup errors
          }
        }
      ),
      { numRuns: 5 }
    );
  });
});

describe('Memory Store - Property 28: Import Merges or Replaces', () => {
  const createdDatabases: string[] = [];

  afterEach(() => {
    for (const dbPath of createdDatabases) {
      try {
        if (fs.existsSync(dbPath)) {
          fs.unlinkSync(dbPath);
        }
      } catch (error) {
        // Ignore cleanup errors
      }
    }
    createdDatabases.length = 0;
  });

  /**
   * Property 28: Import Merges or Replaces
   * For any import operation with merge strategy, existing data should be preserved
   * and new data added; with replace strategy, existing data should be cleared first.
   * 
   * **Validates: Requirements 4.5**
   */
  it('should merge data when using merge strategy', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.record({
          seed: fc.integer({ min: 1, max: 100000 }),
          existingCount: fc.integer({ min: 1, max: 5 }),
          importCount: fc.integer({ min: 1, max: 5 })
        }),
        ({ seed, existingCount, importCount }) => {
          const tempDir = os.tmpdir();
          const sourcePath = path.join(tempDir, `source-merge-${seed}-${Date.now()}.db`);
          const targetPath = path.join(tempDir, `target-merge-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(sourcePath, targetPath);
          
          // Create source database with data
          const sourceStore = new MemoryStoreImpl(sourcePath);
          for (let i = 0; i < importCount; i++) {
            sourceStore.createSession({
              id: `import-session-${seed}-${i}`,
              start_time: Date.now() + i,
            });
          }
          sourceStore.close();
          
          // Create target database with existing data
          const targetStore = new MemoryStoreImpl(targetPath);
          for (let i = 0; i < existingCount; i++) {
            targetStore.createSession({
              id: `existing-session-${seed}-${i}`,
              start_time: Date.now() + i + 1000,
            });
          }
          
          // Import with merge strategy
          const result = targetStore.importDatabase(sourcePath, 'merge');
          
          expect(result.success).toBe(true);
          
          // Verify both existing and imported data are present
          const allSessions = targetStore.querySession({});
          expect(allSessions.length).toBe(existingCount + importCount);
          
          // Verify existing sessions are still there
          const existingSessions = allSessions.filter(s => s.id.startsWith('existing-session'));
          expect(existingSessions.length).toBe(existingCount);
          
          // Verify imported sessions are there
          const importedSessions = allSessions.filter(s => s.id.startsWith('import-session'));
          expect(importedSessions.length).toBe(importCount);
          
          targetStore.close();
        }
      ),
      { numRuns: 5 }
    );
  });

  it('should replace data when using replace strategy', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.record({
          seed: fc.integer({ min: 1, max: 100000 }),
          existingCount: fc.integer({ min: 1, max: 5 }),
          importCount: fc.integer({ min: 1, max: 5 })
        }),
        ({ seed, existingCount, importCount }) => {
          const tempDir = os.tmpdir();
          const sourcePath = path.join(tempDir, `source-replace-${seed}-${Date.now()}.db`);
          const targetPath = path.join(tempDir, `target-replace-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(sourcePath, targetPath);
          
          // Create source database with data
          const sourceStore = new MemoryStoreImpl(sourcePath);
          for (let i = 0; i < importCount; i++) {
            sourceStore.createSession({
              id: `import-session-${seed}-${i}`,
              start_time: Date.now() + i,
            });
          }
          sourceStore.close();
          
          // Create target database with existing data
          const targetStore = new MemoryStoreImpl(targetPath);
          for (let i = 0; i < existingCount; i++) {
            targetStore.createSession({
              id: `existing-session-${seed}-${i}`,
              start_time: Date.now() + i + 1000,
            });
          }
          
          // Import with replace strategy
          const result = targetStore.importDatabase(sourcePath, 'replace');
          
          expect(result.success).toBe(true);
          
          // Verify only imported data is present (existing data cleared)
          const allSessions = targetStore.querySession({});
          expect(allSessions.length).toBe(importCount);
          
          // Verify no existing sessions remain
          const existingSessions = allSessions.filter(s => s.id.startsWith('existing-session'));
          expect(existingSessions.length).toBe(0);
          
          // Verify imported sessions are there
          const importedSessions = allSessions.filter(s => s.id.startsWith('import-session'));
          expect(importedSessions.length).toBe(importCount);
          
          targetStore.close();
        }
      ),
      { numRuns: 5 }
    );
  });

  it('should preserve data integrity during merge', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.record({
          seed: fc.integer({ min: 1, max: 100000 }),
          sessionCount: fc.integer({ min: 1, max: 3 }),
          feedbackCount: fc.integer({ min: 1, max: 3 })
        }),
        ({ seed, sessionCount, feedbackCount }) => {
          const tempDir = os.tmpdir();
          const sourcePath = path.join(tempDir, `source-integrity-${seed}-${Date.now()}.db`);
          const targetPath = path.join(tempDir, `target-integrity-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(sourcePath, targetPath);
          
          // Create source database with sessions and feedback
          const sourceStore = new MemoryStoreImpl(sourcePath);
          const sessionId = `session-${seed}`;
          sourceStore.createSession({
            id: sessionId,
            start_time: Date.now(),
          });
          
          for (let i = 0; i < feedbackCount; i++) {
            sourceStore.storeFeedback({
              id: `feedback-${seed}-${i}`,
              session_id: sessionId,
              timestamp: Date.now() + i,
              feedback_type: 'positive',
              confidence: 0.9,
            });
          }
          sourceStore.close();
          
          // Create target database
          const targetStore = new MemoryStoreImpl(targetPath);
          
          // Import with merge strategy
          const result = targetStore.importDatabase(sourcePath, 'merge');
          
          expect(result.success).toBe(true);
          
          // Verify session was imported
          const sessions = targetStore.querySession({ limit: 10 });
          expect(sessions.length).toBeGreaterThanOrEqual(1);
          
          // Verify feedback was imported and linked to session
          const feedback = targetStore.queryFeedback({ session_id: sessionId });
          expect(feedback.length).toBe(feedbackCount);
          
          // Verify all feedback has correct session_id
          for (const fb of feedback) {
            expect(fb.session_id).toBe(sessionId);
          }
          
          targetStore.close();
        }
      ),
      { numRuns: 5 }
    );
  });

  it('should skip duplicate records during merge', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.record({
          seed: fc.integer({ min: 1, max: 100000 }),
          recordCount: fc.integer({ min: 1, max: 5 })
        }),
        ({ seed, recordCount }) => {
          const tempDir = os.tmpdir();
          const sourcePath = path.join(tempDir, `source-dup-${seed}-${Date.now()}.db`);
          const targetPath = path.join(tempDir, `target-dup-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(sourcePath, targetPath);
          
          // Create source database with data
          const sourceStore = new MemoryStoreImpl(sourcePath);
          for (let i = 0; i < recordCount; i++) {
            sourceStore.createSession({
              id: `session-${seed}-${i}`,
              start_time: Date.now() + i,
            });
          }
          sourceStore.close();
          
          // Create target database with same data (duplicates)
          const targetStore = new MemoryStoreImpl(targetPath);
          for (let i = 0; i < recordCount; i++) {
            targetStore.createSession({
              id: `session-${seed}-${i}`,
              start_time: Date.now() + i,
            });
          }
          
          // Import with merge strategy (should skip duplicates)
          const result = targetStore.importDatabase(sourcePath, 'merge');
          
          expect(result.success).toBe(true);
          
          // Verify no duplicate records (should still have recordCount, not 2x)
          const allSessions = targetStore.querySession({});
          expect(allSessions.length).toBe(recordCount);
          
          // Verify skipped count is reported
          expect(result.recordsSkipped).toBeGreaterThan(0);
          
          targetStore.close();
        }
      ),
      { numRuns: 5 }
    );
  });

  it('should handle empty source database', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const sourcePath = path.join(tempDir, `source-empty-${seed}-${Date.now()}.db`);
          const targetPath = path.join(tempDir, `target-empty-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(sourcePath, targetPath);
          
          // Create empty source database
          const sourceStore = new MemoryStoreImpl(sourcePath);
          sourceStore.close();
          
          // Create target database with data
          const targetStore = new MemoryStoreImpl(targetPath);
          targetStore.createSession({
            id: `session-${seed}`,
            start_time: Date.now(),
          });
          
          // Import empty database with merge strategy
          const result = targetStore.importDatabase(sourcePath, 'merge');
          
          expect(result.success).toBe(true);
          
          // Verify existing data is preserved
          const sessions = targetStore.querySession({});
          expect(sessions.length).toBe(1);
          
          targetStore.close();
        }
      ),
      { numRuns: 5 }
    );
  });
});

describe('Memory Store - Property 29: Schema Compatibility Validation', () => {
  const createdDatabases: string[] = [];

  afterEach(() => {
    for (const dbPath of createdDatabases) {
      try {
        if (fs.existsSync(dbPath)) {
          fs.unlinkSync(dbPath);
        }
      } catch (error) {
        // Ignore cleanup errors
      }
    }
    createdDatabases.length = 0;
  });

  /**
   * Property 29: Schema Compatibility Validation
   * For any import operation, the source database schema version should be validated
   * for compatibility before importing data.
   * 
   * **Validates: Requirements 4.6**
   */
  it('should validate schema version before import', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const sourcePath = path.join(tempDir, `source-version-${seed}-${Date.now()}.db`);
          const targetPath = path.join(tempDir, `target-version-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(sourcePath, targetPath);
          
          // Create source database
          const sourceStore = new MemoryStoreImpl(sourcePath);
          sourceStore.close();
          
          // Create target database
          const targetStore = new MemoryStoreImpl(targetPath);
          
          // Import should succeed (same schema version)
          const result = targetStore.importDatabase(sourcePath, 'merge');
          
          expect(result.success).toBe(true);
          
          // Verify schema versions match
          const sourceDb = new Database(sourcePath, { readonly: true });
          const targetDb = new Database(targetPath, { readonly: true });
          
          const sourceVersion = getCurrentSchemaVersion(sourceDb);
          const targetVersion = getCurrentSchemaVersion(targetDb);
          
          expect(sourceVersion).toBe(targetVersion);
          
          sourceDb.close();
          targetDb.close();
          targetStore.close();
        }
      ),
      { numRuns: 5 }
    );
  });

  it('should reject import from newer schema version', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const sourcePath = path.join(tempDir, `source-newer-${seed}-${Date.now()}.db`);
          const targetPath = path.join(tempDir, `target-newer-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(sourcePath, targetPath);
          
          // Create source database with artificially higher version
          const sourceStore = new MemoryStoreImpl(sourcePath);
          sourceStore.close();
          
          // Manually increase source schema version
          const sourceDb = new Database(sourcePath);
          sourceDb.prepare('INSERT INTO schema_version (version, applied_at) VALUES (?, ?)').run(
            999,
            Date.now()
          );
          sourceDb.close();
          
          // Create target database with normal version
          const targetStore = new MemoryStoreImpl(targetPath);
          
          // Import should fail (source version too new)
          const result = targetStore.importDatabase(sourcePath, 'merge');
          
          expect(result.success).toBe(false);
          expect(result.errors.length).toBeGreaterThan(0);
          expect(result.errors[0]).toContain('version');
          
          targetStore.close();
        }
      ),
      { numRuns: 5 }
    );
  });

  it('should validate source database has valid schema', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const sourcePath = path.join(tempDir, `source-valid-${seed}-${Date.now()}.db`);
          const targetPath = path.join(tempDir, `target-valid-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(sourcePath, targetPath);
          
          // Create source database with valid schema
          const sourceStore = new MemoryStoreImpl(sourcePath);
          sourceStore.close();
          
          // Verify source has valid schema
          const sourceDb = new Database(sourcePath, { readonly: true });
          const schemaValid = verifySchema(sourceDb);
          sourceDb.close();
          
          expect(schemaValid).toBe(true);
          
          // Create target database
          const targetStore = new MemoryStoreImpl(targetPath);
          
          // Import should succeed (valid schema)
          const result = targetStore.importDatabase(sourcePath, 'merge');
          
          expect(result.success).toBe(true);
          
          targetStore.close();
        }
      ),
      { numRuns: 5 }
    );
  });

  it('should reject import from invalid schema', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const sourcePath = path.join(tempDir, `source-invalid-${seed}-${Date.now()}.db`);
          const targetPath = path.join(tempDir, `target-invalid-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(sourcePath, targetPath);
          
          // Create source database with incomplete schema
          const sourceDb = new Database(sourcePath);
          sourceDb.prepare('CREATE TABLE test_table (id TEXT PRIMARY KEY)').run();
          sourceDb.close();
          
          // Create target database with valid schema
          const targetStore = new MemoryStoreImpl(targetPath);
          
          // Import should fail (invalid schema)
          const result = targetStore.importDatabase(sourcePath, 'merge');
          
          expect(result.success).toBe(false);
          expect(result.errors.length).toBeGreaterThan(0);
          expect(result.errors[0]).toContain('schema');
          
          targetStore.close();
        }
      ),
      { numRuns: 5 }
    );
  });

  it('should reject import from non-existent file', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const sourcePath = path.join(tempDir, `nonexistent-${seed}-${Date.now()}.db`);
          const targetPath = path.join(tempDir, `target-nonexist-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(targetPath);
          
          // Ensure source doesn't exist
          if (fs.existsSync(sourcePath)) {
            fs.unlinkSync(sourcePath);
          }
          
          // Create target database
          const targetStore = new MemoryStoreImpl(targetPath);
          
          // Import should fail (source doesn't exist)
          const result = targetStore.importDatabase(sourcePath, 'merge');
          
          expect(result.success).toBe(false);
          expect(result.errors.length).toBeGreaterThan(0);
          expect(result.errors[0]).toContain('not found');
          
          targetStore.close();
        }
      ),
      { numRuns: 5 }
    );
  });

  it('should provide detailed error messages for schema issues', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const sourcePath = path.join(tempDir, `source-error-${seed}-${Date.now()}.db`);
          const targetPath = path.join(tempDir, `target-error-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(sourcePath, targetPath);
          
          // Create source database with wrong schema
          const sourceDb = new Database(sourcePath);
          sourceDb.prepare('CREATE TABLE wrong_table (id TEXT)').run();
          sourceDb.close();
          
          // Create target database
          const targetStore = new MemoryStoreImpl(targetPath);
          
          // Import should fail with detailed error
          const result = targetStore.importDatabase(sourcePath, 'merge');
          
          expect(result.success).toBe(false);
          expect(result.errors.length).toBeGreaterThan(0);
          
          // Verify error message is descriptive
          const errorMsg = result.errors[0].toLowerCase();
          expect(
            errorMsg.includes('schema') ||
            errorMsg.includes('invalid') ||
            errorMsg.includes('incomplete')
          ).toBe(true);
          
          targetStore.close();
        }
      ),
      { numRuns: 5 }
    );
  });
});
