---
allowed-tools: Bash(find:*), Bash(wc:*), Bash(ls:*), Bash(cat:*)
description: Show overview of optimization issue status across all categories
---

## System Status Overview

Display comprehensive status of the optimization system:

```bash
echo "OPTIMIZATION SYSTEM STATUS"
echo "=========================="
echo ""

PENDING=$(find .claude/optimize/pending -name "*.json" 2>/dev/null | wc -l)
BACKLOG=$(find .claude/optimize/backlog -name "*.json" 2>/dev/null | wc -l) 
COMPLETED=$(find .claude/optimize/completed -name "*.json" 2>/dev/null | wc -l)
DECISIONS=$(find .claude/optimize/decisions -name "*.md" 2>/dev/null | wc -l)

echo "📋 PENDING: ${PENDING} issues waiting for review"
echo "⏸️  DEFERRED: ${BACKLOG} issues in backlog"
echo "✅ COMPLETED: ${COMPLETED} issues implemented/skipped"
echo "📝 DECISIONS: ${DECISIONS} review sessions recorded"
echo ""

echo "RECENT ACTIVITY:"
echo "==============="
if [ -d .claude/optimize/reports ]; then
    echo "Latest reports:"
    ls -t .claude/optimize/reports/*.md 2>/dev/null | head -3
fi
echo ""

if [ -d .claude/optimize/decisions ]; then
    echo "Recent decisions:"
    ls -t .claude/optimize/decisions/*.md 2>/dev/null | head -3
fi
echo ""

if [ ${PENDING} -gt 0 ]; then
    echo "🚀 NEXT STEPS: Run '/optimize-review' to process pending issues"
elif [ ${BACKLOG} -gt 0 ]; then
    echo "🚀 NEXT STEPS: Run '/optimize' to include backlog issues in analysis, or '/optimize-gh-migrate' to convert backlog to GitHub issues"  
else
    echo "🚀 NEXT STEPS: Run '/optimize' to analyze recent changes"
fi
echo ""

echo "QUICK COMMANDS:"
echo "- Analyze changes: /optimize"
echo "- Review issues: /optimize-review"  
echo "- Migrate backlog: /optimize-gh-migrate"
echo "- Execute pending: bash .claude/optimize/pending/commands.sh"
echo "- Safe cleanup: See OPTIMIZE_SYSTEM.md for maintenance commands"
```
