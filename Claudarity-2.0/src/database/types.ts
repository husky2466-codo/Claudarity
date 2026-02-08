/**
 * Type definitions for Memory Store data models
 */

/**
 * Feedback entry stored in feedback_log table
 */
export interface FeedbackEntry {
  id: string;
  session_id: string;
  timestamp: number;
  feedback_type: 'positive' | 'negative' | 'neutral';
  confidence: number;
  text_content?: string;
  code_snippet?: string;
  file_path?: string;
  suggestion_type?: string;
  language?: string;
  operation?: string;
  matched_patterns?: string; // JSON array
  corrected?: boolean;
  corrected_type?: 'positive' | 'negative' | 'neutral';
}

/**
 * Filter for querying feedback entries
 */
export interface FeedbackFilter {
  session_id?: string;
  feedback_type?: 'positive' | 'negative' | 'neutral';
  file_path?: string;
  start_time?: number;
  end_time?: number;
  limit?: number;
}

/**
 * Context entry stored in context_memory table
 */
export interface ContextEntry {
  id: string;
  session_id: string;
  timestamp: number;
  context_type: 'code_pattern' | 'preference' | 'solution';
  content: string;
  file_path?: string;
  language?: string;
  tags?: string; // JSON array
  relevance_score?: number;
  usage_count?: number;
  last_used?: number;
}

/**
 * Filter for querying context entries
 */
export interface ContextFilter {
  session_id?: string;
  context_type?: 'code_pattern' | 'preference' | 'solution';
  file_path?: string;
  language?: string;
  min_relevance?: number;
  start_time?: number;
  end_time?: number;
  limit?: number;
}

/**
 * Preference entry stored in code_preferences table
 */
export interface PreferenceEntry {
  id: string;
  category: 'error_handling' | 'naming' | 'structure' | 'testing';
  preference_key: string;
  preference_value: string;
  confidence: number;
  evidence_count?: number;
  last_updated: number;
}

/**
 * Filter for querying preference entries
 */
export interface PreferenceFilter {
  category?: 'error_handling' | 'naming' | 'structure' | 'testing';
  preference_key?: string;
  min_confidence?: number;
  limit?: number;
}

/**
 * Session entry stored in session_log table
 */
export interface Session {
  id: string;
  start_time: number;
  end_time?: number;
  project_path?: string;
  activity_summary?: string;
  feedback_count?: number;
  context_injections?: number;
}

/**
 * Filter for querying session entries
 */
export interface SessionFilter {
  project_path?: string;
  start_time?: number;
  end_time?: number;
  limit?: number;
}

/**
 * Template entry stored in template_evolution table
 */
export interface Template {
  id: string;
  category: 'error_handling' | 'naming' | 'structure' | 'testing';
  pattern: string;
  confidence: number;
  alpha: number;
  beta: number;
  usage_count?: number;
  last_used?: number;
  archived?: boolean;
  created_at: number;
  updated_at: number;
}

/**
 * Filter for querying template entries
 */
export interface TemplateFilter {
  category?: 'error_handling' | 'naming' | 'structure' | 'testing';
  min_confidence?: number;
  archived?: boolean;
  limit?: number;
}

/**
 * Result of export operation
 */
export interface ExportResult {
  success: boolean;
  path: string;
  recordCount: number;
  error?: string;
}

/**
 * Result of import operation
 */
export interface ImportResult {
  success: boolean;
  recordsImported: number;
  recordsSkipped: number;
  errors: string[];
}

/**
 * Memory Store interface for database operations
 */
export interface MemoryStore {
  // Feedback operations
  storeFeedback(feedback: FeedbackEntry): void;
  queryFeedback(filter: FeedbackFilter): FeedbackEntry[];
  
  // Context operations
  storeContext(context: ContextEntry): void;
  queryContext(filter: ContextFilter): ContextEntry[];
  
  // Preference operations
  storePreference(pref: PreferenceEntry): void;
  queryPreferences(filter: PreferenceFilter): PreferenceEntry[];
  
  // Session operations
  createSession(session: string): string;
  updateSession(sessionId: string, updates: Partial<Session>): void;
  querySession(filter: SessionFilter): Session[];
  
  // Template operations
  storeTemplate(template: Template): void;
  updateTemplate(templateId: string, updates: Partial<Template>): void;
  queryTemplates(filter: TemplateFilter): Template[];
  
  // Export/Import operations
  exportDatabase(path: string): ExportResult;
  importDatabase(path: string, strategy: 'merge' | 'replace'): ImportResult;
  
  // Database management
  close(): void;
}
