---
allowed-tools: Bash(cat:*), Bash(echo:*), Bash(grep:*), Bash(mv:*), Bash(cp:*)
description: Process user decisions on optimization issues and generate implementation commands
---

## Load Pending Issues

Check for pending issues and backlog integration with comprehensive error handling:

```bash
# Enable strict error handling
set -e  # Exit on any command failure
set -u  # Exit on undefined variables  
set -o pipefail  # Exit on pipe failures

# Function for cleanup on error
cleanup_on_error() {
    echo "❌ Operation failed. Cleaning up temporary files..."
    # Remove any partial files that might have been created
    rm -f ".claude/optimize/pending/commands.sh.tmp" 2>/dev/null || true
    rm -f ".claude/optimize/decisions/review_*.md.tmp" 2>/dev/null || true
    rm -f ".claude/optimize/backlog/deferred_issues_*.json.tmp" 2>/dev/null || true
    rm -f ".claude/optimize/completed/skipped_issues_*.json.tmp" 2>/dev/null || true
    exit 1
}

# Set up error trap
trap cleanup_on_error ERR

echo "Starting optimization review with safety validation..."

if [ -f .claude/optimize/pending/issues.json ]; then
    echo "Loading pending issues..."
    
    # Verify file is readable and has content
    if [ ! -r .claude/optimize/pending/issues.json ]; then
        echo "❌ Cannot read issues.json file - check permissions"
        exit 1
    fi
    
    if [ ! -s .claude/optimize/pending/issues.json ]; then
        echo "❌ Issues.json file is empty"
        echo "Please run '/optimize' to generate a valid issues file."
        exit 1
    fi
    
    # Check if the JSON has the expected structure with issues array
    if command -v jq >/dev/null 2>&1; then
        if ! jq -e '.issues' .claude/optimize/pending/issues.json >/dev/null 2>&1; then
            echo "❌ Invalid issues.json format - no 'issues' array found"
            echo "Please run '/optimize' to generate a valid issues file."
            exit 1
        fi
        
        if ! jq -e '.issues | length > 0' .claude/optimize/pending/issues.json >/dev/null 2>&1; then
            echo "❌ No issues found in issues.json"
            echo "Please run '/optimize' to generate optimization issues."
            exit 1
        fi
        echo "✓ JSON structure validated with jq"
    else
        # Fallback validation without jq
        if ! grep -q '"issues"' .claude/optimize/pending/issues.json; then
            echo "❌ Invalid issues.json format - no 'issues' array found"
            echo "Please run '/optimize' to generate a valid issues file."
            exit 1
        fi
        echo "⚠️  JSON validation limited (jq not available)"
    fi
    
    # Count issues from the nested structure - they're in the "issues" array
    if command -v jq >/dev/null 2>&1; then
        ISSUE_COUNT=$(jq '.issues | length' .claude/optimize/pending/issues.json 2>/dev/null || echo "0")
    else
        ISSUE_COUNT=$(grep -c '"id":' .claude/optimize/pending/issues.json 2>/dev/null || echo "0")
    fi
    
    # Validate issue count is reasonable
    if ! echo "$ISSUE_COUNT" | grep -qE '^[0-9]+$'; then
        echo "❌ Error: Could not determine issue count"
        exit 1
    fi
    
    if [ "$ISSUE_COUNT" -eq 0 ]; then
        echo "❌ No issues found in issues.json"
        echo "Please run '/optimize' to generate optimization issues."
        exit 1
    fi
    
    if [ "$ISSUE_COUNT" -gt 100 ]; then
        echo "⚠️  Warning: Very large number of issues ($ISSUE_COUNT)"
        echo "   This may indicate a parsing error or corrupted file"
        read -p "Continue anyway? (y/N): " -r confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            echo "Operation cancelled by user"
            exit 1
        fi
    fi
    
    echo "Found $ISSUE_COUNT issues ready for review"
    
    # Check for backlog issues with validation
    BACKLOG_COUNT=0
    if [ -d .claude/optimize/backlog ]; then
        # Count all deferred issue files in backlog
        BACKLOG_FILES=$(find .claude/optimize/backlog -name "deferred_issues*.json" -type f 2>/dev/null | wc -l)
        if [ "$BACKLOG_FILES" -gt 0 ]; then
            # Count total issues across all backlog files
            for backlog_file in .claude/optimize/backlog/deferred_issues*.json; do
                if [ -f "$backlog_file" ] && [ -r "$backlog_file" ] && [ -s "$backlog_file" ]; then
                    file_count=$(grep -c '"id":' "$backlog_file" 2>/dev/null || echo "0")
                    BACKLOG_COUNT=$((BACKLOG_COUNT + file_count))
                fi
            done
            if [ "$BACKLOG_COUNT" -gt 0 ]; then
                echo "Also found $BACKLOG_COUNT deferred issues from previous sessions"
            fi
        fi
    fi
else
    echo "❌ No pending issues found. Run '/optimize' first."
    exit 1
fi
```

## Display Issues for Review

Present all available optimization opportunities from the issues.json file:

```bash
echo "OPTIMIZATION ISSUES - Ready for Review:"
echo ""

# Extract and display issues properly from the nested JSON structure
jq -r '.issues[] | select(.priority == "CRITICAL") | "\(.id) [CRITICAL] \(.title)"' .claude/optimize/pending/issues.json 2>/dev/null || {
    echo "Parsing CRITICAL issues with fallback method..."
    grep -A 10 '"priority": "CRITICAL"' .claude/optimize/pending/issues.json | grep -E '"(id|title)":' | paste - - | sed 's/.*"id": "\([^"]*\)".*"title": "\([^"]*\)".*/\1 [CRITICAL] \2/'
}

jq -r '.issues[] | select(.priority == "HIGH") | "\(.id) [HIGH] \(.title)"' .claude/optimize/pending/issues.json 2>/dev/null || {
    echo "Parsing HIGH issues with fallback method..."
    grep -A 10 '"priority": "HIGH"' .claude/optimize/pending/issues.json | grep -E '"(id|title)":' | paste - - | sed 's/.*"id": "\([^"]*\)".*"title": "\([^"]*\)".*/\1 [HIGH] \2/'
}

jq -r '.issues[] | select(.priority == "MEDIUM") | "\(.id) [MEDIUM] \(.title)"' .claude/optimize/pending/issues.json 2>/dev/null || {
    echo "Parsing MEDIUM issues with fallback method..."
    grep -A 10 '"priority": "MEDIUM"' .claude/optimize/pending/issues.json | grep -E '"(id|title)":' | paste - - | sed 's/.*"id": "\([^"]*\)".*"title": "\([^"]*\)".*/\1 [MEDIUM] \2/'
}

jq -r '.issues[] | select(.priority == "LOW") | "\(.id) [LOW] \(.title)"' .claude/optimize/pending/issues.json 2>/dev/null || {
    echo "Parsing LOW issues with fallback method..."
    grep -A 10 '"priority": "LOW"' .claude/optimize/pending/issues.json | grep -E '"(id|title)":' | paste - - | sed 's/.*"id": "\([^"]*\)".*"title": "\([^"]*\)".*/\1 [LOW] \2/'
}

echo ""
echo "DECISION COMMANDS:"
echo ""
echo "Individual:"
echo "- 'Implement OPT-001, OPT-003, OPT-008'"  
echo "- 'Defer OPT-002, OPT-004 --comment=\"After v2.0 release\"'"
echo "- 'gh-issue OPT-005, OPT-009 --comment=\"For sprint planning\"'"
echo "- 'Skip OPT-006, OPT-010 --comment=\"Not needed for current scope\"'"
echo "- 'Details OPT-005' (show more information)"
echo ""
echo "Batch Operations:"
echo "- 'Skip all' (dismiss all issues)"
echo "- 'Implement all' (implement everything)"  
echo "- 'Defer all' (move everything to backlog)"
echo "- 'gh-issue all' (create GitHub issues for everything)"
echo ""
echo "Priority-based:"
echo "- 'Implement all critical' (implement all CRITICAL priority issues)"
echo "- 'Implement all high' (implement all HIGH priority issues)"
echo "- 'Implement all medium' (implement all MEDIUM priority issues)"
echo "- 'Implement all low' (implement all LOW priority issues)"
echo "- 'gh-issue all critical' (create GitHub issues for all CRITICAL priority)"
echo "- 'gh-issue all high' (create GitHub issues for all HIGH priority)" 
echo "- 'gh-issue all medium' (create GitHub issues for all MEDIUM priority)"
echo "- 'gh-issue all low' (create GitHub issues for all LOW priority)"
echo "- 'Defer all critical' (defer all CRITICAL priority to backlog)"
echo "- 'Defer all high' (defer all HIGH priority to backlog)"
echo "- 'Defer all medium' (defer all MEDIUM priority to backlog)"
echo "- 'Defer all low' (defer all LOW priority to backlog)"
echo ""
echo "Mixed Examples:"
echo "- 'Implement all critical, gh-issue all high, Defer all medium'"
echo "- 'Skip all low, Implement OPT-001, OPT-008, gh-issue OPT-003, OPT-005'"
echo ""
echo "Enter your selection:"
```

## Process User Input with Parsing Logic

Parse user selection and execute batch or individual commands with comprehensive safety checks:

```bash
# Safe timestamp generation with validation
if ! TIMESTAMP=$(date +%Y%m%d_%H%M%S 2>/dev/null); then
    echo "❌ Error: Cannot generate timestamp"
    exit 1
fi

# Validate timestamp format
if ! echo "$TIMESTAMP" | grep -qE '^[0-9]{8}_[0-9]{6}$'; then
    echo "❌ Error: Invalid timestamp format: $TIMESTAMP"
    exit 1
fi

echo "Processing user selection with timestamp: $TIMESTAMP"

# Function for safe directory creation
safe_mkdir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        if ! mkdir -p "$dir" 2>/dev/null; then
            echo "❌ Error: Failed to create directory $dir"
            echo "   Check permissions and disk space"
            return 1
        fi
        echo "✓ Created directory: $dir"
    else
        echo "✓ Directory exists: $dir"
    fi
}

# Create required directories safely
safe_mkdir ".claude/optimize/decisions"
safe_mkdir ".claude/optimize/backlog"  
safe_mkdir ".claude/optimize/completed"

# Create commands.sh with proper header and error handling using atomic operations
COMMANDS_TEMP_FILE=".claude/optimize/pending/commands.sh.tmp.$$"
COMMANDS_FINAL_FILE=".claude/optimize/pending/commands.sh"

# Backup existing commands file if it exists
if [ -f "$COMMANDS_FINAL_FILE" ]; then
    COMMANDS_BACKUP_FILE="${COMMANDS_FINAL_FILE}.backup.${TIMESTAMP}"
    if ! cp "$COMMANDS_FINAL_FILE" "$COMMANDS_BACKUP_FILE"; then
        echo "❌ Error: Failed to backup existing commands file"
        exit 1
    fi
    echo "✓ Backed up existing commands to: $COMMANDS_BACKUP_FILE"
fi

# Generate commands file atomically
{
    echo "#!/bin/bash"
    echo "# Generated Commands - ${TIMESTAMP}"
    echo "# Execute with: bash .claude/optimize/pending/commands.sh"
    echo ""
    echo "set -e  # Exit on any error"
    echo "set -u  # Exit on undefined variables"
    echo ""
    echo "# Comprehensive safety validation"
    echo "echo 'Validating environment before execution...'"
    echo ""
    echo "# Check for required files and directories"
    echo "if [ ! -f .claude/optimize/pending/issues.json ]; then"
    echo "    echo '❌ Required issues.json file not found'"
    echo "    exit 1"
    echo "fi"
    echo ""
    echo "if [ ! -r .claude/optimize/pending/issues.json ]; then"
    echo "    echo '❌ Issues file not readable'"
    echo "    exit 1"
    echo "fi"
    echo ""
    echo "if [ ! -s .claude/optimize/pending/issues.json ]; then"
    echo "    echo '❌ Issues file is empty'"
    echo "    exit 1"
    echo "fi"
    echo ""
    echo "# Validate JSON syntax if jq is available"
    echo "if command -v jq >/dev/null 2>&1; then"
    echo "    if ! jq empty .claude/optimize/pending/issues.json >/dev/null 2>&1; then"
    echo "        echo '❌ Issues file contains invalid JSON'"
    echo "        exit 1"
    echo "    fi"
    echo "    echo '✓ JSON validation passed'"
    echo "fi"
    echo ""
    echo "echo 'Starting optimization implementation session - ${TIMESTAMP}'"
    echo "echo 'Processing user selection: '\"\$(printf '%s' \"\$USER_INPUT\" | sed 's/[^a-zA-Z0-9 ,.\\\\-]/_/g')\"\''''
    echo ""
} > "$COMMANDS_TEMP_FILE"

# Validate the commands file was created successfully
if [ ! -f "$COMMANDS_TEMP_FILE" ] || [ ! -s "$COMMANDS_TEMP_FILE" ]; then
    echo "❌ Error: Failed to create commands file"
    rm -f "$COMMANDS_TEMP_FILE"
    exit 1
fi

# Make the temporary file executable
if ! chmod +x "$COMMANDS_TEMP_FILE"; then
    echo "❌ Error: Failed to make commands file executable"
    rm -f "$COMMANDS_TEMP_FILE"
    exit 1
fi

echo -n "Enter your selection: "
read -r USER_INPUT

# Comprehensive input validation and sanitization
echo "Validating user input..."

if [ -z "$USER_INPUT" ]; then
    echo "❌ No input provided. Operation cancelled."
    echo ""
    echo "Valid selection examples:"
    echo "  Individual: Implement OPT-001, OPT-003"
    echo "  Batch:      Defer all"
    echo "  GitHub:     gh-issue OPT-002"
    echo "  Dismiss:    Skip all"
    echo "  Mixed:      Implement OPT-001, gh-issue OPT-005, Skip OPT-010"
    exit 1
fi

# Critical security: Length check to prevent buffer overflow attacks
if [ ${#USER_INPUT} -gt 500 ]; then
    echo "❌ Input too long. Maximum 500 characters allowed."
    echo "   Received: ${#USER_INPUT} characters"
    exit 1
fi

# Critical security: Character whitelist validation
if ! printf '%s' "$USER_INPUT" | grep -qE '^[a-zA-Z0-9 ,.\"\\-]+$'; then
    echo "❌ Invalid characters detected in input."
    echo "   Only allowed: letters, numbers, spaces, commas, quotes, periods, hyphens"
    echo "   This prevents command injection attacks"
    exit 1
fi

# Additional security: Check for potential command injection patterns
DANGEROUS_PATTERNS=";\|\&\$\(\)\`\<\>\{\}"
if printf '%s' "$USER_INPUT" | grep -q "[$DANGEROUS_PATTERNS]"; then
    echo "❌ Security violation: Potentially dangerous characters detected"
    echo "   Input rejected to prevent command injection"
    exit 1
fi

echo "✓ Input validation passed: ${#USER_INPUT} characters, safe content"

USER_INPUT=$(printf '%s' "$USER_INPUT" | tr '[:lower:]' '[:upper:]')
echo "Normalized input: $USER_INPUT"

echo "Processing: $USER_INPUT"

SELECTED_ISSUES=""
USER_COMMENTS=""
OPERATION_TYPE="individual"
IMPLEMENT_COUNT=0
GITHUB_COUNT=0
DEFER_COUNT=0
SKIP_COUNT=0

# Safely extract comments using parameter expansion instead of regex
if [[ "$USER_INPUT" == *"--comment="* ]]; then
    # Extract comment between quotes safely
    temp_comment="${USER_INPUT#*--comment=\"}"
    USER_COMMENTS="${temp_comment%%\"*}"
    # Validate comment content
    if ! printf '%s' "$USER_COMMENTS" | grep -qE '^[a-zA-Z0-9 ,.\\-]*$'; then
        echo "❌ Invalid characters in comment. Only letters, numbers, spaces, commas, periods, and hyphens are allowed."
        exit 1
    fi
    echo "Found comment: $USER_COMMENTS"
fi

if [[ "$USER_INPUT" == *"SKIP ALL"* ]]; then
    echo "Batch operation: Skipping all issues"
    OPERATION_TYPE="skip_all"
    SKIP_COUNT=$(jq '.issues | length' .claude/optimize/pending/issues.json 2>/dev/null || grep -c '"id":' .claude/optimize/pending/issues.json)
    
elif [[ "$USER_INPUT" == *"IMPLEMENT ALL CRITICAL"* ]]; then
    echo "Batch operation: Implementing all CRITICAL priority issues"
    OPERATION_TYPE="implement_critical"
    SELECTED_ISSUES=$(jq -r '.issues[] | select(.priority == "CRITICAL") | .id' .claude/optimize/pending/issues.json 2>/dev/null | tr '\n' ',' | sed 's/,$//' || {
        grep -A 10 '"priority": "CRITICAL"' .claude/optimize/pending/issues.json | grep '"id":' | sed 's/.*"id": "\([^"]*\)".*/\1/' | tr '\n' ',' | sed 's/,$//'
    })
    IMPLEMENT_COUNT=$(echo "$SELECTED_ISSUES" | tr ',' '\n' | grep -v '^$' | wc -l)
    
elif [[ "$USER_INPUT" == *"IMPLEMENT ALL HIGH"* ]]; then
    echo "Batch operation: Implementing all HIGH priority issues"
    OPERATION_TYPE="implement_high"
    SELECTED_ISSUES=$(jq -r '.issues[] | select(.priority == "HIGH") | .id' .claude/optimize/pending/issues.json 2>/dev/null | tr '\n' ',' | sed 's/,$//' || {
        grep -A 10 '"priority": "HIGH"' .claude/optimize/pending/issues.json | grep '"id":' | sed 's/.*"id": "\([^"]*\)".*/\1/' | tr '\n' ',' | sed 's/,$//'
    })
    IMPLEMENT_COUNT=$(echo "$SELECTED_ISSUES" | tr ',' '\n' | grep -v '^$' | wc -l)
    
elif [[ "$USER_INPUT" == *"IMPLEMENT ALL MEDIUM"* ]]; then
    echo "Batch operation: Implementing all MEDIUM priority issues"
    OPERATION_TYPE="implement_medium"
    SELECTED_ISSUES=$(jq -r '.issues[] | select(.priority == "MEDIUM") | .id' .claude/optimize/pending/issues.json 2>/dev/null | tr '\n' ',' | sed 's/,$//' || {
        grep -A 10 '"priority": "MEDIUM"' .claude/optimize/pending/issues.json | grep '"id":' | sed 's/.*"id": "\([^"]*\)".*/\1/' | tr '\n' ',' | sed 's/,$//'
    })
    IMPLEMENT_COUNT=$(echo "$SELECTED_ISSUES" | tr ',' '\n' | grep -v '^$' | wc -l)
    
elif [[ "$USER_INPUT" == *"IMPLEMENT ALL LOW"* ]]; then
    echo "Batch operation: Implementing all LOW priority issues"
    OPERATION_TYPE="implement_low"
    SELECTED_ISSUES=$(jq -r '.issues[] | select(.priority == "LOW") | .id' .claude/optimize/pending/issues.json 2>/dev/null | tr '\n' ',' | sed 's/,$//' || {
        grep -A 10 '"priority": "LOW"' .claude/optimize/pending/issues.json | grep '"id":' | sed 's/.*"id": "\([^"]*\)".*/\1/' | tr '\n' ',' | sed 's/,$//'
    })
    IMPLEMENT_COUNT=$(echo "$SELECTED_ISSUES" | tr ',' '\n' | grep -v '^$' | wc -l)
    
elif [[ "$USER_INPUT" == *"IMPLEMENT ALL"* ]]; then
    echo "Batch operation: Implementing all issues"
    OPERATION_TYPE="implement_all"
    SELECTED_ISSUES=$(jq -r '.issues[] | .id' .claude/optimize/pending/issues.json 2>/dev/null | tr '\n' ',' | sed 's/,$//' || {
        grep '"id":' .claude/optimize/pending/issues.json | sed 's/.*"id": "\([^"]*\)".*/\1/' | tr '\n' ',' | sed 's/,$//'
    })
    IMPLEMENT_COUNT=$(echo "$SELECTED_ISSUES" | tr ',' '\n' | grep -v '^$' | wc -l)
    
elif [[ "$USER_INPUT" == *"DEFER ALL CRITICAL"* ]]; then
    echo "Batch operation: Deferring all CRITICAL priority issues"
    OPERATION_TYPE="defer_critical"
    SELECTED_ISSUES=$(jq -r '.issues[] | select(.priority == "CRITICAL") | .id' .claude/optimize/pending/issues.json 2>/dev/null | tr '\n' ',' | sed 's/,$//' || {
        grep -A 10 '"priority": "CRITICAL"' .claude/optimize/pending/issues.json | grep '"id":' | sed 's/.*"id": "\([^"]*\)".*/\1/' | tr '\n' ',' | sed 's/,$//'
    })
    DEFER_COUNT=$(echo "$SELECTED_ISSUES" | tr ',' '\n' | grep -v '^$' | wc -l)
    
elif [[ "$USER_INPUT" == *"DEFER ALL HIGH"* ]]; then
    echo "Batch operation: Deferring all HIGH priority issues"
    OPERATION_TYPE="defer_high"
    SELECTED_ISSUES=$(jq -r '.issues[] | select(.priority == "HIGH") | .id' .claude/optimize/pending/issues.json 2>/dev/null | tr '\n' ',' | sed 's/,$//' || {
        grep -A 10 '"priority": "HIGH"' .claude/optimize/pending/issues.json | grep '"id":' | sed 's/.*"id": "\([^"]*\)".*/\1/' | tr '\n' ',' | sed 's/,$//'
    })
    DEFER_COUNT=$(echo "$SELECTED_ISSUES" | tr ',' '\n' | grep -v '^$' | wc -l)
    
elif [[ "$USER_INPUT" == *"DEFER ALL MEDIUM"* ]]; then
    echo "Batch operation: Deferring all MEDIUM priority issues"
    OPERATION_TYPE="defer_medium"
    SELECTED_ISSUES=$(jq -r '.issues[] | select(.priority == "MEDIUM") | .id' .claude/optimize/pending/issues.json 2>/dev/null | tr '\n' ',' | sed 's/,$//' || {
        grep -A 10 '"priority": "MEDIUM"' .claude/optimize/pending/issues.json | grep '"id":' | sed 's/.*"id": "\([^"]*\)".*/\1/' | tr '\n' ',' | sed 's/,$//'
    })
    DEFER_COUNT=$(echo "$SELECTED_ISSUES" | tr ',' '\n' | grep -v '^$' | wc -l)
    
elif [[ "$USER_INPUT" == *"DEFER ALL LOW"* ]]; then
    echo "Batch operation: Deferring all LOW priority issues"
    OPERATION_TYPE="defer_low"
    SELECTED_ISSUES=$(jq -r '.issues[] | select(.priority == "LOW") | .id' .claude/optimize/pending/issues.json 2>/dev/null | tr '\n' ',' | sed 's/,$//' || {
        grep -A 10 '"priority": "LOW"' .claude/optimize/pending/issues.json | grep '"id":' | sed 's/.*"id": "\([^"]*\)".*/\1/' | tr '\n' ',' | sed 's/,$//'
    })
    DEFER_COUNT=$(echo "$SELECTED_ISSUES" | tr ',' '\n' | grep -v '^$' | wc -l)
    
elif [[ "$USER_INPUT" == *"DEFER ALL"* ]]; then
    echo "Batch operation: Deferring all issues"
    OPERATION_TYPE="defer_all"
    DEFER_COUNT=$(jq '.issues | length' .claude/optimize/pending/issues.json 2>/dev/null || grep -c '"id":' .claude/optimize/pending/issues.json)

elif [[ "$USER_INPUT" == *"GH-ISSUE ALL CRITICAL"* ]]; then
    echo "Batch operation: Creating GitHub issues for all CRITICAL priority"
    OPERATION_TYPE="github_critical"
    GITHUB_COUNT=$(jq '[.issues[] | select(.priority == "CRITICAL")] | length' .claude/optimize/pending/issues.json 2>/dev/null || {
        grep -A 10 '"priority": "CRITICAL"' .claude/optimize/pending/issues.json | grep -c '"id":'
    })
    
elif [[ "$USER_INPUT" == *"GH-ISSUE ALL HIGH"* ]]; then
    echo "Batch operation: Creating GitHub issues for all HIGH priority"
    OPERATION_TYPE="github_high"
    GITHUB_COUNT=$(jq '[.issues[] | select(.priority == "HIGH")] | length' .claude/optimize/pending/issues.json 2>/dev/null || {
        grep -A 10 '"priority": "HIGH"' .claude/optimize/pending/issues.json | grep -c '"id":'
    })
    
elif [[ "$USER_INPUT" == *"GH-ISSUE ALL MEDIUM"* ]]; then
    echo "Batch operation: Creating GitHub issues for all MEDIUM priority"
    OPERATION_TYPE="github_medium"
    GITHUB_COUNT=$(jq '[.issues[] | select(.priority == "MEDIUM")] | length' .claude/optimize/pending/issues.json 2>/dev/null || {
        grep -A 10 '"priority": "MEDIUM"' .claude/optimize/pending/issues.json | grep -c '"id":'
    })
    
elif [[ "$USER_INPUT" == *"GH-ISSUE ALL LOW"* ]]; then
    echo "Batch operation: Creating GitHub issues for all LOW priority"
    OPERATION_TYPE="github_low"
    GITHUB_COUNT=$(jq '[.issues[] | select(.priority == "LOW")] | length' .claude/optimize/pending/issues.json 2>/dev/null || {
        grep -A 10 '"priority": "LOW"' .claude/optimize/pending/issues.json | grep -c '"id":'
    })
    
elif [[ "$USER_INPUT" == *"GH-ISSUE ALL"* ]]; then
    echo "Batch operation: Creating GitHub issues for all"
    OPERATION_TYPE="github_all"
    GITHUB_COUNT=$(jq '.issues | length' .claude/optimize/pending/issues.json 2>/dev/null || grep -c '"id":' .claude/optimize/pending/issues.json)
    
else
    echo "Processing individual selections..."
    OPERATION_TYPE="individual"
    
    # Safely extract issue IDs using a more secure approach
    SELECTED_ISSUES=$(printf '%s' "$USER_INPUT" | grep -oE 'OPT-[0-9]{3}' | tr '\n' ',' | sed 's/,$//')
    if [ -n "$SELECTED_ISSUES" ]; then
        echo "Found issue IDs: $SELECTED_ISSUES"
        
        if [[ "$USER_INPUT" == *"IMPLEMENT"* ]]; then
            IMPLEMENT_COUNT=$(echo "$SELECTED_ISSUES" | tr ',' '\n' | wc -l)
        fi
        if [[ "$USER_INPUT" == *"GH-ISSUE"* ]]; then
            GITHUB_COUNT=$(echo "$SELECTED_ISSUES" | tr ',' '\n' | wc -l)
        fi
        if [[ "$USER_INPUT" == *"DEFER"* ]]; then
            DEFER_COUNT=$(echo "$SELECTED_ISSUES" | tr ',' '\n' | wc -l)
        fi
        if [[ "$USER_INPUT" == *"SKIP"* ]]; then
            SKIP_COUNT=$(echo "$SELECTED_ISSUES" | tr ',' '\n' | wc -l)
        fi
    else
        echo "⚠️  No valid issue IDs found in input for individual operations."
        echo "Please use one of these formats:"
        echo "  - Individual: 'Implement OPT-001, OPT-003'"
        echo "  - Batch: 'Implement all', 'Skip all', 'Defer all'"
        echo "  - Priority: 'Implement all critical', 'gh-issue all high'"
        echo "Available issue IDs in current session:"
        jq -r '.issues[0:10][] | "  - " + .id' .claude/optimize/pending/issues.json 2>/dev/null || {
            grep '"id":' .claude/optimize/pending/issues.json | sed 's/.*"id": "\([^"]*\)".*/  - \1/' | head -10
        }
        exit 1
    fi
fi

echo "Command parsing completed."
echo "Selected Issues: $SELECTED_ISSUES"
echo "Operation Type: $OPERATION_TYPE"
echo "Counts - Implement: $IMPLEMENT_COUNT, GitHub: $GITHUB_COUNT, Defer: $DEFER_COUNT, Skip: $SKIP_COUNT"
```

## Generate Implementation Commands

Generate implementation commands with test-first approach and GitHub integration:

```bash
if [ $IMPLEMENT_COUNT -gt 0 ] || [ "$OPERATION_TYPE" = "implement_all" ] || [ "$OPERATION_TYPE" = "implement_critical" ] || [ "$OPERATION_TYPE" = "implement_high" ] || [ "$OPERATION_TYPE" = "implement_medium" ] || [ "$OPERATION_TYPE" = "implement_low" ]; then
    echo "Test Impact Analysis and Updates" >> "$COMMANDS_TEMP_FILE"
    printf '@test-automation-engineer analyze-test-impact --issues="%s" --generate-test-plan\n' "$SELECTED_ISSUES" >> "$COMMANDS_TEMP_FILE"
    echo "@test-automation-engineer update-tests --test-plan='impact-analysis.md' --validate-before-refactor" >> "$COMMANDS_TEMP_FILE"
    echo "" >> "$COMMANDS_TEMP_FILE"

    echo "Implementation with Test Safety" >> "$COMMANDS_TEMP_FILE"
    IFS=',' read -ra ISSUE_ARRAY <<< "$SELECTED_ISSUES"
    for issue in "${ISSUE_ARRAY[@]}"; do
        if [ -n "$issue" ]; then
            # Get the assigned agent for this specific issue
            if command -v jq >/dev/null 2>&1; then
                ASSIGNED_AGENT=$(jq -r --arg id "$issue" '.issues[] | select(.id == $id) | .assigned_agent' .claude/optimize/pending/issues.json)
                ISSUE_TITLE=$(jq -r --arg id "$issue" '.issues[] | select(.id == $id) | .title' .claude/optimize/pending/issues.json)
                RECOMMENDED_ACTION=$(jq -r --arg id "$issue" '.issues[] | select(.id == $id) | .recommended_action' .claude/optimize/pending/issues.json)
            else
                # Fallback method without jq
                ASSIGNED_AGENT=$(grep -A 10 "\"id\": \"$issue\"" .claude/optimize/pending/issues.json | grep '"assigned_agent":' | sed 's/.*"assigned_agent": "\([^"]*\)".*/\1/' | head -1)
                ISSUE_TITLE=$(grep -A 10 "\"id\": \"$issue\"" .claude/optimize/pending/issues.json | grep '"title":' | sed 's/.*"title": "\([^"]*\)".*/\1/' | head -1)
                RECOMMENDED_ACTION=$(grep -A 10 "\"id\": \"$issue\"" .claude/optimize/pending/issues.json | grep '"recommended_action":' | sed 's/.*"recommended_action": "\([^"]*\)".*/\1/' | head -1)
            fi
            
            if [ -n "$ASSIGNED_AGENT" ] && [ "$ASSIGNED_AGENT" != "null" ]; then
                printf 'echo "Implementing %s: %s"\n' "$issue" "$(printf '%s' "$ISSUE_TITLE" | sed 's/\"/\\&/g')" >> "$COMMANDS_TEMP_FILE"
                printf '%s "%s" --issue="%s" --comment="%s" --test-guided\n' "$ASSIGNED_AGENT" "$(printf '%s' "$RECOMMENDED_ACTION" | sed 's/\"/\\&/g')" "$issue" "$(printf '%s' "$USER_COMMENTS" | sed 's/\"/\\&/g')" >> "$COMMANDS_TEMP_FILE"
            else
                printf 'echo "Warning: No assigned agent for %s, using generic approach"\n' "$issue" >> "$COMMANDS_TEMP_FILE"
                printf '@command-reviewer fix "%s" --comment="%s" --test-guided\n' "$issue" "$(printf '%s' "$USER_COMMENTS" | sed 's/\"/\\&/g')" >> "$COMMANDS_TEMP_FILE"
            fi
        fi
    done
    echo "" >> "$COMMANDS_TEMP_FILE"
fi

if [ $GITHUB_COUNT -gt 0 ] || [ "$OPERATION_TYPE" = "github_all" ] || [ "$OPERATION_TYPE" = "github_critical" ] || [ "$OPERATION_TYPE" = "github_high" ] || [ "$OPERATION_TYPE" = "github_medium" ] || [ "$OPERATION_TYPE" = "github_low" ]; then
    echo "GitHub Issue Creation" >> "$COMMANDS_TEMP_FILE"
    
    if [ "$OPERATION_TYPE" = "github_all" ] || [ "$OPERATION_TYPE" = "github_critical" ] || [ "$OPERATION_TYPE" = "github_high" ] || [ "$OPERATION_TYPE" = "github_medium" ] || [ "$OPERATION_TYPE" = "github_low" ]; then
        PRIORITY_FILTER=""
        case "$OPERATION_TYPE" in
            "github_critical") PRIORITY_FILTER="CRITICAL" ;;
            "github_high") PRIORITY_FILTER="HIGH" ;;
            "github_medium") PRIORITY_FILTER="MEDIUM" ;;
            "github_low") PRIORITY_FILTER="LOW" ;;
        esac
        
        # Use jq to process JSON properly, with fallback for systems without jq
        if command -v jq >/dev/null 2>&1; then
            if [ -n "$PRIORITY_FILTER" ]; then
                jq -r --arg ts "$TIMESTAMP" --arg priority "$PRIORITY_FILTER" '.issues[] | select(.priority == $priority) | "gh issue create --title=\"[OPTIMIZATION] \(.title | gsub("\\\\"; "\\\\\\\\") | gsub("\""; "\\\\\""))\" --body=\"Priority: \(.priority)\\nCategory: \(.category)\\nDescription: \(.description | gsub("\\\\"; "\\\\\\\\") | gsub("\""; "\\\\\""))\\nAgent: \(.assigned_agent)\\nGenerated from optimization session " + $ts + "\" --label=\"optimization,\(.priority | ascii_downcase)-priority\""' .claude/optimize/pending/issues.json >> "$COMMANDS_TEMP_FILE"
            else
                jq -r --arg ts "$TIMESTAMP" '.issues[] | "gh issue create --title=\"[OPTIMIZATION] \(.title | gsub("\\\\"; "\\\\\\\\") | gsub("\""; "\\\\\""))\" --body=\"Priority: \(.priority)\\nCategory: \(.category)\\nDescription: \(.description | gsub("\\\\"; "\\\\\\\\") | gsub("\""; "\\\\\""))\\nAgent: \(.assigned_agent)\\nGenerated from optimization session " + $ts + "\" --label=\"optimization,\(.priority | ascii_downcase)-priority\""' .claude/optimize/pending/issues.json >> "$COMMANDS_TEMP_FILE"
            fi
        else
            echo "Warning: jq not available, using fallback parsing for GitHub issues"
            # Fallback method for systems without jq
            while IFS= read -r line; do
                if [[ $line == *'"id":'* ]]; then
                    ISSUE_ID=$(echo "$line" | sed 's/.*"id": "\([^"]*\)".*/\1/')
                elif [[ $line == *'"title":'* ]]; then
                    ISSUE_TITLE=$(echo "$line" | sed 's/.*"title": "\([^"]*\)".*/\1/')
                elif [[ $line == *'"priority":'* ]]; then
                    ISSUE_PRIORITY=$(echo "$line" | sed 's/.*"priority": "\([^"]*\)".*/\1/')
                elif [[ $line == *'"category":'* ]]; then
                    ISSUE_CATEGORY=$(echo "$line" | sed 's/.*"category": "\([^"]*\)".*/\1/')
                elif [[ $line == *'"assigned_agent":'* ]]; then
                    ISSUE_AGENT=$(echo "$line" | sed 's/.*"assigned_agent": "\([^"]*\)".*/\1/')
                elif [[ $line == *'"description":'* ]]; then
                    ISSUE_DESC=$(echo "$line" | sed 's/.*"description": "\([^"]*\)".*/\1/')
                    
                    if [ -z "$PRIORITY_FILTER" ] || [[ $ISSUE_PRIORITY == "$PRIORITY_FILTER" ]]; then
                        printf 'gh issue create --title="[OPTIMIZATION] %s" --body="Priority: %s\\nCategory: %s\\nDescription: %s\\nAgent: %s\\nGenerated from optimization session %s" --label="optimization,%s-priority"\n' \
                            "$(printf '%s' "$ISSUE_TITLE" | sed 's/[\\\"`$]/\\&/g')" \
                            "$ISSUE_PRIORITY" \
                            "$(printf '%s' "$ISSUE_CATEGORY" | sed 's/[\\\"`$]/\\&/g')" \
                            "$(printf '%s' "$ISSUE_DESC" | sed 's/[\\\"`$]/\\&/g')" \
                            "$(printf '%s' "$ISSUE_AGENT" | sed 's/[\\\"`$]/\\&/g')" \
                            "$TIMESTAMP" \
                            "$(printf '%s' "$ISSUE_PRIORITY" | tr '[:upper:]' '[:lower:]')" >> "$COMMANDS_TEMP_FILE"
                    fi
                fi
            done < .claude/optimize/pending/issues.json
        fi
    else
        # Process individual issues for GitHub issue creation
        IFS=',' read -ra ISSUE_ARRAY <<< "$SELECTED_ISSUES"
        for issue in "${ISSUE_ARRAY[@]}"; do
            if [ -n "$issue" ]; then
                # Use jq for proper JSON parsing if available
                if command -v jq >/dev/null 2>&1; then
                    ISSUE_DATA=$(jq -r --arg id "$issue" '.issues[] | select(.id == $id) | "\(.title)|\(.priority)|\(.category)|\(.description)|\(.assigned_agent)"' .claude/optimize/pending/issues.json)
                    if [ -n "$ISSUE_DATA" ]; then
                        IFS='|' read -r ISSUE_TITLE ISSUE_PRIORITY ISSUE_CATEGORY ISSUE_DESC ISSUE_AGENT <<< "$ISSUE_DATA"
                        printf 'gh issue create --title="[OPTIMIZATION] %s" --body="Priority: %s\\nCategory: %s\\nDescription: %s\\nAgent: %s\\nGenerated from optimization session %s" --label="optimization,%s-priority"\n' \
                            "$(printf '%s' "$ISSUE_TITLE" | sed 's/[\\\"`$]/\\&/g')" \
                            "$ISSUE_PRIORITY" \
                            "$(printf '%s' "$ISSUE_CATEGORY" | sed 's/[\\\"`$]/\\&/g')" \
                            "$(printf '%s' "$ISSUE_DESC" | sed 's/[\\\"`$]/\\&/g')" \
                            "$(printf '%s' "$ISSUE_AGENT" | sed 's/[\\\"`$]/\\&/g')" \
                            "$TIMESTAMP" \
                            "$(printf '%s' "$ISSUE_PRIORITY" | tr '[:upper:]' '[:lower:]')" >> "$COMMANDS_TEMP_FILE"
                    fi
                else
                    # Fallback method without jq
                    ISSUE_TITLE=$(grep -A 10 "\"id\": \"$issue\"" .claude/optimize/pending/issues.json | grep '"title":' | sed 's/.*"title": "\([^"]*\)".*/\1/' | head -1)
                    ISSUE_PRIORITY=$(grep -A 10 "\"id\": \"$issue\"" .claude/optimize/pending/issues.json | grep '"priority":' | sed 's/.*"priority": "\([^"]*\)".*/\1/' | head -1)
                    ISSUE_CATEGORY=$(grep -A 10 "\"id\": \"$issue\"" .claude/optimize/pending/issues.json | grep '"category":' | sed 's/.*"category": "\([^"]*\)".*/\1/' | head -1)
                    ISSUE_DESC=$(grep -A 10 "\"id\": \"$issue\"" .claude/optimize/pending/issues.json | grep '"description":' | sed 's/.*"description": "\([^"]*\)".*/\1/' | head -1)
                    ISSUE_AGENT=$(grep -A 10 "\"id\": \"$issue\"" .claude/optimize/pending/issues.json | grep '"assigned_agent":' | sed 's/.*"assigned_agent": "\([^"]*\)".*/\1/' | head -1)
                    printf 'gh issue create --title="[OPTIMIZATION] %s" --body="Priority: %s\\nCategory: %s\\nDescription: %s\\nAgent: %s\\nGenerated from optimization session %s" --label="optimization,%s-priority"\n' \
                        "$(printf '%s' "$ISSUE_TITLE" | sed 's/[\\\"`$]/\\&/g')" \
                        "$ISSUE_PRIORITY" \
                        "$(printf '%s' "$ISSUE_CATEGORY" | sed 's/[\\\"`$]/\\&/g')" \
                        "$(printf '%s' "$ISSUE_DESC" | sed 's/[\\\"`$]/\\&/g')" \
                        "$(printf '%s' "$ISSUE_AGENT" | sed 's/[\\\"`$]/\\&/g')" \
                        "$TIMESTAMP" \
                        "$(printf '%s' "$ISSUE_PRIORITY" | tr '[:upper:]' '[:lower:]')" >> "$COMMANDS_TEMP_FILE"
                fi
            fi
        done
    fi
    echo "" >> "$COMMANDS_TEMP_FILE"
fi

if [ $DEFER_COUNT -gt 0 ] || [ "$OPERATION_TYPE" = "defer_all" ] || [ "$OPERATION_TYPE" = "defer_critical" ] || [ "$OPERATION_TYPE" = "defer_high" ] || [ "$OPERATION_TYPE" = "defer_medium" ] || [ "$OPERATION_TYPE" = "defer_low" ]; then
    echo "Moving deferred issues to backlog with atomic operations..." 
    
    # Create temporary file for backlog with atomic operations
    BACKLOG_TEMP_FILE=".claude/optimize/backlog/deferred_issues_${TIMESTAMP}.json.tmp.$$"
    BACKLOG_FINAL_FILE=".claude/optimize/backlog/deferred_issues_${TIMESTAMP}.json"
    
    if [ "$OPERATION_TYPE" = "defer_all" ]; then
        # Copy all issues to backlog with proper metadata
        if command -v jq >/dev/null 2>&1; then
            if ! jq --arg timestamp "$TIMESTAMP" --arg comment "$USER_COMMENTS" '{
                "deferred_session": {
                    "timestamp": $timestamp,
                    "comment": $comment,
                    "operation_type": "defer_all"
                },
                "deferred_issues": .issues
            }' .claude/optimize/pending/issues.json > "$BACKLOG_TEMP_FILE"; then
                echo "❌ Error: Failed to create deferred issues file"
                rm -f "$BACKLOG_TEMP_FILE"
                exit 1
            fi
        else
            if ! cp .claude/optimize/pending/issues.json "$BACKLOG_TEMP_FILE"; then
                echo "❌ Error: Failed to copy issues to backlog"
                exit 1
            fi
        fi
    else
        # Create backlog file with only selected issues using atomic operations
        if command -v jq >/dev/null 2>&1; then
            if ! echo "$SELECTED_ISSUES" | tr ',' '\n' | jq -R --arg timestamp "$TIMESTAMP" --arg comment "$USER_COMMENTS" --slurpfile all_issues .claude/optimize/pending/issues.json '{
                "deferred_session": {
                    "timestamp": $timestamp,
                    "comment": $comment,
                    "operation_type": "defer_individual"
                },
                "deferred_issues": [$all_issues[0].issues[] | select(.id == input)]
            }' > "$BACKLOG_TEMP_FILE"; then
                echo "❌ Error: Failed to create individual deferred issues file"
                rm -f "$BACKLOG_TEMP_FILE"
                exit 1
            fi
        else
            # Fallback method with error checking
            if ! echo '{"deferred_issues": []}' > "$BACKLOG_TEMP_FILE"; then
                echo "❌ Error: Failed to initialize deferred issues file"
                exit 1
            fi
            IFS=',' read -ra ISSUE_ARRAY <<< "$SELECTED_ISSUES"
            for issue in "${ISSUE_ARRAY[@]}"; do
                if [ -n "$issue" ]; then
                    if ! grep -A 15 "\"id\": \"$issue\"" .claude/optimize/pending/issues.json >> "$BACKLOG_TEMP_FILE"; then
                        echo "❌ Warning: Failed to add issue $issue to deferred file"
                    fi
                fi
            done
        fi
    fi
    
    # Validate temporary file was created
    if [ ! -f "$BACKLOG_TEMP_FILE" ] || [ ! -s "$BACKLOG_TEMP_FILE" ]; then
        echo "❌ Error: Backlog file creation failed"
        rm -f "$BACKLOG_TEMP_FILE"
        exit 1
    fi
    
    # Validate JSON if jq is available
    if command -v jq >/dev/null 2>&1; then
        if ! jq empty "$BACKLOG_TEMP_FILE" >/dev/null 2>&1; then
            echo "❌ Error: Generated backlog file contains invalid JSON"
            rm -f "$BACKLOG_TEMP_FILE"
            exit 1
        fi
        echo "✓ Backlog JSON validated"
    fi
    
    # Atomic move to final location
    if ! mv "$BACKLOG_TEMP_FILE" "$BACKLOG_FINAL_FILE"; then
        echo "❌ Error: Failed to finalize backlog file"
        rm -f "$BACKLOG_TEMP_FILE"
        exit 1
    fi
    
    echo "✓ Deferred issues saved atomically to: $BACKLOG_FINAL_FILE"
fi

if [ $SKIP_COUNT -gt 0 ] || [ "$OPERATION_TYPE" = "skip_all" ]; then
    echo "Moving skipped issues to completed folder..."
    
    if [ "$OPERATION_TYPE" = "skip_all" ]; then
        # Copy all issues to completed with proper metadata
        if command -v jq >/dev/null 2>&1; then
            jq --arg timestamp "$TIMESTAMP" --arg comment "$USER_COMMENTS" '{
                "skipped_session": {
                    "timestamp": $timestamp,
                    "comment": $comment,
                    "operation_type": "skip_all"
                },
                "skipped_issues": .issues
            }' .claude/optimize/pending/issues.json > .claude/optimize/completed/skipped_issues_${TIMESTAMP}.json
        else
            cp .claude/optimize/pending/issues.json .claude/optimize/completed/skipped_issues_${TIMESTAMP}.json
        fi
    else
        # Create completed file with only selected issues
        if command -v jq >/dev/null 2>&1; then
            echo "$SELECTED_ISSUES" | tr ',' '\n' | jq -R --arg timestamp "$TIMESTAMP" --arg comment "$USER_COMMENTS" --slurpfile all_issues .claude/optimize/pending/issues.json '{
                "skipped_session": {
                    "timestamp": $timestamp,
                    "comment": $comment,
                    "operation_type": "skip_individual"
                },
                "skipped_issues": [$all_issues[0].issues[] | select(.id == input)]
            }' > .claude/optimize/completed/skipped_issues_${TIMESTAMP}.json
        else
            # Fallback method
            echo '{"skipped_issues": []}' > .claude/optimize/completed/skipped_issues_${TIMESTAMP}.json
            IFS=',' read -ra ISSUE_ARRAY <<< "$SELECTED_ISSUES"
            for issue in "${ISSUE_ARRAY[@]}"; do
                if [ -n "$issue" ]; then
                    grep -A 15 "\"id\": \"$issue\"" .claude/optimize/pending/issues.json >> .claude/optimize/completed/skipped_issues_${TIMESTAMP}.json
                fi
            done
        fi
    fi
fi

# Add validation and documentation commands
echo "# Validation and Documentation" >> "$COMMANDS_TEMP_FILE"
echo "echo 'Running validation tests...'" >> "$COMMANDS_TEMP_FILE"
echo "if command -v pytest >/dev/null 2>&1; then" >> "$COMMANDS_TEMP_FILE"
echo "    pytest -xvs --tb=short || { echo '❌ Tests failed - refactoring stopped'; exit 1; }" >> "$COMMANDS_TEMP_FILE"
echo "else" >> "$COMMANDS_TEMP_FILE"
echo "    echo '⚠️  pytest not available, skipping test validation'" >> "$COMMANDS_TEMP_FILE"
echo "fi" >> "$COMMANDS_TEMP_FILE"
echo "" >> "$COMMANDS_TEMP_FILE"
echo "echo 'Documenting optimization session...'" >> "$COMMANDS_TEMP_FILE"
printf '@project-scribe "Document optimization session with %d implemented issues, %d GitHub issues, %d deferred, %d skipped" --issues="%s" --decisions=".claude/optimize/decisions/review_%s.md" --summary="Test-driven optimization session with GitHub integration"\n' "$IMPLEMENT_COUNT" "$GITHUB_COUNT" "$DEFER_COUNT" "$SKIP_COUNT" "$SELECTED_ISSUES" "$TIMESTAMP" >> "$COMMANDS_TEMP_FILE"

printf 'User Selection: %s\n' "$SELECTED_ISSUES" > ".claude/optimize/decisions/review_${TIMESTAMP}.md"
printf 'Comments: %s\n' "$USER_COMMENTS" >> ".claude/optimize/decisions/review_${TIMESTAMP}.md"
echo "Test Strategy: Test-First TDD approach" >> .claude/optimize/decisions/review_${TIMESTAMP}.md
printf 'Operation Type: %s\n' "$OPERATION_TYPE" >> ".claude/optimize/decisions/review_${TIMESTAMP}.md"
echo "" >> .claude/optimize/decisions/review_${TIMESTAMP}.md
echo "Issue Distribution:" >> .claude/optimize/decisions/review_${TIMESTAMP}.md
echo "- Implemented: $IMPLEMENT_COUNT issues" >> .claude/optimize/decisions/review_${TIMESTAMP}.md
echo "- GitHub Issues: $GITHUB_COUNT issues → created in repository" >> .claude/optimize/decisions/review_${TIMESTAMP}.md
echo "- Deferred: $DEFER_COUNT issues → backlog" >> .claude/optimize/decisions/review_${TIMESTAMP}.md
echo "- Skipped: $SKIP_COUNT issues → permanently dismissed" >> .claude/optimize/decisions/review_${TIMESTAMP}.md

echo "Moving selected issues to appropriate folders..."
echo "✓ Implemented issues → $COMMANDS_FINAL_FILE"
if [ $GITHUB_COUNT -gt 0 ]; then
    echo "✓ GitHub issues → commands added to commands.sh"
fi
if [ $DEFER_COUNT -gt 0 ]; then
    echo "✓ Deferred issues → .claude/optimize/backlog/deferred_issues_${TIMESTAMP}.json"
fi
if [ $SKIP_COUNT -gt 0 ]; then
    echo "✓ Skipped issues → .claude/optimize/completed/skipped_issues_${TIMESTAMP}.json"
fi

# Atomically move commands file to final location
if [ -f "$COMMANDS_TEMP_FILE" ]; then
    if ! mv "$COMMANDS_TEMP_FILE" "$COMMANDS_FINAL_FILE"; then
        echo "❌ Error: Failed to finalize commands file"
        rm -f "$COMMANDS_TEMP_FILE"
        exit 1
    fi
    
    # Final validation of commands file
    if [ ! -s "$COMMANDS_FINAL_FILE" ] || [ ! -x "$COMMANDS_FINAL_FILE" ]; then
        echo "❌ Error: Commands file is empty or not executable"
        exit 1
    fi
    
    echo "✓ Commands file created atomically: $(wc -l < "$COMMANDS_FINAL_FILE") lines"
fi

# Final summary and execution instructions
echo ""
echo "✅ OPTIMIZATION REVIEW COMPLETE - ${TIMESTAMP}"
echo ""
echo "📊 SUMMARY:"
echo "   • Issues Processed: $(jq '.issues | length' .claude/optimize/pending/issues.json 2>/dev/null || echo 'N/A')"
echo "   • Implementation Queue: $IMPLEMENT_COUNT issues"
echo "   • GitHub Issues to Create: $GITHUB_COUNT issues"
echo "   • Deferred to Backlog: $DEFER_COUNT issues"
echo "   • Skipped Permanently: $SKIP_COUNT issues"
echo ""
if [ $IMPLEMENT_COUNT -gt 0 ] || [ $GITHUB_COUNT -gt 0 ]; then
    echo "🚀 NEXT STEPS:"
    echo "   1. Review generated commands: cat .claude/optimize/pending/commands.sh"
    echo "   2. Execute commands: bash .claude/optimize/pending/commands.sh"
    echo "   3. Monitor progress: /optimize-status"
    echo ""
    echo "⚠️  IMPORTANT: Generated commands include test-first approach and agent assignments"
    if [ $GITHUB_COUNT -gt 0 ]; then
        echo "   GitHub CLI (gh) is required for issue creation"
    fi
    echo ""
    echo "📁 FILES CREATED:"
    echo "   • .claude/optimize/pending/commands.sh - Executable implementation script"
    echo "   • .claude/optimize/decisions/review_${TIMESTAMP}.md - Session record"
    if [ $DEFER_COUNT -gt 0 ]; then
        echo "   • .claude/optimize/backlog/deferred_issues_${TIMESTAMP}.json - Deferred issues"
    fi
    if [ $SKIP_COUNT -gt 0 ]; then
        echo "   • .claude/optimize/completed/skipped_issues_${TIMESTAMP}.json - Skipped issues"
    fi
else
    echo "ℹ️  No implementation actions selected. Review completed with issue management only."
fi
```
