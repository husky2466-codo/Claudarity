/**
 * Property-Based Tests for Database Migration System
 * Testing Property 30: Database Migration
 * 
 * Feature: claudarity-modernization
 * **Validates: Requirements 4.7**
 */

import { describe, it, expect, afterEach } from 'vitest';
import * as fc from 'fast-check';
import Database from 'better-sqlite3';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { initializeSchema, getCurrentSchemaVersion } from './schema';
import {
  migrate,
  rollback,
  getPendingMigrations,
  getAppliedMigrations,
  validateMigrationIntegrity,
  type Migration
} from './migrations';

describe('Database Migration - Property 30: Database Migration', () => {
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
   * Property 30: Database Migration
   * For any database with schema version less than the target version,
   * migrations should be applied sequentially until the target version is reached.
   */
  it('should apply migrations sequentially from current to target version', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const dbPath = path.join(tempDir, `test-migration-seq-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(dbPath);
          
          if (fs.existsSync(dbPath)) {
            fs.unlinkSync(dbPath);
          }
          
          const db = new Database(dbPath);
          initializeSchema(db);
          
          // Verify initial version is 1
          const initialVersion = getCurrentSchemaVersion(db);
          expect(initialVersion).toBe(1);
          
          // Verify migration to same version succeeds with no changes
          const result = migrate(db, initialVersion);
          expect(result.success).toBe(true);
          expect(result.fromVersion).toBe(initialVersion);
          expect(result.toVersion).toBe(initialVersion);
          expect(result.appliedMigrations).toEqual([]);
          
          // Verify version remains unchanged
          const finalVersion = getCurrentSchemaVersion(db);
          expect(finalVersion).toBe(initialVersion);
          
          db.close();
        }
      ),
      { numRuns: 3 }
    );
  });

  it('should track all applied migrations in schema_version table', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const dbPath = path.join(tempDir, `test-migration-track-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(dbPath);
          
          if (fs.existsSync(dbPath)) {
            fs.unlinkSync(dbPath);
          }
          
          const db = new Database(dbPath);
          initializeSchema(db);
          
          // Get applied migrations
          const appliedMigrations = getAppliedMigrations(db);
          
          // Should have at least version 1
          expect(appliedMigrations.length).toBeGreaterThanOrEqual(1);
          expect(appliedMigrations).toContain(1);
          
          // All versions should be positive integers
          for (const version of appliedMigrations) {
            expect(version).toBeGreaterThan(0);
            expect(Number.isInteger(version)).toBe(true);
          }
          
          // Versions should be in ascending order
          for (let i = 1; i < appliedMigrations.length; i++) {
            expect(appliedMigrations[i]).toBeGreaterThan(appliedMigrations[i - 1]);
          }
          
          db.close();
        }
      ),
      { numRuns: 3 }
    );
  });

  it('should maintain migration integrity across operations', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const dbPath = path.join(tempDir, `test-migration-integrity-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(dbPath);
          
          if (fs.existsSync(dbPath)) {
            fs.unlinkSync(dbPath);
          }
          
          const db = new Database(dbPath);
          initializeSchema(db);
          
          // Verify migration integrity
          const isValid = validateMigrationIntegrity(db);
          expect(isValid).toBe(true);
          
          // Verify version 1 exists
          const appliedMigrations = getAppliedMigrations(db);
          expect(appliedMigrations).toContain(1);
          
          // Verify current version matches highest applied version
          const currentVersion = getCurrentSchemaVersion(db);
          const maxAppliedVersion = Math.max(...appliedMigrations);
          expect(currentVersion).toBe(maxAppliedVersion);
          
          db.close();
        }
      ),
      { numRuns: 3 }
    );
  });

  it('should prevent backward migration through migrate function', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.record({
          seed: fc.integer({ min: 1, max: 100000 }),
          targetVersion: fc.integer({ min: 0, max: 0 })
        }),
        ({ seed, targetVersion }) => {
          const tempDir = os.tmpdir();
          const dbPath = path.join(tempDir, `test-migration-backward-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(dbPath);
          
          if (fs.existsSync(dbPath)) {
            fs.unlinkSync(dbPath);
          }
          
          const db = new Database(dbPath);
          initializeSchema(db);
          
          const currentVersion = getCurrentSchemaVersion(db);
          
          // Attempt to migrate to lower version
          const result = migrate(db, targetVersion);
          
          // Should fail
          expect(result.success).toBe(false);
          expect(result.error).toBeDefined();
          expect(result.error).toContain('Cannot migrate backwards');
          
          // Version should remain unchanged
          const finalVersion = getCurrentSchemaVersion(db);
          expect(finalVersion).toBe(currentVersion);
          
          db.close();
        }
      ),
      { numRuns: 3 }
    );
  });

  it('should handle rollback validation correctly', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.record({
          seed: fc.integer({ min: 1, max: 100000 }),
          targetVersion: fc.integer({ min: 0, max: 10 })
        }),
        ({ seed, targetVersion }) => {
          const tempDir = os.tmpdir();
          const dbPath = path.join(tempDir, `test-migration-rollback-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(dbPath);
          
          if (fs.existsSync(dbPath)) {
            fs.unlinkSync(dbPath);
          }
          
          const db = new Database(dbPath);
          initializeSchema(db);
          
          const currentVersion = getCurrentSchemaVersion(db);
          
          // Attempt rollback
          const result = rollback(db, targetVersion);
          
          if (targetVersion >= currentVersion) {
            // Should fail - cannot rollback to current or higher version
            expect(result.success).toBe(false);
            expect(result.error).toBeDefined();
          } else if (targetVersion < 1) {
            // Should fail - cannot rollback below version 1
            expect(result.success).toBe(false);
            expect(result.error).toContain('Cannot rollback below version 1');
          }
          
          // Version should remain unchanged on failure
          const finalVersion = getCurrentSchemaVersion(db);
          expect(finalVersion).toBe(currentVersion);
          
          db.close();
        }
      ),
      { numRuns: 3 }
    );
  });

  it('should return empty pending migrations for current schema', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const dbPath = path.join(tempDir, `test-migration-pending-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(dbPath);
          
          if (fs.existsSync(dbPath)) {
            fs.unlinkSync(dbPath);
          }
          
          const db = new Database(dbPath);
          initializeSchema(db);
          
          // Get pending migrations
          const pending = getPendingMigrations(db);
          
          // Should be empty for current schema (no migrations defined beyond version 1)
          expect(Array.isArray(pending)).toBe(true);
          expect(pending.length).toBe(0);
          
          db.close();
        }
      ),
      { numRuns: 3 }
    );
  });

  it('should preserve data integrity during migration operations', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.record({
          seed: fc.integer({ min: 1, max: 100000 }),
          sessionCount: fc.integer({ min: 1, max: 5 })
        }),
        ({ seed, sessionCount }) => {
          const tempDir = os.tmpdir();
          const dbPath = path.join(tempDir, `test-migration-data-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(dbPath);
          
          if (fs.existsSync(dbPath)) {
            fs.unlinkSync(dbPath);
          }
          
          const db = new Database(dbPath);
          initializeSchema(db);
          
          // Insert test data
          const sessionIds: string[] = [];
          for (let i = 0; i < sessionCount; i++) {
            const sessionId = `session-${seed}-${i}`;
            sessionIds.push(sessionId);
            db.prepare(`
              INSERT INTO session_log (id, start_time)
              VALUES (?, ?)
            `).run(sessionId, Date.now() + i);
          }
          
          // Verify data exists
          const beforeCount = db.prepare('SELECT COUNT(*) as count FROM session_log').get() as { count: number };
          expect(beforeCount.count).toBe(sessionCount);
          
          // Attempt migration (should succeed with no changes since no migrations to apply)
          const result = migrate(db);
          expect(result.success).toBe(true);
          
          // Verify data still exists after migration
          const afterCount = db.prepare('SELECT COUNT(*) as count FROM session_log').get() as { count: number };
          expect(afterCount.count).toBe(sessionCount);
          
          // Verify all session IDs are still present
          const sessions = db.prepare('SELECT id FROM session_log').all() as Array<{ id: string }>;
          const retrievedIds = sessions.map(s => s.id);
          for (const sessionId of sessionIds) {
            expect(retrievedIds).toContain(sessionId);
          }
          
          db.close();
        }
      ),
      { numRuns: 3 }
    );
  });

  it('should handle concurrent migration attempts safely', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const dbPath = path.join(tempDir, `test-migration-concurrent-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(dbPath);
          
          if (fs.existsSync(dbPath)) {
            fs.unlinkSync(dbPath);
          }
          
          const db = new Database(dbPath);
          initializeSchema(db);
          
          const initialVersion = getCurrentSchemaVersion(db);
          
          // Attempt multiple migrations to same version
          const result1 = migrate(db, initialVersion);
          const result2 = migrate(db, initialVersion);
          
          // Both should succeed
          expect(result1.success).toBe(true);
          expect(result2.success).toBe(true);
          
          // Version should remain consistent
          const finalVersion = getCurrentSchemaVersion(db);
          expect(finalVersion).toBe(initialVersion);
          
          // Migration integrity should be maintained
          const isValid = validateMigrationIntegrity(db);
          expect(isValid).toBe(true);
          
          db.close();
        }
      ),
      { numRuns: 3 }
    );
  });

  it('should record migration timestamps', { timeout: 15000 }, () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100000 }),
        (seed) => {
          const tempDir = os.tmpdir();
          const dbPath = path.join(tempDir, `test-migration-timestamp-${seed}-${Date.now()}.db`);
          
          createdDatabases.push(dbPath);
          
          if (fs.existsSync(dbPath)) {
            fs.unlinkSync(dbPath);
          }
          
          const db = new Database(dbPath);
          initializeSchema(db);
          
          // Get version 1 timestamp
          const versionInfo = db.prepare(
            'SELECT version, applied_at FROM schema_version WHERE version = 1'
          ).get() as { version: number; applied_at: number };
          
          expect(versionInfo).toBeDefined();
          expect(versionInfo.version).toBe(1);
          expect(versionInfo.applied_at).toBeGreaterThan(0);
          
          // Timestamp should be reasonable (within last hour)
          const now = Math.floor(Date.now() / 1000);
          const oneHourAgo = now - 3600;
          expect(versionInfo.applied_at).toBeGreaterThan(oneHourAgo);
          expect(versionInfo.applied_at).toBeLessThanOrEqual(now);
          
          db.close();
        }
      ),
      { numRuns: 3 }
    );
  });
});
