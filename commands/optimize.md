---
allowed-tools: Bash(find:*), Bash(grep:*), Bash(git log:*), Bash(git diff:*), Bash(echo:*), Bash(mkdir:*)
description: Analyze code changes for quality, architecture alignment, and security issues
---

## Setup Context Management

Create the required directory structure for optimization tracking:

```bash
mkdir -p .claude/optimize/reports
mkdir -p .claude/optimize/pending
mkdir -p .claude/optimize/backlog
mkdir -p .claude/optimize/completed
mkdir -p .claude/optimize/decisions

echo "Optimization analysis started..."
```

## Context Analysis

Gather changes since last optimization:

```bash
git log --oneline -10
git diff --name-status HEAD~5..HEAD
git branch --show-current
find . -name "*.py" -not -path "./.git/*" | head -10
find . -name "*.js" -o -name "*.ts" -not -path "./.git/*" | head -10
find . -name "*.md" -o -name "*.yaml" -o -name "*.json" -not -path "./.git/*" | head -5
```

## Subagent Assignment for Analysis

1. **@code-reviewer**: Analyze code quality patterns, performance issues, and maintainability
2. **@database-architect**: Review data access patterns and database interactions  
3. **@python-backend-architect**: Check backend architecture alignment and API patterns
4. **@security-auditor**: Identify security implications and best practices
5. **@test-automation-engineer**: Analyze test coverage and identify test impact for potential changes
6. **@task-decomposer**: Structure findings into actionable tasks with test considerations

## Generate Issues JSON

Create structured issues file and report for the review phase:

```bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "Creating issues.json with analysis findings..."
echo "Issues ready for review in .claude/optimize/pending/issues.json"
echo "Report saved to .claude/optimize/reports/optimization_${TIMESTAMP}.md"
echo ""
echo "✅ Analysis complete. Run '/optimize-review' to make decisions."
echo "Status: WAITING FOR REVIEW"
```

## Report Structure Template

```markdown
# Optimization Report - ${TIMESTAMP}

## Executive Summary
- **Commit Range**: ${LAST_OPTIMIZE}..HEAD
- **Files Changed**: [Auto-filled]
- **Priority Issues Found**: [Count by category]

## Findings by Category

### 1. REFACTORING TASKS
**Issue #1**: [Title]
- **Priority**: High/Medium/Low
- **Description**: [Details]
- **Affected Files**: [List]
- **Recommended Action**: [Specific steps]
- **Assigned Subagent**: @code-reviewer

### 2. ARCHITECTURE UPDATES  
**Issue #2**: [Title]
- **Priority**: High/Medium/Low
- **Description**: [Alignment issues]
- **Documentation Impact**: [Files to update]
- **Recommended Action**: [Specific steps]
- **Assigned Subagent**: @python-backend-architect

### 3. TESTING REQUIREMENTS
**Issue #3**: [Title]
- **Priority**: High/Medium/Low
- **Description**: [Missing test coverage or test updates needed]
- **Test Impact**: [Existing tests affected by proposed changes]
- **Test Types Needed**: [Unit/Integration/E2E]
- **Recommended Action**: [Specific tests to write/update before implementation]
- **Assigned Subagent**: @test-automation-engineer

### 4. SECURITY ISSUES
**Issue #4**: [Title]
- **Priority**: Critical/High/Medium/Low
- **Security Impact**: [Data exposure/Authentication/Authorization/Input validation]
- **Vulnerability Type**: [OWASP category if applicable]
- **Affected Components**: [List]
- **Recommended Action**: [Specific security measures]
- **Assigned Subagent**: @security-auditor
```
