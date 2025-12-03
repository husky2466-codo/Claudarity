---
description: Query learned code preferences before making decisions
---

Before implementing the user's request, check learned code preferences to align with their past feedback.

Run the query tool to check preferences:

```bash
$HOME/.claude/scripts/query-preferences.sh
```

Or query specific items:

```bash
# Query a technology
$HOME/.claude/scripts/query-preferences.sh query tech "SwiftUI"

# Query a pattern
$HOME/.claude/scripts/query-preferences.sh query pattern "hook"

# Query a tool
$HOME/.claude/scripts/query-preferences.sh query tool "Edit"
```

Use this information to inform your implementation approach. If something has a high win rate, favor that approach. If something has been avoided, mention why you're avoiding it or seek clarification before using it.

The preferences show:
- Preferred vs avoided technologies
- Liked vs disliked patterns
- Preferred vs avoided tools
- Confidence scores (higher = more data backing the preference)
- Win rates (percentage of positive outcomes)

After checking preferences, proceed with the implementation that aligns with learned patterns.
