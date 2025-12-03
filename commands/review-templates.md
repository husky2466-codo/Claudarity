---
description: Review template evolution proposals and system health
runOn: user
---

Provide a comprehensive review of the template system:

1. **Run template-evolver.py** to generate latest evolution proposals:
   ```bash
   ~/.claude/scripts/template-evolver.py
   ```

2. **Calculate confidence scores** for all templates:
   ```bash
   ~/.claude/scripts/confidence-calculator.sh
   ```

3. **Display comprehensive statistics**:
   ```bash
   ~/.claude/scripts/template-stats.sh
   ```

4. **Review pending proposals** and provide recommendations:
   - Read `/Volumes/DevDrive/Cache/templates/evolved/evolution-proposals.json`
   - For each pending proposal, analyze:
     - Template win rate and confidence
     - Adoption rates of proposed changes
     - Rationale and metrics
   - Recommend which proposals to apply

5. **Provide insights** on:
   - Which templates are performing best
   - Which templates need improvement
   - Trends in template usage
   - Recommended next actions

Present findings in a clear, organized format with actionable recommendations.
