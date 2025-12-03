---
description: Structure and refine a query for approval before execution
arguments:
  - name: query
    description: The raw query to structure
    required: true
---

Use the Task tool with `subagent_type='prompt-structurer'` to transform the following query into a well-structured prompt with clear role, task, constraints, and output format.

After receiving the structured prompt, present it to me for review. I will then use `/sab` to execute it once approved.

**Raw Query:**
$ARGUMENTS
