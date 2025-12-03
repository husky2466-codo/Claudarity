---
description: Load relevant context from Claudarity into current session
tags: [memory, context, auto-recall]
---

You are loading relevant context from the Claudarity memory system into the current session.

**Instructions:**

1. Run the auto-context-recall script to analyze the current project state and query Claudarity:
   ```bash
   $HOME/.claude/scripts/auto-context-recall.sh "$PWD"
   ```

2. Read the generated session context file:
   ```bash
   cat ~/.claude/session-context.md
   ```

3. Present the context to the user:
   - Show what project state was analyzed (branch, recent files, commits)
   - Display the relevant past experiences found
   - Highlight key takeaways from wins (what worked)
   - Note any losses (what to avoid)
   - Provide actionable recommendations based on past learnings

4. Inform the user that this context is now loaded for the session and will inform your responses.

5. If the user provided additional search terms in `{{prompt}}`, run a supplementary manual search:
   ```bash
   $HOME/.claude/hooks/context-search.sh "{{prompt}}" 3
   ```
   And append any additional findings to the context.

**What This Does:**
- Automatically analyzes your current git branch, recent files, and commit messages
- Searches Claudarity database for similar past work
- Generates a session context file at `~/.claude/session-context.md`
- Loads that context into the current conversation
- Makes past learnings immediately available to inform current work

**Output Format:**
1. Brief summary of what was analyzed
2. Number of relevant past experiences found
3. Key recommendations based on those experiences
4. Confirmation that context is loaded for the session
