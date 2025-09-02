---
allowed-tools: Bash(cat:*), Bash(echo:*), Bash(grep:*), Bash(mv:*), Bash(cp:*)
description: Process user decisions on optimization issues and generate implementation commands
---

## Load Pending Issues

Check for pending issues and backlog integration:

```bash
if [ -f .claude/optimize/pending/issues.json ]; then
    echo "Loading pending issues..."
    echo "Found issues ready for review"
    
    if [ -f .claude/optimize/backlog/deferred_issues.json ]; then
        echo "Also found deferred issues from previous sessions"
    fi
else
    echo "❌ No pending issues found. Run '/optimize' first."
    exit 1
fi
```

## Display Issues for Review

Present all available optimization opportunities:

```bash
echo "OPTIMIZATION ISSUES - Ready for Review:"
echo ""
echo "REFACTORING:"
echo "#1 [HIGH] Database connection pooling optimization"
echo "#2 [MED]  Complex conditional logic in user validation"
echo ""
echo "ARCHITECTURE:"  
echo "#3 [HIGH] API endpoints not following REST conventions"
echo "#4 [LOW]  Missing error handling patterns documentation"
echo ""
echo "TESTING:"
echo "#5 [HIGH] Test updates needed before database connection refactoring"
echo "#6 [MED]  Missing unit tests for new validation logic"
echo "#7 [HIGH] Integration tests will break with API endpoint changes"
echo ""
echo "SECURITY:"
echo "#8 [CRITICAL] Hardcoded API keys in configuration files"  
echo "#9 [HIGH] Missing input sanitization in user endpoints"
echo "#10 [MED] Insufficient authentication token validation"
echo ""
echo "DECISION COMMANDS:"
echo ""
echo "Individual:"
echo "- 'Implement #1, #3, #8'"  
echo "- 'Defer #2, #4, #7 --comment=\"After v2.0 release\"'"
echo "- 'gh-issue #5, #9 --comment=\"For sprint planning\"'"
echo "- 'Skip #6, #10 --comment=\"Not needed for current scope\"'"
echo "- 'Details #5' (show more information)"
echo ""
echo "Batch Operations:"
echo "- 'Skip all' (dismiss all issues)"
echo "- 'Implement all' (implement everything)"  
echo "- 'Defer all' (move everything to backlog)"
echo "- 'gh-issue all' (create GitHub issues for everything)"
echo ""
echo "Mixed:"
echo "- 'Implement all critical, gh-issue all high, Defer the rest'"
echo "- 'Skip all low, Implement #1, #8, gh-issue #3, #5'"
echo ""
echo "Enter your selection:"
```

## Process User Input with Parsing Logic

Parse user selection and execute batch or individual commands:

```bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "Processing user selection..."

echo "Generated Commands - ${TIMESTAMP}" > .claude/optimize/pending/commands.sh
echo "Execute with: bash .claude/optimize/pending/commands.sh" >> .claude/optimize/pending/commands.sh
echo "" >> .claude/optimize/pending/commands.sh

USER_INPUT="[USER_SELECTION]"

if [[ "$USER_INPUT" == *"Skip all"* ]]; then
    echo "Batch operation: Skipping all issues"
    echo "Moving all issues to skipped..."
    
elif [[ "$USER_INPUT" == *"Implement all"* ]]; then
    echo "Batch operation: Implementing all issues"
    
elif [[ "$USER_INPUT" == *"Defer all"* ]]; then
    echo "Batch operation: Deferring all issues"  

elif [[ "$USER_INPUT" == *"gh-issue all"* ]]; then
    echo "Batch operation: Creating GitHub issues for all"
    
else
    echo "Processing individual selections..."
fi

echo "Command parsing completed."
```

## Generate Implementation Commands

Generate implementation commands with test-first approach and GitHub integration:

```bash
echo "Test Impact Analysis and Updates" >> .claude/optimize/pending/commands.sh
echo "@test-automation-engineer analyze-test-impact --issues='[IMPLEMENTED_ISSUES]' --generate-test-plan" >> .claude/optimize/pending/commands.sh
echo "@test-automation-engineer update-tests --test-plan='impact-analysis.md' --validate-before-refactor" >> .claude/optimize/pending/commands.sh
echo "" >> .claude/optimize/pending/commands.sh

echo "Implementation with Test Safety" >> .claude/optimize/pending/commands.sh  
echo "@code-reviewer fix issue-#1 --file=src/database.py --comment='Focus on connection pooling' --test-guided" >> .claude/optimize/pending/commands.sh
echo "@security-auditor fix issue-#8 --priority=critical --comment='Remove hardcoded keys, use environment variables' --preserve-tests" >> .claude/optimize/pending/commands.sh
echo "" >> .claude/optimize/pending/commands.sh

echo "GitHub Issue Creation" >> .claude/optimize/pending/commands.sh
echo "gh issue create --title='[OPTIMIZATION] Test updates for database refactoring' --body='Priority: HIGH\nCategory: TESTING\nDescription: Test updates needed before database connection refactoring\nGenerated from optimization session ${TIMESTAMP}' --label='optimization,testing,high-priority'" >> .claude/optimize/pending/commands.sh
echo "gh issue create --title='[OPTIMIZATION] Input sanitization improvements' --body='Priority: HIGH\nCategory: SECURITY\nDescription: Missing input sanitization in user endpoints\nGenerated from optimization session ${TIMESTAMP}' --label='optimization,security,high-priority'" >> .claude/optimize/pending/commands.sh
echo "" >> .claude/optimize/pending/commands.sh

echo "Validation and Documentation" >> .claude/optimize/pending/commands.sh
echo "pytest -xvs --tb=short || { echo '❌ Tests failed - refactoring stopped'; exit 1; }" >> .claude/optimize/pending/commands.sh
echo "@project-scribe document optimization-session --issues='[IMPLEMENTED_ISSUES]' --github-issues='[GITHUB_ISSUES]' --decisions='.claude/optimize/decisions/review_${TIMESTAMP}.md' --summary='Test-driven optimization session with GitHub integration'" >> .claude/optimize/pending/commands.sh

echo "User Selection: [SELECTED_ISSUES]" > .claude/optimize/decisions/review_${TIMESTAMP}.md
echo "Comments: [USER_COMMENTS]" >> .claude/optimize/decisions/review_${TIMESTAMP}.md
echo "Test Strategy: Test-First TDD approach" >> .claude/optimize/decisions/review_${TIMESTAMP}.md
echo "" >> .claude/optimize/decisions/review_${TIMESTAMP}.md
echo "Issue Distribution:" >> .claude/optimize/decisions/review_${TIMESTAMP}.md
echo "- Implemented: [IMPLEMENT_COUNT] issues" >> .claude/optimize/decisions/review_${TIMESTAMP}.md
echo "- GitHub Issues: [GITHUB_COUNT] issues → created in repository" >> .claude/optimize/decisions/review_${TIMESTAMP}.md
echo "- Deferred: [DEFER_COUNT] issues → backlog" >> .claude/optimize/decisions/review_${TIMESTAMP}.md  
echo "- Skipped: [SKIP_COUNT] issues → permanently dismissed" >> .claude/optimize/decisions/review_${TIMESTAMP}.md

echo "Moving selected issues to appropriate folders..."
echo "✓ Implemented issues → .claude/optimize/pending/commands.sh"
echo "✓ GitHub issues → created via gh CLI commands"
echo "✓ Deferred issues → .claude/optimize/backlog/deferred_issues.json"
echo "✓ Skipped issues → .claude/optimize/completed/skipped_issues.json"

echo ""
echo "✅ Review processed. Commands ready with test-first approach and GitHub integration:"
echo "Execute: bash .claude/optimize/pending/commands.sh"
echo "Status: READY FOR TEST-DRIVEN IMPLEMENTATION + GITHUB ISSUE CREATION"
```
