---
allowed-tools: Bash(cat:*), Bash(jq:*), Bash(gh:*), Bash(echo:*), Bash(mv:*)
description: Convert deferred issues from backlog to GitHub issues for project management
---

## Load Deferred Issues

Check for and display backlogged optimization issues:

```bash
if [ -f .claude/optimize/backlog/deferred_issues.json ]; then
    DEFERRED_COUNT=$(jq '. | length' .claude/optimize/backlog/deferred_issues.json)
    echo "Found ${DEFERRED_COUNT} deferred issues in backlog"
    echo ""
    echo "DEFERRED ISSUES:"
    echo "==============="
    jq -r '.[] | "#\(.id) [\(.priority)] \(.title)"' .claude/optimize/backlog/deferred_issues.json
    echo ""
else
    echo "❌ No deferred issues found in backlog."
    echo "Run '/optimize' and '/optimize-review' to create deferred issues first."
    exit 1
fi
```

## Migration Options

Present available GitHub migration commands:

```bash
echo "GITHUB MIGRATION OPTIONS:"
echo "========================"
echo ""
echo "Convert specific issues:"
echo "- 'Convert #2, #4' (convert specific deferred issues)"
echo "- 'Convert #2 --comment=\"High priority for next sprint\"'"
echo ""
echo "Batch operations:"
echo "- 'Convert all' (convert all deferred issues)"
echo "- 'Convert all high' (convert all high-priority deferred issues)"
echo "- 'Convert all critical' (convert all critical-priority deferred issues)"
echo ""
echo "Enter your selection:"
```

## Process Migration

Execute GitHub issue creation based on user selection:

```bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
USER_INPUT="[USER_SELECTION]"

echo "Processing GitHub issue creation..."

if [[ "$USER_INPUT" == *"Convert all"* ]]; then
    echo "Converting all deferred issues to GitHub..."
    
    jq -c '.[]' .claude/optimize/backlog/deferred_issues.json | while read issue; do
        TITLE=$(echo $issue | jq -r '.title')
        DESCRIPTION=$(echo $issue | jq -r '.description')
        PRIORITY=$(echo $issue | jq -r '.priority')
        CATEGORY=$(echo $issue | jq -r '.category')
        
        gh issue create \
            --title="[OPTIMIZATION] ${TITLE}" \
            --body="Priority: ${PRIORITY}
Category: ${CATEGORY}
Description: ${DESCRIPTION}

Generated from deferred optimization issues on ${TIMESTAMP}
Original optimization session: $(echo $issue | jq -r '.session_id // "unknown"')" \
            --label="optimization,deferred,${PRIORITY,,}-priority,${CATEGORY,,}"
        
        echo "✓ Created GitHub issue: ${TITLE}"
    done
    
    mv .claude/optimize/backlog/deferred_issues.json .claude/optimize/completed/converted_to_github_${TIMESTAMP}.json
    echo "✓ Deferred issues archived as converted to GitHub"
    
else
    echo "Processing individual issue conversions..."
fi

echo "GitHub Migration: [CONVERTED_ISSUES]" > .claude/optimize/decisions/github_migration_${TIMESTAMP}.md
echo "Timestamp: ${TIMESTAMP}" >> .claude/optimize/decisions/github_migration_${TIMESTAMP}.md
echo "Issues Converted: [CONVERTED_COUNT]" >> .claude/optimize/decisions/github_migration_${TIMESTAMP}.md
echo "Command: ${USER_INPUT}" >> .claude/optimize/decisions/github_migration_${TIMESTAMP}.md

echo ""
echo "✅ GitHub migration completed successfully!"
echo "Converted issues are now available in your GitHub repository."
echo "Deferred issues backlog has been cleared."
echo "Status: BACKLOG MIGRATED TO GITHUB"
```
