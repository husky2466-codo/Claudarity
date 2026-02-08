/**
 * Example: Using Memory Store with Platform Abstraction
 * 
 * This example demonstrates how to use the platform abstraction layer
 * to get the appropriate database path and initialize the Memory Store.
 */

import { PlatformAbstractionImpl } from '../src/platform';
import { MemoryStoreImpl } from '../src/database';
import * as path from 'path';

// Initialize platform abstraction
const platform = new PlatformAbstractionImpl();

// Get platform-appropriate data directory
const dataDir = platform.getDataDir();
console.log(`Data directory: ${dataDir}`);

// Construct database path using platform abstraction
const dbPath = platform.joinPath(dataDir, 'claudarity', 'memory.db');
console.log(`Database path: ${dbPath}`);

// Ensure the directory exists
await platform.createDirectory(platform.joinPath(dataDir, 'claudarity'));

// Initialize Memory Store with platform-appropriate path
const memoryStore = new MemoryStoreImpl(dbPath);

// Example: Create a session
const sessionId = `session-${Date.now()}`;
memoryStore.createSession({
  id: sessionId,
  start_time: Date.now(),
  project_path: process.cwd(),
});

console.log(`Created session: ${sessionId}`);

// Example: Store feedback
memoryStore.storeFeedback({
  id: `feedback-${Date.now()}`,
  session_id: sessionId,
  timestamp: Date.now(),
  feedback_type: 'positive',
  confidence: 0.9,
  text_content: 'looks good',
  code_snippet: 'const x = 1;',
});

console.log('Stored feedback');

// Example: Query feedback
const feedback = memoryStore.queryFeedback({ session_id: sessionId });
console.log(`Retrieved ${feedback.length} feedback entries`);

// Example: Store a preference
memoryStore.storePreference({
  id: `pref-${Date.now()}`,
  category: 'error_handling',
  preference_key: 'use_early_returns',
  preference_value: 'true',
  confidence: 0.85,
  last_updated: Date.now(),
});

console.log('Stored preference');

// Example: Query preferences
const preferences = memoryStore.queryPreferences({
  category: 'error_handling',
  min_confidence: 0.8,
});
console.log(`Retrieved ${preferences.length} high-confidence preferences`);

// Clean up
memoryStore.close();
console.log('Memory Store closed');
