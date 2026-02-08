/**
 * Database Migration System
 * Handles schema version upgrades and rollbacks
 * 
 * Feature: claudarity-modernization
 * Requirements: 4.7
 */

import Database from 'better-sqlite3';
import { getCurrentSchemaVersion } from './schema';

/**
 * Migration definition interface
 */
export interface Migration {
  version: number;
  description: string;
  up: (db: Database.Database) => void;
  down?: (db: Database.Database) => void;
}

/**
 * Migration result interface
 */
export interface MigrationResult {
  success: boolean;
  fromVersion: number;
  toVersion: number;
  appliedMigrations: number[];
  error?: string;
}

/**
 * Registry of all available migrations
 * Migrations are applied sequentially in order of version number
 */
const MIGRATIONS: Migration[] = [
  // Example migration (version 1 is the initial schema)
  // Future migrations will be added here
  // {
  //   version: 2,
  //   description: 'Add corrected fields to feedback_log',
  //   up: (db) => {
  //     db.exec(`
  //       ALTER TABLE feedback_log ADD COLUMN corrected BOOLEAN DEFAULT 0;
  //       ALTER TABLE feedback_log ADD COLUMN corrected_type TEXT;
  //     `);
  //   },
  //   down: (db) => {
  //     // SQLite doesn't support DROP COLUMN easily, would need table recreation
  //     throw new Error('Rollback not supported for this migration');
  //   }
  // }
];

/**
 * Apply migrations to bring database to target version
 * 
 * @param db - Better-sqlite3 database instance
 * @param targetVersion - Target schema version (defaults to latest)
 * @returns Migration result with success status and applied migrations
 */
export function migrate(
  db: Database.Database,
  targetVersion?: number
): MigrationResult {
  const currentVersion = getCurrentSchemaVersion(db);
  const maxVersion = Math.max(...MIGRATIONS.map(m => m.version), 1);
  const target = targetVersion ?? maxVersion;

  // Validate target version
  if (target < currentVersion) {
    return {
      success: false,
      fromVersion: currentVersion,
      toVersion: currentVersion,
      appliedMigrations: [],
      error: `Cannot migrate backwards from version ${currentVersion} to ${target}. Use rollback instead.`
    };
  }

  if (target === currentVersion) {
    return {
      success: true,
      fromVersion: currentVersion,
      toVersion: currentVersion,
      appliedMigrations: [],
    };
  }

  // Find migrations to apply
  const migrationsToApply = MIGRATIONS
    .filter(m => m.version > currentVersion && m.version <= target)
    .sort((a, b) => a.version - b.version);

  if (migrationsToApply.length === 0) {
    return {
      success: false,
      fromVersion: currentVersion,
      toVersion: currentVersion,
      appliedMigrations: [],
      error: `No migrations found between version ${currentVersion} and ${target}`
    };
  }

  const appliedMigrations: number[] = [];

  try {
    // Apply each migration in a transaction
    for (const migration of migrationsToApply) {
      const transaction = db.transaction(() => {
        // Apply the migration
        migration.up(db);

        // Update schema version
        const now = Math.floor(Date.now() / 1000);
        db.prepare('INSERT INTO schema_version (version, applied_at) VALUES (?, ?)').run(
          migration.version,
          now
        );

        appliedMigrations.push(migration.version);
      });

      transaction();
    }

    return {
      success: true,
      fromVersion: currentVersion,
      toVersion: target,
      appliedMigrations,
    };
  } catch (error) {
    // Migration failed - transaction will have rolled back automatically
    return {
      success: false,
      fromVersion: currentVersion,
      toVersion: currentVersion,
      appliedMigrations,
      error: error instanceof Error ? error.message : String(error)
    };
  }
}

/**
 * Rollback migrations to a previous version
 * 
 * @param db - Better-sqlite3 database instance
 * @param targetVersion - Target schema version to rollback to
 * @returns Migration result with success status
 */
export function rollback(
  db: Database.Database,
  targetVersion: number
): MigrationResult {
  const currentVersion = getCurrentSchemaVersion(db);

  // Validate target version
  if (targetVersion >= currentVersion) {
    return {
      success: false,
      fromVersion: currentVersion,
      toVersion: currentVersion,
      appliedMigrations: [],
      error: `Cannot rollback from version ${currentVersion} to ${targetVersion}. Use migrate instead.`
    };
  }

  if (targetVersion < 1) {
    return {
      success: false,
      fromVersion: currentVersion,
      toVersion: currentVersion,
      appliedMigrations: [],
      error: 'Cannot rollback below version 1'
    };
  }

  // Find migrations to rollback
  const migrationsToRollback = MIGRATIONS
    .filter(m => m.version > targetVersion && m.version <= currentVersion)
    .sort((a, b) => b.version - a.version); // Reverse order for rollback

  if (migrationsToRollback.length === 0) {
    return {
      success: false,
      fromVersion: currentVersion,
      toVersion: currentVersion,
      appliedMigrations: [],
      error: `No migrations found between version ${targetVersion} and ${currentVersion}`
    };
  }

  const rolledBackMigrations: number[] = [];

  try {
    // Rollback each migration in a transaction
    for (const migration of migrationsToRollback) {
      if (!migration.down) {
        throw new Error(`Migration ${migration.version} does not support rollback`);
      }

      const transaction = db.transaction(() => {
        // Rollback the migration
        migration.down!(db);

        // Remove schema version entry
        db.prepare('DELETE FROM schema_version WHERE version = ?').run(migration.version);

        rolledBackMigrations.push(migration.version);
      });

      transaction();
    }

    return {
      success: true,
      fromVersion: currentVersion,
      toVersion: targetVersion,
      appliedMigrations: rolledBackMigrations,
    };
  } catch (error) {
    // Rollback failed - transaction will have rolled back automatically
    return {
      success: false,
      fromVersion: currentVersion,
      toVersion: currentVersion,
      appliedMigrations: rolledBackMigrations,
      error: error instanceof Error ? error.message : String(error)
    };
  }
}

/**
 * Get list of pending migrations
 * 
 * @param db - Better-sqlite3 database instance
 * @returns Array of pending migration versions
 */
export function getPendingMigrations(db: Database.Database): Migration[] {
  const currentVersion = getCurrentSchemaVersion(db);
  return MIGRATIONS
    .filter(m => m.version > currentVersion)
    .sort((a, b) => a.version - b.version);
}

/**
 * Get list of applied migrations
 * 
 * @param db - Better-sqlite3 database instance
 * @returns Array of applied migration versions
 */
export function getAppliedMigrations(db: Database.Database): number[] {
  try {
    const results = db.prepare('SELECT version FROM schema_version ORDER BY version ASC').all() as Array<{ version: number }>;
    return results.map(r => r.version);
  } catch (error) {
    return [];
  }
}

/**
 * Validate migration integrity
 * Checks that all migrations between version 1 and current are applied
 * 
 * @param db - Better-sqlite3 database instance
 * @returns true if migration history is valid, false otherwise
 */
export function validateMigrationIntegrity(db: Database.Database): boolean {
  const currentVersion = getCurrentSchemaVersion(db);
  const appliedVersions = getAppliedMigrations(db);

  // Check that version 1 exists
  if (!appliedVersions.includes(1)) {
    return false;
  }

  // Check that all versions from 1 to current exist
  for (let v = 1; v <= currentVersion; v++) {
    if (!appliedVersions.includes(v)) {
      return false;
    }
  }

  return true;
}
