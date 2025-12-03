---
description: Audit current project - comprehensive development/progress phase analysis using subagents
argument-hint: "[focus-area]"
---

# Project Audit Command

Perform a comprehensive audit of the current project directory using parallel subagents to analyze different aspects of the codebase. Generate a detailed development/progress report.

**Optional Focus Area:** $ARGUMENTS (leave blank for full audit)

## Execution Strategy

Launch multiple subagents IN PARALLEL to maximize efficiency. Use the Task tool with these specialized agents:

### Phase 1: Parallel Discovery (Launch ALL simultaneously)

1. **Architecture Explorer** - Task tool with `subagent_type="Explore"`:
   - Analyze project structure and file organization
   - Identify main entry points, core modules, and architectural patterns
   - Map dependencies between components
   - Detect framework/library usage

2. **Code Quality Scanner** - Task tool with `subagent_type="Explore"`:
   - Count files by type, lines of code, complexity indicators
   - Find TODO/FIXME/HACK comments and technical debt markers
   - Identify dead code, unused imports, code smells
   - Check for consistent naming and coding patterns

3. **Testing & Documentation Auditor** - Task tool with `subagent_type="Explore"`:
   - Locate test files and assess test coverage structure
   - Find documentation (README, docs/, comments, JSDoc/docstrings)
   - Check for CI/CD configuration files
   - Identify missing documentation areas

4. **Dependency & Config Analyzer** - Task tool with `subagent_type="Explore"`:
   - Parse package.json, requirements.txt, Podfile, Gemfile, etc.
   - Check for outdated dependencies, security advisories
   - Analyze configuration files (env, yaml, json configs)
   - Identify environment-specific configurations

5. **Security Scanner** - Task tool with `subagent_type="security-vulnerability-scanner"`:
   - Scan for common vulnerabilities (hardcoded secrets, SQL injection, XSS)
   - Check authentication/authorization patterns
   - Review input validation and sanitization
   - Identify security misconfigurations

### Phase 2: Synthesis

After all agents complete, synthesize findings into a comprehensive report.

## Output Format

Generate the audit report in this exact markdown structure:

```markdown
# 🔍 Project Audit Report

**Project:** [Name from package.json/config or directory name]
**Audit Date:** [Current date]
**Audited Path:** [Working directory]

---

## 📊 Executive Summary

[2-3 sentence high-level assessment of project health and development phase]

**Development Phase:** [Alpha | Beta | MVP | Production-Ready | Maintenance | Legacy]
**Overall Health Score:** [1-10 with brief justification]

---

## 🏗️ Architecture Overview

### Project Structure
[Tree view or description of key directories]

### Technology Stack
- **Language(s):**
- **Framework(s):**
- **Database:**
- **Key Libraries:**

### Architectural Pattern
[MVC, MVVM, Clean Architecture, Monolith, Microservices, etc.]

### Component Map
[Key modules and their responsibilities]

---

## 📈 Code Metrics

| Metric | Value |
|--------|-------|
| Total Files | X |
| Lines of Code | ~X |
| Primary Language | X |
| File Types | .ts, .js, .swift, etc. |

### Complexity Indicators
- [Large files, deep nesting, cyclomatic complexity observations]

---

## ✅ Code Quality Assessment

### Strengths
- [List positive patterns found]

### Technical Debt
- [TODO count: X]
- [FIXME count: X]
- [Key debt areas identified]

### Code Smells Detected
- [List any problematic patterns]

---

## 🧪 Testing Status

| Test Type | Status | Coverage |
|-----------|--------|----------|
| Unit Tests | ✅/⚠️/❌ | X% / Unknown |
| Integration Tests | ✅/⚠️/❌ | - |
| E2E Tests | ✅/⚠️/❌ | - |

### Test Infrastructure
- [Test framework, CI integration status]

---

## 📚 Documentation Status

| Doc Type | Status |
|----------|--------|
| README | ✅/⚠️/❌ |
| API Docs | ✅/⚠️/❌ |
| Code Comments | ✅/⚠️/❌ |
| Architecture Docs | ✅/⚠️/❌ |

---

## 📦 Dependencies

### Summary
- **Total Dependencies:** X
- **Dev Dependencies:** X
- **Potentially Outdated:** X

### Key Dependencies
[List major frameworks/libraries with versions]

### Concerns
- [Any security advisories, deprecated packages]

---

## 🔒 Security Assessment

### Risk Level: [Low | Medium | High | Critical]

### Findings
- [List security observations]

### Recommendations
- [Priority security fixes needed]

---

## 🎯 Development Phase Analysis

### Current Phase: [Phase Name]

**Indicators:**
- [Evidence supporting phase classification]

### Phase Characteristics
| Aspect | Status |
|--------|--------|
| Core Features | Complete/In Progress/Planned |
| Error Handling | Robust/Basic/Missing |
| Performance Optimization | Done/Needed/N/A |
| Security Hardening | Done/Needed/N/A |
| Documentation | Complete/Partial/Missing |
| Test Coverage | High/Medium/Low/None |

---

## ⚠️ Risk Areas

1. **[Risk Name]** - [Severity: High/Medium/Low]
   - Description: [What the risk is]
   - Impact: [What could go wrong]
   - Mitigation: [How to address]

---

## 💡 Recommendations

### Immediate (Do Now)
1. [Critical items]

### Short-term (This Sprint)
1. [Important improvements]

### Long-term (Roadmap)
1. [Strategic improvements]

---

## 📋 Action Items

- [ ] [Specific actionable task]
- [ ] [Specific actionable task]
- [ ] [Specific actionable task]

---

*Generated by /audit command using Claude Code subagents*
```

## Instructions

1. Launch ALL Phase 1 subagents in a SINGLE message with multiple Task tool calls
2. Wait for all results
3. Synthesize findings into the report format above
4. Be specific - use actual file names, real counts, genuine observations
5. If a focus area was specified ($ARGUMENTS), emphasize that section while still providing full context
6. Adapt the report sections based on project type (web app vs library vs mobile app, etc.)
