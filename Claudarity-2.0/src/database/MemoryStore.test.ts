/**
 * Memory Store Tests
 * Tests CRUD operations for all data types
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { MemoryStoreImpl } from './MemoryStore';
import type {
  FeedbackEntry,
  ContextEntry,
  PreferenceEntry,
  Session,
  Template
} from './types';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';

describe('MemoryStore', () => {
  let memoryStore: MemoryStoreImpl;
  let testDbPath: string;

  beforeEach(() => {
    // Create a temporary database file for testing
    const tempDir = os.tmpdir();
    testDbPath = path.join(tempDir, `test-claudarity-${Date.now()}.db`);
    memoryStore = new MemoryStoreImpl(testDbPath);
  });

  afterEach(() => {
    // Clean up
    memoryStore.close();
    if (fs.existsSync(testDbPath)) {
      fs.unlinkSync(testDbPath);
    }
  });

  // ==================== Feedback Operations ====================

  describe('Feedback Operations', () => {
    it('should store and retrieve feedback', () => {
      const sessionId = 'session-1';
      const session: Session = {
        id: sessionId,
        start_time: Date.now(),
      };
      memoryStore.createSession(session);

      const feedback: FeedbackEntry = {
        id: 'feedback-1',
        session_id: sessionId,
        timestamp: Date.now(),
        feedback_type: 'positive',
        confidence: 0.9,
        text_content: 'looks good',
        code_snippet: 'const x = 1;',
        file_path: '/test/file.ts',
        suggestion_type: 'code_completion',
        language: 'typescript',
        operation: 'edit',
        matched_patterns: JSON.stringify(['approval', 'positive']),
      };

      memoryStore.storeFeedback(feedback);

      const results = memoryStore.queryFeedback({ session_id: sessionId });
      expect(results).toHaveLength(1);
      expect(results[0].id).toBe(feedback.id);
      expect(results[0].feedback_type).toBe('positive');
      expect(results[0].confidence).toBe(0.9);
      expect(results[0].text_content).toBe('looks good');
    });

    it('should filter feedback by type', () => {
      const sessionId = 'session-2';
      const session: Session = {
        id: sessionId,
        start_time: Date.now(),
      };
      memoryStore.createSession(session);

      const positiveFeedback: FeedbackEntry = {
        id: 'feedback-pos',
        session_id: sessionId,
        timestamp: Date.now(),
        feedback_type: 'positive',
        confidence: 0.9,
      };

      const negativeFeedback: FeedbackEntry = {
        id: 'feedback-neg',
        session_id: sessionId,
        timestamp: Date.now(),
        feedback_type: 'negative',
        confidence: 0.8,
      };

      memoryStore.storeFeedback(positiveFeedback);
      memoryStore.storeFeedback(negativeFeedback);

      const positiveResults = memoryStore.queryFeedback({
        session_id: sessionId,
        feedback_type: 'positive',
      });
      expect(positiveResults).toHaveLength(1);
      expect(positiveResults[0].feedback_type).toBe('positive');

      const negativeResults = memoryStore.queryFeedback({
        session_id: sessionId,
        feedback_type: 'negative',
      });
      expect(negativeResults).toHaveLength(1);
      expect(negativeResults[0].feedback_type).toBe('negative');
    });

    it('should filter feedback by time range', () => {
      const sessionId = 'session-3';
      const session: Session = {
        id: sessionId,
        start_time: Date.now(),
      };
      memoryStore.createSession(session);

      const now = Date.now();
      const oldFeedback: FeedbackEntry = {
        id: 'feedback-old',
        session_id: sessionId,
        timestamp: now - 10000,
        feedback_type: 'positive',
        confidence: 0.9,
      };

      const newFeedback: FeedbackEntry = {
        id: 'feedback-new',
        session_id: sessionId,
        timestamp: now,
        feedback_type: 'positive',
        confidence: 0.9,
      };

      memoryStore.storeFeedback(oldFeedback);
      memoryStore.storeFeedback(newFeedback);

      const recentResults = memoryStore.queryFeedback({
        session_id: sessionId,
        start_time: now - 5000,
      });
      expect(recentResults).toHaveLength(1);
      expect(recentResults[0].id).toBe('feedback-new');
    });

    it('should limit feedback results', () => {
      const sessionId = 'session-4';
      const session: Session = {
        id: sessionId,
        start_time: Date.now(),
      };
      memoryStore.createSession(session);

      for (let i = 0; i < 10; i++) {
        const feedback: FeedbackEntry = {
          id: `feedback-${i}`,
          session_id: sessionId,
          timestamp: Date.now() + i,
          feedback_type: 'positive',
          confidence: 0.9,
        };
        memoryStore.storeFeedback(feedback);
      }

      const results = memoryStore.queryFeedback({
        session_id: sessionId,
        limit: 5,
      });
      expect(results).toHaveLength(5);
    });
  });

  // ==================== Context Operations ====================

  describe('Context Operations', () => {
    it('should store and retrieve context', () => {
      const sessionId = 'session-5';
      const session: Session = {
        id: sessionId,
        start_time: Date.now(),
      };
      memoryStore.createSession(session);

      const context: ContextEntry = {
        id: 'context-1',
        session_id: sessionId,
        timestamp: Date.now(),
        context_type: 'code_pattern',
        content: 'Use early returns for error handling',
        file_path: '/test/file.ts',
        language: 'typescript',
        tags: JSON.stringify(['error_handling', 'best_practice']),
        relevance_score: 0.85,
        usage_count: 3,
      };

      memoryStore.storeContext(context);

      const results = memoryStore.queryContext({ session_id: sessionId });
      expect(results).toHaveLength(1);
      expect(results[0].id).toBe(context.id);
      expect(results[0].context_type).toBe('code_pattern');
      expect(results[0].relevance_score).toBe(0.85);
    });

    it('should filter context by type', () => {
      const sessionId = 'session-6';
      const session: Session = {
        id: sessionId,
        start_time: Date.now(),
      };
      memoryStore.createSession(session);

      const patternContext: ContextEntry = {
        id: 'context-pattern',
        session_id: sessionId,
        timestamp: Date.now(),
        context_type: 'code_pattern',
        content: 'Pattern content',
      };

      const preferenceContext: ContextEntry = {
        id: 'context-preference',
        session_id: sessionId,
        timestamp: Date.now(),
        context_type: 'preference',
        content: 'Preference content',
      };

      memoryStore.storeContext(patternContext);
      memoryStore.storeContext(preferenceContext);

      const patternResults = memoryStore.queryContext({
        session_id: sessionId,
        context_type: 'code_pattern',
      });
      expect(patternResults).toHaveLength(1);
      expect(patternResults[0].context_type).toBe('code_pattern');
    });

    it('should filter context by minimum relevance', () => {
      const sessionId = 'session-7';
      const session: Session = {
        id: sessionId,
        start_time: Date.now(),
      };
      memoryStore.createSession(session);

      const highRelevance: ContextEntry = {
        id: 'context-high',
        session_id: sessionId,
        timestamp: Date.now(),
        context_type: 'code_pattern',
        content: 'High relevance',
        relevance_score: 0.9,
      };

      const lowRelevance: ContextEntry = {
        id: 'context-low',
        session_id: sessionId,
        timestamp: Date.now(),
        context_type: 'code_pattern',
        content: 'Low relevance',
        relevance_score: 0.3,
      };

      memoryStore.storeContext(highRelevance);
      memoryStore.storeContext(lowRelevance);

      const results = memoryStore.queryContext({
        session_id: sessionId,
        min_relevance: 0.7,
      });
      expect(results).toHaveLength(1);
      expect(results[0].id).toBe('context-high');
    });

    it('should order context by relevance score', () => {
      const sessionId = 'session-8';
      const session: Session = {
        id: sessionId,
        start_time: Date.now(),
      };
      memoryStore.createSession(session);

      const contexts = [
        { id: 'context-1', relevance_score: 0.5 },
        { id: 'context-2', relevance_score: 0.9 },
        { id: 'context-3', relevance_score: 0.7 },
      ];

      for (const ctx of contexts) {
        const context: ContextEntry = {
          id: ctx.id,
          session_id: sessionId,
          timestamp: Date.now(),
          context_type: 'code_pattern',
          content: 'Content',
          relevance_score: ctx.relevance_score,
        };
        memoryStore.storeContext(context);
      }

      const results = memoryStore.queryContext({ session_id: sessionId });
      expect(results).toHaveLength(3);
      expect(results[0].id).toBe('context-2'); // Highest relevance
      expect(results[1].id).toBe('context-3');
      expect(results[2].id).toBe('context-1'); // Lowest relevance
    });
  });

  // ==================== Preference Operations ====================

  describe('Preference Operations', () => {
    it('should store and retrieve preferences', () => {
      const preference: PreferenceEntry = {
        id: 'pref-1',
        category: 'error_handling',
        preference_key: 'use_early_returns',
        preference_value: 'true',
        confidence: 0.85,
        evidence_count: 5,
        last_updated: Date.now(),
      };

      memoryStore.storePreference(preference);

      const results = memoryStore.queryPreferences({
        category: 'error_handling',
      });
      expect(results).toHaveLength(1);
      expect(results[0].preference_key).toBe('use_early_returns');
      expect(results[0].confidence).toBe(0.85);
    });

    it('should update existing preference on conflict', () => {
      const preference1: PreferenceEntry = {
        id: 'pref-1',
        category: 'naming',
        preference_key: 'case_style',
        preference_value: 'camelCase',
        confidence: 0.7,
        evidence_count: 3,
        last_updated: Date.now(),
      };

      const preference2: PreferenceEntry = {
        id: 'pref-2',
        category: 'naming',
        preference_key: 'case_style',
        preference_value: 'snake_case',
        confidence: 0.9,
        evidence_count: 10,
        last_updated: Date.now(),
      };

      memoryStore.storePreference(preference1);
      memoryStore.storePreference(preference2);

      const results = memoryStore.queryPreferences({
        category: 'naming',
        preference_key: 'case_style',
      });
      expect(results).toHaveLength(1);
      expect(results[0].preference_value).toBe('snake_case');
      expect(results[0].confidence).toBe(0.9);
    });

    it('should filter preferences by minimum confidence', () => {
      const prefs = [
        {
          id: 'pref-1',
          category: 'testing' as const,
          preference_key: 'use_property_tests',
          preference_value: 'true',
          confidence: 0.9,
        },
        {
          id: 'pref-2',
          category: 'testing' as const,
          preference_key: 'use_mocks',
          preference_value: 'false',
          confidence: 0.5,
        },
      ];

      for (const pref of prefs) {
        const preference: PreferenceEntry = {
          ...pref,
          last_updated: Date.now(),
        };
        memoryStore.storePreference(preference);
      }

      const results = memoryStore.queryPreferences({
        category: 'testing',
        min_confidence: 0.8,
      });
      expect(results).toHaveLength(1);
      expect(results[0].preference_key).toBe('use_property_tests');
    });

    it('should order preferences by confidence', () => {
      const prefs = [
        { id: 'pref-1', confidence: 0.5 },
        { id: 'pref-2', confidence: 0.9 },
        { id: 'pref-3', confidence: 0.7 },
      ];

      for (const pref of prefs) {
        const preference: PreferenceEntry = {
          id: pref.id,
          category: 'structure',
          preference_key: `key-${pref.id}`,
          preference_value: 'value',
          confidence: pref.confidence,
          last_updated: Date.now(),
        };
        memoryStore.storePreference(preference);
      }

      const results = memoryStore.queryPreferences({ category: 'structure' });
      expect(results).toHaveLength(3);
      expect(results[0].confidence).toBe(0.9);
      expect(results[1].confidence).toBe(0.7);
      expect(results[2].confidence).toBe(0.5);
    });
  });

  // ==================== Session Operations ====================

  describe('Session Operations', () => {
    it('should create and retrieve sessions', () => {
      const session: Session = {
        id: 'session-1',
        start_time: Date.now(),
        project_path: '/test/project',
        activity_summary: 'Working on feature X',
        feedback_count: 0,
        context_injections: 0,
      };

      const sessionId = memoryStore.createSession(session);
      expect(sessionId).toBe('session-1');

      const results = memoryStore.querySession({});
      expect(results).toHaveLength(1);
      expect(results[0].id).toBe('session-1');
      expect(results[0].project_path).toBe('/test/project');
    });

    it('should update session fields', () => {
      const session: Session = {
        id: 'session-2',
        start_time: Date.now(),
        feedback_count: 0,
      };

      memoryStore.createSession(session);

      memoryStore.updateSession('session-2', {
        end_time: Date.now(),
        feedback_count: 5,
        context_injections: 3,
        activity_summary: 'Completed feature Y',
      });

      const results = memoryStore.querySession({});
      expect(results).toHaveLength(1);
      expect(results[0].feedback_count).toBe(5);
      expect(results[0].context_injections).toBe(3);
      expect(results[0].activity_summary).toBe('Completed feature Y');
      expect(results[0].end_time).toBeDefined();
    });

    it('should filter sessions by project path', () => {
      const session1: Session = {
        id: 'session-1',
        start_time: Date.now(),
        project_path: '/project/a',
      };

      const session2: Session = {
        id: 'session-2',
        start_time: Date.now(),
        project_path: '/project/b',
      };

      memoryStore.createSession(session1);
      memoryStore.createSession(session2);

      const results = memoryStore.querySession({
        project_path: '/project/a',
      });
      expect(results).toHaveLength(1);
      expect(results[0].id).toBe('session-1');
    });

    it('should filter sessions by time range', () => {
      const now = Date.now();
      const session1: Session = {
        id: 'session-old',
        start_time: now - 10000,
      };

      const session2: Session = {
        id: 'session-new',
        start_time: now,
      };

      memoryStore.createSession(session1);
      memoryStore.createSession(session2);

      const results = memoryStore.querySession({
        start_time: now - 5000,
      });
      expect(results).toHaveLength(1);
      expect(results[0].id).toBe('session-new');
    });

    it('should order sessions by start time descending', () => {
      const sessions = [
        { id: 'session-1', start_time: 1000 },
        { id: 'session-2', start_time: 3000 },
        { id: 'session-3', start_time: 2000 },
      ];

      for (const sess of sessions) {
        memoryStore.createSession(sess);
      }

      const results = memoryStore.querySession({});
      expect(results).toHaveLength(3);
      expect(results[0].id).toBe('session-2'); // Most recent
      expect(results[1].id).toBe('session-3');
      expect(results[2].id).toBe('session-1'); // Oldest
    });
  });

  // ==================== Template Operations ====================

  describe('Template Operations', () => {
    it('should store and retrieve templates', () => {
      const now = Date.now();
      const template: Template = {
        id: 'template-1',
        category: 'error_handling',
        pattern: 'try-catch with specific error types',
        confidence: 0.85,
        alpha: 17,
        beta: 3,
        usage_count: 20,
        created_at: now,
        updated_at: now,
      };

      memoryStore.storeTemplate(template);

      const results = memoryStore.queryTemplates({
        category: 'error_handling',
      });
      expect(results).toHaveLength(1);
      expect(results[0].pattern).toBe('try-catch with specific error types');
      expect(results[0].confidence).toBe(0.85);
      expect(results[0].alpha).toBe(17);
      expect(results[0].beta).toBe(3);
    });

    it('should update template fields', () => {
      const now = Date.now();
      const template: Template = {
        id: 'template-2',
        category: 'naming',
        pattern: 'camelCase for variables',
        confidence: 0.7,
        alpha: 7,
        beta: 3,
        usage_count: 10,
        created_at: now,
        updated_at: now,
      };

      memoryStore.storeTemplate(template);

      memoryStore.updateTemplate('template-2', {
        confidence: 0.9,
        alpha: 18,
        beta: 2,
        usage_count: 20,
        updated_at: now + 1000,
      });

      const results = memoryStore.queryTemplates({});
      expect(results).toHaveLength(1);
      expect(results[0].confidence).toBe(0.9);
      expect(results[0].alpha).toBe(18);
      expect(results[0].beta).toBe(2);
      expect(results[0].usage_count).toBe(20);
    });

    it('should filter templates by minimum confidence', () => {
      const now = Date.now();
      const templates = [
        {
          id: 'template-1',
          confidence: 0.9,
          alpha: 18,
          beta: 2,
        },
        {
          id: 'template-2',
          confidence: 0.5,
          alpha: 5,
          beta: 5,
        },
      ];

      for (const tmpl of templates) {
        const template: Template = {
          id: tmpl.id,
          category: 'structure',
          pattern: 'pattern',
          confidence: tmpl.confidence,
          alpha: tmpl.alpha,
          beta: tmpl.beta,
          created_at: now,
          updated_at: now,
        };
        memoryStore.storeTemplate(template);
      }

      const results = memoryStore.queryTemplates({
        min_confidence: 0.8,
      });
      expect(results).toHaveLength(1);
      expect(results[0].id).toBe('template-1');
    });

    it('should filter templates by archived status', () => {
      const now = Date.now();
      const activeTemplate: Template = {
        id: 'template-active',
        category: 'testing',
        pattern: 'active pattern',
        confidence: 0.8,
        alpha: 8,
        beta: 2,
        archived: false,
        created_at: now,
        updated_at: now,
      };

      const archivedTemplate: Template = {
        id: 'template-archived',
        category: 'testing',
        pattern: 'archived pattern',
        confidence: 0.2,
        alpha: 2,
        beta: 8,
        archived: true,
        created_at: now,
        updated_at: now,
      };

      memoryStore.storeTemplate(activeTemplate);
      memoryStore.storeTemplate(archivedTemplate);

      const activeResults = memoryStore.queryTemplates({
        archived: false,
      });
      expect(activeResults).toHaveLength(1);
      expect(activeResults[0].id).toBe('template-active');

      const archivedResults = memoryStore.queryTemplates({
        archived: true,
      });
      expect(archivedResults).toHaveLength(1);
      expect(archivedResults[0].id).toBe('template-archived');
    });

    it('should order templates by confidence', () => {
      const now = Date.now();
      const templates = [
        { id: 'template-1', confidence: 0.5, alpha: 5, beta: 5 },
        { id: 'template-2', confidence: 0.9, alpha: 18, beta: 2 },
        { id: 'template-3', confidence: 0.7, alpha: 7, beta: 3 },
      ];

      for (const tmpl of templates) {
        const template: Template = {
          id: tmpl.id,
          category: 'structure',
          pattern: 'pattern',
          confidence: tmpl.confidence,
          alpha: tmpl.alpha,
          beta: tmpl.beta,
          created_at: now,
          updated_at: now,
        };
        memoryStore.storeTemplate(template);
      }

      const results = memoryStore.queryTemplates({});
      expect(results).toHaveLength(3);
      expect(results[0].confidence).toBe(0.9);
      expect(results[1].confidence).toBe(0.7);
      expect(results[2].confidence).toBe(0.5);
    });
  });

  // ==================== Integration Tests ====================

  describe('Integration Tests', () => {
    it('should maintain foreign key relationships', () => {
      const sessionId = 'session-integration';
      const session: Session = {
        id: sessionId,
        start_time: Date.now(),
      };
      memoryStore.createSession(session);

      const feedback: FeedbackEntry = {
        id: 'feedback-integration',
        session_id: sessionId,
        timestamp: Date.now(),
        feedback_type: 'positive',
        confidence: 0.9,
      };
      memoryStore.storeFeedback(feedback);

      const context: ContextEntry = {
        id: 'context-integration',
        session_id: sessionId,
        timestamp: Date.now(),
        context_type: 'code_pattern',
        content: 'Integration test content',
      };
      memoryStore.storeContext(context);

      const feedbackResults = memoryStore.queryFeedback({
        session_id: sessionId,
      });
      expect(feedbackResults).toHaveLength(1);

      const contextResults = memoryStore.queryContext({
        session_id: sessionId,
      });
      expect(contextResults).toHaveLength(1);
    });

    it('should handle empty queries', () => {
      const feedbackResults = memoryStore.queryFeedback({});
      expect(feedbackResults).toHaveLength(0);

      const contextResults = memoryStore.queryContext({});
      expect(contextResults).toHaveLength(0);

      const preferenceResults = memoryStore.queryPreferences({});
      expect(preferenceResults).toHaveLength(0);

      const sessionResults = memoryStore.querySession({});
      expect(sessionResults).toHaveLength(0);

      const templateResults = memoryStore.queryTemplates({});
      expect(templateResults).toHaveLength(0);
    });
  });

  // ==================== Export/Import Tests ====================

  describe('Export/Import Operations', () => {
    it('should export database to a backup file', () => {
      // Create some test data
      const sessionId = 'session-export';
      const session: Session = {
        id: sessionId,
        start_time: Date.now(),
        project_path: '/test/project',
      };
      memoryStore.createSession(session);

      const feedback: FeedbackEntry = {
        id: 'feedback-export',
        session_id: sessionId,
        timestamp: Date.now(),
        feedback_type: 'positive',
        confidence: 0.9,
      };
      memoryStore.storeFeedback(feedback);

      const preference: PreferenceEntry = {
        id: 'pref-export',
        category: 'naming',
        preference_key: 'case_style',
        preference_value: 'camelCase',
        confidence: 0.85,
        last_updated: Date.now(),
      };
      memoryStore.storePreference(preference);

      // Export database
      const exportPath = path.join(os.tmpdir(), `export-${Date.now()}.db`);
      const result = memoryStore.exportDatabase(exportPath);

      expect(result.success).toBe(true);
      expect(result.path).toBe(exportPath);
      expect(result.recordCount).toBeGreaterThan(0);
      expect(fs.existsSync(exportPath)).toBe(true);

      // Clean up
      fs.unlinkSync(exportPath);
    });

    it('should import database with merge strategy', () => {
      // Create source database with test data
      const sourceDbPath = path.join(os.tmpdir(), `source-${Date.now()}.db`);
      const sourceStore = new MemoryStoreImpl(sourceDbPath);

      const sessionId = 'session-import-merge';
      const session: Session = {
        id: sessionId,
        start_time: Date.now(),
        project_path: '/source/project',
      };
      sourceStore.createSession(session);

      const feedback: FeedbackEntry = {
        id: 'feedback-import-merge',
        session_id: sessionId,
        timestamp: Date.now(),
        feedback_type: 'positive',
        confidence: 0.9,
      };
      sourceStore.storeFeedback(feedback);

      sourceStore.close();

      // Import into target database
      const result = memoryStore.importDatabase(sourceDbPath, 'merge');

      expect(result.success).toBe(true);
      expect(result.recordsImported).toBeGreaterThan(0);
      expect(result.errors).toHaveLength(0);

      // Verify data was imported
      const sessions = memoryStore.querySession({ project_path: '/source/project' });
      expect(sessions).toHaveLength(1);
      expect(sessions[0].id).toBe(sessionId);

      const feedbackResults = memoryStore.queryFeedback({ session_id: sessionId });
      expect(feedbackResults).toHaveLength(1);
      expect(feedbackResults[0].id).toBe('feedback-import-merge');

      // Clean up
      fs.unlinkSync(sourceDbPath);
    });

    it('should import database with replace strategy', () => {
      // Add some data to target database first
      const targetSession: Session = {
        id: 'target-session',
        start_time: Date.now(),
        project_path: '/target/project',
      };
      memoryStore.createSession(targetSession);

      // Create source database with different data
      const sourceDbPath = path.join(os.tmpdir(), `source-replace-${Date.now()}.db`);
      const sourceStore = new MemoryStoreImpl(sourceDbPath);

      const sourceSession: Session = {
        id: 'source-session',
        start_time: Date.now(),
        project_path: '/source/project',
      };
      sourceStore.createSession(sourceSession);

      sourceStore.close();

      // Import with replace strategy
      const result = memoryStore.importDatabase(sourceDbPath, 'replace');

      expect(result.success).toBe(true);
      expect(result.recordsImported).toBeGreaterThan(0);

      // Verify old data was replaced
      const allSessions = memoryStore.querySession({});
      expect(allSessions).toHaveLength(1);
      expect(allSessions[0].id).toBe('source-session');

      // Clean up
      fs.unlinkSync(sourceDbPath);
    });

    it('should skip duplicate records with merge strategy', () => {
      // Create source database
      const sourceDbPath = path.join(os.tmpdir(), `source-duplicate-${Date.now()}.db`);
      const sourceStore = new MemoryStoreImpl(sourceDbPath);

      const sessionId = 'duplicate-session';
      const session: Session = {
        id: sessionId,
        start_time: Date.now(),
      };
      sourceStore.createSession(session);
      sourceStore.close();

      // First import
      const result1 = memoryStore.importDatabase(sourceDbPath, 'merge');
      expect(result1.success).toBe(true);
      expect(result1.recordsImported).toBeGreaterThan(0);

      // Second import (should skip duplicates)
      const result2 = memoryStore.importDatabase(sourceDbPath, 'merge');
      expect(result2.success).toBe(true);
      expect(result2.recordsSkipped).toBeGreaterThan(0);

      // Verify only one session exists
      const sessions = memoryStore.querySession({});
      expect(sessions).toHaveLength(1);

      // Clean up
      fs.unlinkSync(sourceDbPath);
    });

    it('should validate schema compatibility on import', () => {
      // Create a database with incompatible schema (simulated by using a newer version)
      const sourceDbPath = path.join(os.tmpdir(), `source-incompatible-${Date.now()}.db`);
      const sourceStore = new MemoryStoreImpl(sourceDbPath);
      
      // Manually insert a higher schema version
      const sourceDb = (sourceStore as any).db;
      sourceDb.prepare('INSERT INTO schema_version (version, applied_at) VALUES (?, ?)').run(999, Date.now());
      
      sourceStore.close();

      // Try to import
      const result = memoryStore.importDatabase(sourceDbPath, 'merge');

      expect(result.success).toBe(false);
      expect(result.errors.length).toBeGreaterThan(0);
      expect(result.errors[0]).toContain('Schema version mismatch');

      // Clean up
      fs.unlinkSync(sourceDbPath);
    });

    it('should handle non-existent source database', () => {
      const nonExistentPath = path.join(os.tmpdir(), 'non-existent.db');
      const result = memoryStore.importDatabase(nonExistentPath, 'merge');

      expect(result.success).toBe(false);
      expect(result.errors.length).toBeGreaterThan(0);
      expect(result.errors[0]).toContain('not found');
    });

    it('should export and import complete database', () => {
      // Create comprehensive test data
      const sessionId = 'session-complete';
      const session: Session = {
        id: sessionId,
        start_time: Date.now(),
        project_path: '/complete/project',
      };
      memoryStore.createSession(session);

      const feedback: FeedbackEntry = {
        id: 'feedback-complete',
        session_id: sessionId,
        timestamp: Date.now(),
        feedback_type: 'positive',
        confidence: 0.9,
      };
      memoryStore.storeFeedback(feedback);

      const context: ContextEntry = {
        id: 'context-complete',
        session_id: sessionId,
        timestamp: Date.now(),
        context_type: 'code_pattern',
        content: 'Complete test content',
      };
      memoryStore.storeContext(context);

      const preference: PreferenceEntry = {
        id: 'pref-complete',
        category: 'naming',
        preference_key: 'test_key',
        preference_value: 'test_value',
        confidence: 0.85,
        last_updated: Date.now(),
      };
      memoryStore.storePreference(preference);

      const template: Template = {
        id: 'template-complete',
        category: 'testing',
        pattern: 'test pattern',
        confidence: 0.8,
        alpha: 8,
        beta: 2,
        created_at: Date.now(),
        updated_at: Date.now(),
      };
      memoryStore.storeTemplate(template);

      // Export
      const exportPath = path.join(os.tmpdir(), `complete-export-${Date.now()}.db`);
      const exportResult = memoryStore.exportDatabase(exportPath);
      expect(exportResult.success).toBe(true);

      // Create new database and import
      const importDbPath = path.join(os.tmpdir(), `complete-import-${Date.now()}.db`);
      const importStore = new MemoryStoreImpl(importDbPath);
      const importResult = importStore.importDatabase(exportPath, 'merge');

      expect(importResult.success).toBe(true);
      expect(importResult.recordsImported).toBeGreaterThan(0);

      // Verify all data was imported
      const sessions = importStore.querySession({});
      expect(sessions).toHaveLength(1);

      const feedbackResults = importStore.queryFeedback({});
      expect(feedbackResults).toHaveLength(1);

      const contextResults = importStore.queryContext({});
      expect(contextResults).toHaveLength(1);

      const preferenceResults = importStore.queryPreferences({});
      expect(preferenceResults).toHaveLength(1);

      const templateResults = importStore.queryTemplates({});
      expect(templateResults).toHaveLength(1);

      // Clean up
      importStore.close();
      fs.unlinkSync(exportPath);
      fs.unlinkSync(importDbPath);
    });
  });
});
