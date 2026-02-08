# Implementation Plan: Claudarity Modernization for Kiro

## Overview

This implementation plan converts the Claudarity modernization design into actionable coding tasks. The approach follows a layered architecture: Platform Abstraction → Data Layer → Core Logic → Integration Layer. Each task builds incrementally, with testing integrated throughout to catch errors early.

**Build Location**: All implementation will be in the `Claudarity-2.0/` directory at the workspace root.

## Tasks

- [x] 1. Set up project structure and platform abstraction layer
  - Create TypeScript project in `Claudarity-2.0/` with tsconfig, package.json, and directory structure
  - Implement Platform Abstraction interface for OS detection, path operations, and shell execution
  - Support Windows (PowerShell), macOS (bash/zsh), and Linux (bash)
  - _Requirements: 1.1, 1.2, 1.3, 1.5, 1.6_

- [x] 1.1 Write property test for platform detection
  - **Property 1: Platform Detection and Configuration**
  - **Validates: Requirements 1.1, 1.2, 1.3**

- [x] 1.2 Write property test for path portability
  - **Property 2: Path Portability**
  - **Validates: Requirements 1.4, 1.5**

- [-] 2. Implement database schema and Memory Store
  - [x] 2.1 Create SQLite database schema with all required tables
    - Implement feedback_log, context_memory, code_preferences, session_log, template_evolution, template_history, terminal_activity, schema_version tables
    - Add indexes for common queries
    - _Requirements: 4.1_

  - [x] 2.2 Implement Memory Store interface with CRUD operations
    - Implement storeFeedback, queryFeedback, storeContext, queryContext, storePreference, queryPreferences
    - Implement createSession, updateSession, querySession
    - Implement storeTemplate, updateTemplate, queryTemplates
    - Use platform abstraction for database path
    - _Requirements: 4.2, 4.3_

  - [x] 2.3 Write property test for database initialization
    - **Property 25: Database Initialization**
    - **Validates: Requirements 4.3**

  - [x] 2.4 Write property test for configurable database location
    - **Property 26: Configurable Database Location**
    - **Validates: Requirements 4.2**

  - [x] 2.5 Implement database migration system
    - Create migration framework that applies migrations sequentially
    - Implement version tracking and rollback on failure
    - _Requirements: 4.7_

  - [x] 2.6 Write property test for database migration
    - **Property 30: Database Migration**
    - **Validates: Requirements 4.7**

  - [x] 2.7 Implement export and import functionality
    - Create exportDatabase function that creates portable backup
    - Create importDatabase function with merge and replace strategies
    - Validate schema compatibility on import
    - _Requirements: 4.4, 4.5, 4.6_

  - [ ] 2.8 Write property tests for export/import
    - **Property 27: Export Creates Valid Backup**
    - **Property 28: Import Merges or Replaces**
    - **Property 29: Schema Compatibility Validation**
    - **Validates: Requirements 4.4, 4.5, 4.6**

- [ ] 3. Checkpoint - Ensure database layer tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 4. Implement configuration management
  - [ ] 4.1 Create configuration schema and default values
    - Define configuration interface with learning, context, feedback, templates, storage, features, logging sections
    - Implement default configuration values
    - _Requirements: 14.2, 14.3, 14.4_

  - [ ] 4.2 Implement configuration file reading and validation
    - Read YAML/JSON from .kiro/claudarity/config
    - Validate configuration on startup
    - Use safe defaults for invalid values
    - _Requirements: 14.1, 14.5, 14.7_

  - [ ] 4.3 Write property tests for configuration
    - **Property 54: Configuration File Reading**
    - **Property 55: Complete Configuration Support**
    - **Property 56: Invalid Configuration Handling**
    - **Property 57: Configuration Validation on Startup**
    - **Validates: Requirements 14.1, 14.2, 14.3, 14.4, 14.5, 14.7**

  - [ ] 4.4 Implement configuration generation command
    - Create command to generate default config file
    - _Requirements: 14.6_

- [ ] 5. Implement Pattern Matcher for feedback detection
  - [ ] 5.1 Create Pattern interface and pattern library
    - Define Pattern interface with id, type, keywords, contextRequirements, weight
    - Create initial pattern library with common positive/negative feedback phrases
    - _Requirements: 3.1, 3.2_

  - [ ] 5.2 Implement pattern matching algorithm
    - Implement keyword matching for fast filtering
    - Implement contextual analysis for implicit feedback
    - Implement confidence scoring combining multiple signals
    - _Requirements: 3.1, 3.2_

  - [ ] 5.3 Write property test for feedback classification
    - **Property 12: Feedback Classification**
    - **Validates: Requirements 3.1, 3.2**

- [ ] 6. Implement Feedback Detector
  - [ ] 6.1 Create Feedback Detector using Pattern Matcher
    - Implement detectFeedback function that analyzes text
    - Implement extractContext function that extracts code snippets, file paths, etc.
    - Implement getConfidence function
    - _Requirements: 3.1, 3.2, 3.4_

  - [ ] 6.2 Write property test for context extraction
    - **Property 13: Context Extraction from Feedback**
    - **Validates: Requirements 3.4**

  - [ ] 6.3 Write unit test for F1 score validation
    - Create labeled test dataset with 500+ examples
    - Validate F1 score >90% on test dataset
    - _Requirements: 3.3_

  - [ ] 6.4 Implement ambiguous feedback handling
    - Handle feedback with confidence below threshold
    - Use lower confidence weights for ambiguous feedback
    - _Requirements: 3.7_

- [ ] 7. Implement Multi-Armed Bandit algorithm
  - [ ] 7.1 Create Multi-Armed Bandit interface with Thompson Sampling
    - Implement Arm interface with alpha and beta parameters
    - Implement selectArm using Thompson Sampling (sample from Beta distribution)
    - Implement updateArm to increment alpha (positive) or beta (negative)
    - Implement getArmStats to calculate success rates
    - _Requirements: 8.1, 8.2_

  - [ ] 7.2 Write property test for exploration-exploitation balance
    - **Property 16: Exploration-Exploitation Balance**
    - **Validates: Requirements 8.2**

  - [ ] 7.3 Write property test for adaptive exploration
    - **Property 19: Adaptive Exploration**
    - **Validates: Requirements 8.7**

- [ ] 8. Implement Learning Engine
  - [ ] 8.1 Create Learning Engine using Multi-Armed Bandit
    - Implement updateScores function that updates alpha/beta based on feedback
    - Implement selectPattern function using Thompson Sampling
    - Implement getConfidence function with mean, variance, confidence intervals
    - Implement getMetrics function for success rates
    - _Requirements: 3.5, 8.3, 8.4, 8.5, 8.6, 8.7_

  - [ ] 8.2 Write property tests for learning engine
    - **Property 15: Multi-Armed Bandit Score Updates**
    - **Property 17: Confidence Score Maintenance**
    - **Property 18: Success Rate Tracking**
    - **Validates: Requirements 3.5, 8.3, 8.4, 8.5, 8.6**

  - [ ] 8.3 Implement confidence score persistence
    - Persist score updates to Memory Store after each feedback
    - _Requirements: 3.6_

  - [ ] 8.4 Write property test for confidence score persistence
    - **Property 14: Confidence Score Persistence**
    - **Validates: Requirements 3.6**

- [ ] 9. Checkpoint - Ensure learning components tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 10. Implement Template Evolver
  - [ ] 10.1 Create Template interface and template library
    - Define Template interface with id, category, pattern, confidence, alpha, beta, usageCount, lastUsed, archived
    - Support categories: error_handling, naming, structure, testing
    - _Requirements: 5.3, 5.5_

  - [ ] 10.2 Implement template weight updates
    - Implement updateTemplate function that adjusts alpha/beta based on feedback
    - Calculate confidence as alpha / (alpha + beta)
    - _Requirements: 5.1, 5.2_

  - [ ] 10.3 Write property test for template weight adjustment
    - **Property 20: Template Weight Adjustment**
    - **Property 21: Template Confidence Maintenance**
    - **Validates: Requirements 5.1, 5.2, 5.3**

  - [ ] 10.4 Implement template prioritization and archiving
    - Implement getTemplates function that orders by confidence
    - Implement archiveTemplates function for low-confidence templates
    - _Requirements: 5.4, 5.6_

  - [ ] 10.5 Write property tests for template operations
    - **Property 22: Template Prioritization**
    - **Property 23: Template Archiving**
    - **Validates: Requirements 5.4, 5.6**

  - [ ] 10.6 Implement template evolution history tracking
    - Record before/after confidence and feedback type in template_history table
    - Implement getEvolutionHistory function
    - _Requirements: 5.7_

  - [ ] 10.7 Write property test for template evolution history
    - **Property 24: Template Evolution History**
    - **Validates: Requirements 5.7**

- [ ] 11. Implement Context Injector
  - [ ] 11.1 Create context relevance scoring algorithm
    - Implement relevance formula: 0.4*recency + 0.3*confidence + 0.3*similarity
    - Implement recency scoring with exponential decay
    - Implement semantic similarity (cosine similarity or simple keyword matching)
    - _Requirements: 6.2, 2.7_

  - [ ] 11.2 Write property test for context prioritization
    - **Property 9: Context Prioritization**
    - **Validates: Requirements 2.7, 6.2**

  - [ ] 11.3 Implement context query and ranking
    - Implement queryRelevantContext function that queries Memory Store
    - Implement rankContext function using relevance scoring
    - Query on session start
    - _Requirements: 6.1, 6.2_

  - [ ] 11.4 Write property test for session start context query
    - **Property 31: Session Start Context Query**
    - **Validates: Requirements 6.1**

  - [ ] 11.4 Implement steering file generation
    - Implement formatSteeringFile function that creates Markdown
    - Include code preferences, recent patterns, related solutions
    - Organize by context type (preferences, patterns, recent-context)
    - Track which context was used
    - _Requirements: 2.2, 2.4, 6.3, 6.4, 6.5_

  - [ ] 11.5 Write property tests for steering file format
    - **Property 5: Valid Markdown Format**
    - **Property 6: Context Organization by Type**
    - **Property 32: Context Content Inclusion**
    - **Property 33: Context Usage Tracking**
    - **Validates: Requirements 2.2, 2.4, 6.3, 6.4, 6.5**

  - [ ] 11.6 Implement steering file creation and limits
    - Implement injectContext function that writes steering files to .kiro/steering/
    - Enforce token limit (max 2000 tokens per file)
    - Enforce active file limit (max 3 files)
    - Don't create empty files when no relevant context
    - _Requirements: 2.1, 2.6, 6.6, 6.7_

  - [ ] 11.7 Write property tests for steering file constraints
    - **Property 4: Steering File Creation from Context**
    - **Property 8: Token Limit Enforcement**
    - **Property 10: Active Steering File Limit**
    - **Property 11: No Empty Steering Files**
    - **Validates: Requirements 2.1, 2.6, 6.6, 6.7**

  - [ ] 11.8 Implement steering file cleanup
    - Implement cleanupSteeringFiles function that removes outdated files
    - Use configured cleanup age threshold
    - _Requirements: 2.5_

  - [ ] 11.9 Write property test for steering file cleanup
    - **Property 7: Steering File Cleanup**
    - **Validates: Requirements 2.5**

  - [ ] 11.10 Implement Kiro memory deduplication
    - Check Kiro's CLAUDE.md and /memory for existing context
    - Avoid duplicating context in steering files
    - _Requirements: 7.1, 7.3_

  - [ ] 11.11 Write property test for deduplication
    - **Property 34: Kiro Memory Deduplication**
    - **Validates: Requirements 7.3**

- [ ] 12. Checkpoint - Ensure context injection tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 13. Implement Session Management
  - [ ] 13.1 Create session lifecycle management
    - Implement createSession on Kiro start
    - Track start_time, end_time, project_path, activity_summary, feedback_count, context_injections
    - Implement updateSession and session end handling
    - Associate feedback and context with session IDs
    - _Requirements: 15.1, 15.2, 15.3, 15.4_

  - [ ] 13.2 Write property tests for session management
    - **Property 58: Session Creation on Start**
    - **Property 59: Complete Session Tracking**
    - **Property 60: Session Data Persistence**
    - **Property 61: Feedback-Session Association**
    - **Validates: Requirements 15.1, 15.2, 15.3, 15.4**

  - [ ] 13.3 Implement session queries and boundary handling
    - Implement session history queries (recent, by project, by date)
    - Consider session boundaries in context relevance queries
    - Support manual session boundaries
    - _Requirements: 15.5, 15.6, 15.7_

  - [ ] 13.4 Write property tests for session queries
    - **Property 62: Session Boundary Consideration**
    - **Property 63: Manual Session Boundaries**
    - **Validates: Requirements 15.6, 15.7**

- [ ] 14. Implement privacy and security features
  - [ ] 14.1 Implement sensitive data detection and redaction
    - Create patterns for API keys, credentials, PII
    - Implement redaction in steering file generation
    - Ensure no external network calls
    - _Requirements: 9.2, 9.3, 9.4_

  - [ ] 14.2 Write property tests for privacy
    - **Property 36: Local-Only Storage**
    - **Property 37: No External Network Calls**
    - **Property 38: Sensitive Data Exclusion**
    - **Validates: Requirements 9.1, 9.2, 9.3, 9.4**

  - [ ] 14.3 Implement secure deletion
    - Implement deletion that removes all associated data
    - _Requirements: 9.6_

  - [ ] 14.4 Write property test for secure deletion
    - **Property 39: Secure Data Deletion**
    - **Validates: Requirements 9.6**

  - [ ] 14.5 Implement optional encryption (optional feature)
    - Implement encryption for sensitive fields using user-provided keys
    - _Requirements: 9.7_

  - [ ] 14.6 Write property test for optional encryption
    - **Property 40: Optional Encryption**
    - **Validates: Requirements 9.7**

- [ ] 15. Implement error handling and logging
  - [ ] 15.1 Create logging infrastructure
    - Implement log levels (DEBUG, INFO, WARN, ERROR)
    - Implement log formatting with timestamp, level, component, operation, context
    - Implement log rotation (max size, max files)
    - Write logs to configurable location
    - _Requirements: 12.1, 12.2, 12.3_

  - [ ] 15.2 Write property tests for logging
    - **Property 48: Error Logging with Context**
    - **Property 49: Configurable Log Location**
    - **Validates: Requirements 12.1, 12.3**

  - [ ] 15.3 Implement error recovery strategies
    - Implement retry logic for database operations (3 retries with exponential backoff)
    - Implement retry logic for file operations (2 retries)
    - Implement graceful degradation (continue without failed components)
    - Implement fallback behavior (use defaults when components fail)
    - _Requirements: 12.7_

  - [ ] 15.4 Write property test for database failure recovery
    - **Property 51: Database Failure Recovery**
    - **Validates: Requirements 12.7**

  - [ ] 15.5 Implement user notifications for critical errors
    - Implement notification through Kiro for background failures
    - _Requirements: 12.4_

  - [ ] 15.6 Write property test for background failure notification
    - **Property 50: Background Failure Notification**
    - **Validates: Requirements 12.4**

  - [ ] 15.7 Implement health check and diagnostics
    - Implement healthCheck function that verifies all components
    - Implement diagnostic commands to inspect system state
    - _Requirements: 12.5, 12.6_

- [ ] 16. Implement MCP Server
  - [ ] 16.1 Create MCP server infrastructure
    - Set up MCP server with tool registration
    - Implement structured response format
    - _Requirements: 13.1, 13.7_

  - [ ] 16.2 Implement memory query tools
    - Implement queryMemory tool with filters (contextType, filePattern, timeRange, limit)
    - _Requirements: 13.2_

  - [ ] 16.3 Implement feedback management tools
    - Implement reviewFeedback tool
    - Implement correctFeedback tool
    - _Requirements: 13.3_

  - [ ] 16.4 Implement template inspection tools
    - Implement inspectTemplates tool with filters (category, minConfidence)
    - _Requirements: 13.4_

  - [ ] 16.5 Implement memory management tools
    - Implement exportMemory tool
    - Implement importMemory tool
    - _Requirements: 13.5_

  - [ ] 16.6 Implement steering file control tools
    - Implement refreshContext tool
    - Implement clearSteeringFiles tool
    - _Requirements: 13.6_

  - [ ] 16.7 Implement diagnostic tools
    - Implement healthCheck tool
    - Implement getConfig tool
    - _Requirements: 13.6_

  - [ ] 16.8 Write property tests for MCP server
    - **Property 52: Complete Tool Exposure**
    - **Property 53: Structured MCP Responses**
    - **Validates: Requirements 13.2, 13.3, 13.4, 13.5, 13.6, 13.7**

  - [ ] 16.9 Implement Kiro integration features
    - Respect Kiro's /memory command
    - Implement user preference priority for conflicts
    - _Requirements: 7.2, 7.6_

  - [ ] 16.10 Write property test for user preference priority
    - **Property 35: User Preference Priority**
    - **Validates: Requirements 7.6**

- [ ] 17. Checkpoint - Ensure MCP server tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 18. Implement migration from legacy system
  - [ ] 18.1 Create migration tool for legacy databases
    - Implement legacy database reader
    - Parse legacy schema and data
    - _Requirements: 11.1_

  - [ ] 18.2 Write property test for legacy database reading
    - **Property 41: Legacy Database Reading**
    - **Validates: Requirements 11.1**

  - [ ] 18.3 Implement configuration conversion
    - Convert bash hook configurations to steering file configurations
    - _Requirements: 11.2_

  - [ ] 18.4 Write property test for configuration conversion
    - **Property 42: Configuration Conversion**
    - **Validates: Requirements 11.2**

  - [ ] 18.5 Implement path format conversion
    - Convert hardcoded absolute paths to portable format
    - _Requirements: 11.3_

  - [ ] 18.6 Write property test for path format conversion
    - **Property 43: Path Format Conversion**
    - **Validates: Requirements 11.3**

  - [ ] 18.7 Implement migration error handling and validation
    - Log warnings and skip invalid entries
    - Validate migrated data integrity
    - Create migration report
    - _Requirements: 11.4, 11.5, 11.6_

  - [ ] 18.8 Write property tests for migration
    - **Property 44: Migration Error Handling**
    - **Property 45: Migration Data Integrity**
    - **Property 46: Migration Report Generation**
    - **Property 47: Migration Preserves Learning Data**
    - **Validates: Requirements 11.4, 11.5, 11.6, 11.7**

- [ ] 19. Integration and wiring
  - [ ] 19.1 Wire all components together
    - Create main application entry point
    - Initialize all components with configuration
    - Set up component dependencies and communication
    - Implement application lifecycle (startup, shutdown)
    - _Requirements: All_

  - [ ] 19.2 Create CLI interface for standalone usage
    - Implement commands for migration, export, import, health check
    - _Requirements: 11.1, 4.4, 4.5, 12.5_

  - [ ] 19.3 Write integration tests
    - Test end-to-end scenarios: fresh install, migration, export/import, multiple sessions
    - Test MCP integration through Kiro
    - Test error scenarios and recovery
    - _Requirements: All_

- [ ] 20. Cross-platform testing and validation
  - [ ] 20.1 Run cross-platform tests
    - Test on Windows 10/11 with PowerShell
    - Test on macOS 12+ with bash and zsh
    - Test on Ubuntu 20.04+ with bash
    - _Requirements: 1.1, 1.2, 1.3_

  - [ ] 20.2 Run performance benchmarks
    - Validate feedback detection <50ms
    - Validate context query <100ms
    - Validate steering file generation <200ms
    - Validate database migration <5s
    - _Requirements: 3.1, 6.1, 2.1, 4.7_

- [ ] 21. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- All tasks are required for comprehensive implementation
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- The implementation uses TypeScript for type safety and cross-platform compatibility
- SQLite is used for the database to ensure portability and local-only operation
