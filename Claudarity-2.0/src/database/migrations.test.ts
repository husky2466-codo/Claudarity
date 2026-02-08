/**
 * Unit tests for database migration system
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
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

describe('Database Migration System', () => {
  let db: Database.Database;
  let dbPath: string;

  beforeEach(() => {
    const tempDir = os.tmpdir();
    dbPath = path.join(tempDir, `test-migration-${Date.now()}.db`);
    db = new Database(dbPath);
    initializeSchema(db);
  });

  afterEach(() => {
    if (db) {
      db.close();
    }
    if (fs.existsSync(dbPath)) {
      fs.unlinkSync(dbPath);
    }
  });

  describe('getCurrentSchemaVersion', () => {
    it('should return version 1 for newly initialized database', () => {
      const version = getCurrentSchemaVersion(db);
      expect(version).toBe(1);
    });
  });

  describe('migrate', () => {
    it('should return success when no migrations to apply', () => {
      const result = migrate(db);
      expect(result.success).toBe(true);
      expect(result.fromVersion).toBe(1);
      expect(result.toVersion).toBe(1);
      expect(result.appliedMigrations).toEqual([]);
    });

    it('should not allow migrating backwards', () => {
      const result = migrate(db, 0);
      expect(result.success).toBe(false);
      expect(result.error).toContain('Cannot migrate backwards');
    });

    it('should maintain current version when target equals current', () => {
      const currentVersion = getCurrentSchemaVersion(db);
      const result = migrate(db, currentVersion);
      expect(result.success).toBe(true);
      expect(result.fromVersion).toBe(currentVersion);
      expect(result.toVersion).toBe(currentVersion);
      expect(result.appliedMigrations).toEqual([]);
    });
  });

  describe('rollback', () => {
    it('should not allow rolling back to current or higher version', () => {
      const currentVersion = getCurrentSchemaVersion(db);
      const result = rollback(db, currentVersion);
      expect(result.success).toBe(false);
      expect(result.error).toContain('Cannot rollback');
    });

    it('should not allow rolling back below version 1', () => {
      const result = rollback(db, 0);
      expect(result.success).toBe(false);
      expect(result.error).toContain('Cannot rollback below version 1');
    });
  });

  describe('getPendingMigrations', () => {
    it('should return empty array when no pending migrations', () => {
      const pending = getPendingMigrations(db);
      expect(pending).toEqual([]);
    });
  });

  describe('getAppliedMigrations', () => {
    it('should return version 1 for newly initialized database', () => {
      const applied = getAppliedMigrations(db);
      expect(applied).toContain(1);
      expect(applied.length).toBeGreaterThanOrEqual(1);
    });

    it('should return versions in ascending order', () => {
      const applied = getAppliedMigrations(db);
      for (let i = 1; i < applied.length; i++) {
        expect(applied[i]).toBeGreaterThan(applied[i - 1]);
      }
    });
  });

  describe('validateMigrationIntegrity', () => {
    it('should return true for newly initialized database', () => {
      const isValid = validateMigrationIntegrity(db);
      expect(isValid).toBe(true);
    });

    it('should return false if version 1 is missing', () => {
      // Remove version 1 entry
      db.prepare('DELETE FROM schema_version WHERE version = 1').run();
      const isValid = validateMigrationIntegrity(db);
      expect(isValid).toBe(false);
    });
  });

  describe('migration transactions', () => {
    it('should rollback on migration failure', () => {
      const currentVersion = getCurrentSchemaVersion(db);
      
      // Create a migration that will fail
      const failingMigration: Migration = {
        version: 2,
        description: 'Failing migration',
        up: () => {
          throw new Error('Migration failed');
        }
      };

      // Manually test the transaction behavior
      try {
        const transaction = db.transaction(() => {
          failingMigration.up(db);
          db.prepare('INSERT INTO schema_version (version, applied_at) VALUES (?, ?)').run(2, Date.now());
        });
        transaction();
      } catch (error) {
        // Expected to fail
      }

      // Version should still be the same
      const newVersion = getCurrentSchemaVersion(db);
      expect(newVersion).toBe(currentVersion);
    });
  });

  describe('schema version tracking', () => {
    it('should track applied_at timestamp', () => {
      const result = db.prepare('SELECT version, applied_at FROM schema_version WHERE version = 1').get() as { version: number; applied_at: number };
      expect(result).toBeDefined();
      expect(result.version).toBe(1);
      expect(result.applied_at).toBeGreaterThan(0);
    });

    it('should maintain version history', () => {
      const versions = db.prepare('SELECT version FROM schema_version ORDER BY version ASC').all() as Array<{ version: number }>;
      expect(versions.length).toBeGreaterThanOrEqual(1);
      expect(versions[0].version).toBe(1);
    });
  });
});
