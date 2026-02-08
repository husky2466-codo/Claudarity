/**
 * Database module exports
 */

export {
  initializeSchema,
  getCurrentSchemaVersion,
  verifySchema,
  SCHEMA_STATEMENTS,
  INDEX_STATEMENTS
} from './schema';

export {
  MemoryStoreImpl
} from './MemoryStore';

export {
  migrate,
  rollback,
  getPendingMigrations,
  getAppliedMigrations,
  validateMigrationIntegrity
} from './migrations';

export type {
  Migration,
  MigrationResult
} from './migrations';

export type {
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
  TemplateFilter
} from './types';
