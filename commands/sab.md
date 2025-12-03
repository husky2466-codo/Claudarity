---
description: Execute an approved/structured query using subagents
arguments:
  - name: query
    description: The approved query to execute (use /sa first to structure if needed)
    required: true
---

# Sub-Agent Execution

Execute the following task using subagents. Do NOT refine or restructure the query - it has already been approved. Just do the work.

## Execution Guidelines:

**Maximize parallelization:**
- Launch MULTIPLE Task tool calls in a SINGLE message to run agents concurrently
- Break work into independent subtasks that can run in parallel
- Only sequence tasks with true dependencies

**Choose the right subagents:**
- `Explore` - For codebase exploration, finding files, understanding architecture
- `general-purpose` - For complex multi-step coding tasks
- `refactorer` - For improving code structure without changing behavior
- `security-vulnerability-scanner` - For identifying security issues
- `web-researcher` - For gathering external information
- `Plan` - For planning complex implementations

**Example parallel execution:**
- Spawn multiple Explore agents to search different parts of the codebase simultaneously
- Run web-researcher alongside code exploration when external info is needed
- Launch security-vulnerability-scanner in parallel with implementation

## Task to Execute:
$ARGUMENTS
