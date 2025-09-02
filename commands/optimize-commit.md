---
allowed-tools: Bash(git:*), Bash(cat:*), Bash(grep:*), Bash(echo:*), Bash(find:*), Bash(ls:*), Bash(date:*), Bash(sed:*), Bash(jq:*), Bash(head:*), Bash(tail:*), Bash(wc:*), Bash(mv:*)
description: Commit optimization improvements with session tracking and attribution
---

## Session Discovery and Validation

Detect recent optimization sessions and validate system state:

```bash
# Enable strict error handling
set -e  # Exit on any command failure
set -u  # Exit on undefined variables  
set -o pipefail  # Exit on pipe failures

# Function for cleanup on error
cleanup_on_error() {
    echo "❌ Optimization commit failed. Cleaning up temporary files..."
    # Remove any partial files that might have been created
    rm -f ".claude/optimize/session_data.tmp" 2>/dev/null || true
    rm -f ".claude/optimize/commit_message.tmp" 2>/dev/null || true
    exit 1
}

# Set up error trap
trap cleanup_on_error ERR

echo "Starting optimization-aware git commit with session detection..."

# Function for safe directory validation
validate_directory() {
    local dir="$1"
    local description="$2"
    
    if [ ! -e "$dir" ]; then
        return 1
    fi
    
    if [ ! -d "$dir" ]; then
        echo "❌ Warning: Path $dir exists but is not a directory"
        return 1
    fi
    
    if [ ! -r "$dir" ]; then
        echo "❌ Warning: Cannot read directory $dir (permission denied)"
        return 1
    fi
    
    return 0
}

# Validate git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "❌ Not a git repository"
    echo "   This command must be run from within a git repository"
    exit 1
fi

echo "✓ Git repository validated"

# Check for optimization system initialization
if ! validate_directory ".claude/optimize" "optimization system"; then
    echo "❌ Optimization system not initialized"
    echo "   Run '/optimize' to set up the optimization workflow"
    echo "   This command works best with existing optimization sessions"
    
    echo ""
    echo "Falling back to standard git commit workflow..."
    echo ""
    
    # Standard git workflow when no optimization system
    if ! git diff --cached --quiet; then
        echo "Staged changes detected. Proceeding with standard commit..."
        echo -n "Enter commit message: "
        read -r COMMIT_MESSAGE
        
        if [ -z "$COMMIT_MESSAGE" ]; then
            echo "❌ No commit message provided"
            exit 1
        fi
        
        if ! git commit -m "$COMMIT_MESSAGE"; then
            echo "❌ Commit failed"
            exit 1
        fi
        
        echo "✅ Standard git commit completed"
        exit 0
    else
        echo "❌ No staged changes found"
        echo "   Stage your changes with 'git add' before committing"
        exit 1
    fi
fi

echo "✓ Optimization system found"
```

## Find Recent Optimization Sessions

Scan for recent optimization sessions and extract session data:

```bash
echo "Scanning for recent optimization sessions..."

# Find the most recent optimization session
LATEST_SESSION=""
LATEST_SESSION_FILE=""
LATEST_TIMESTAMP=""

if validate_directory ".claude/optimize/decisions" "decision records"; then
    # Find the most recent review session file
    LATEST_SESSION_FILE=$(find .claude/optimize/decisions -name "review_*.md" -type f 2>/dev/null | \
                         head -10 | \
                         while IFS= read -r file; do
                             if [ -f "$file" ] && [ -r "$file" ]; then
                                 basename "$file" | sed 's/^review_\(.*\)\.md$/\1 '"$file"'/'
                             fi
                         done | \
                         sort -r | \
                         head -1)
    
    if [ -n "$LATEST_SESSION_FILE" ]; then
        LATEST_TIMESTAMP=$(echo "$LATEST_SESSION_FILE" | cut -d' ' -f1)
        LATEST_SESSION_FILE=$(echo "$LATEST_SESSION_FILE" | cut -d' ' -f2-)
        
        # Validate timestamp format
        if echo "$LATEST_TIMESTAMP" | grep -qE '^[0-9]{8}_[0-9]{6}$'; then
            LATEST_SESSION="$LATEST_TIMESTAMP"
            echo "✓ Found recent optimization session: $LATEST_SESSION"
            echo "   Session file: $(basename "$LATEST_SESSION_FILE")"
        else
            echo "⚠️  Found session file but invalid timestamp format"
        fi
    else
        echo "⚠️  No recent optimization session files found"
    fi
else
    echo "⚠️  Decisions directory not accessible"
fi

# Alternative: Look for recent commands execution
LATEST_COMMANDS=""
if [ -z "$LATEST_SESSION" ] && [ -f ".claude/optimize/pending/commands.sh" ]; then
    # Check if commands file has recent modification
    if command -v stat >/dev/null 2>&1; then
        # Get file modification time and compare with current time
        COMMANDS_AGE=$(find .claude/optimize/pending -name "commands.sh" -mtime -1 2>/dev/null | wc -l)
        if [ "$COMMANDS_AGE" -gt 0 ]; then
            echo "✓ Found recently modified commands.sh (within 24 hours)"
            LATEST_COMMANDS=".claude/optimize/pending/commands.sh"
            # Try to extract timestamp from commands file
            LATEST_SESSION=$(grep "Generated Commands -" "$LATEST_COMMANDS" 2>/dev/null | \
                           sed 's/.*Generated Commands - \([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9]\).*/\1/' | \
                           head -1)
            if [ -n "$LATEST_SESSION" ]; then
                echo "   Extracted session ID: $LATEST_SESSION"
            fi
        fi
    else
        echo "ℹ️  Cannot determine commands file age (stat command not available)"
        LATEST_COMMANDS=".claude/optimize/pending/commands.sh"
    fi
fi

# If no optimization sessions found, proceed with enhanced standard commit
if [ -z "$LATEST_SESSION" ] && [ -z "$LATEST_COMMANDS" ]; then
    echo ""
    echo "No recent optimization sessions detected"
    echo "Proceeding with standard git commit with optimization context awareness..."
    echo ""
fi
```

## Extract Session Data and Implemented Issues

Parse session data to understand what was implemented:

```bash
IMPLEMENTED_ISSUES=""
SESSION_COMMENTS=""
OPERATION_TYPE=""
IMPLEMENT_COUNT=0
GITHUB_COUNT=0
DEFER_COUNT=0
SKIP_COUNT=0

if [ -n "$LATEST_SESSION_FILE" ] && [ -f "$LATEST_SESSION_FILE" ]; then
    echo "Extracting session data from: $(basename "$LATEST_SESSION_FILE")"
    
    # Read session data safely
    if [ -r "$LATEST_SESSION_FILE" ] && [ -s "$LATEST_SESSION_FILE" ]; then
        # Extract user selection (implemented issues)
        USER_SELECTION=$(grep "^User Selection:" "$LATEST_SESSION_FILE" 2>/dev/null | sed 's/^User Selection: //' | head -1)
        if [ -n "$USER_SELECTION" ]; then
            # Extract OPT-XXX issue IDs
            IMPLEMENTED_ISSUES=$(echo "$USER_SELECTION" | grep -oE 'OPT-[0-9]{3}' | tr '\n' ',' | sed 's/,$//')
            if [ -n "$IMPLEMENTED_ISSUES" ]; then
                IMPLEMENT_COUNT=$(echo "$IMPLEMENTED_ISSUES" | tr ',' '\n' | grep -v '^$' | wc -l)
                echo "   Found implemented issues: $IMPLEMENTED_ISSUES"
                echo "   Implementation count: $IMPLEMENT_COUNT"
            fi
        fi
        
        # Extract comments
        SESSION_COMMENTS=$(grep "^Comments:" "$LATEST_SESSION_FILE" 2>/dev/null | sed 's/^Comments: //' | head -1)
        if [ -n "$SESSION_COMMENTS" ] && [ "$SESSION_COMMENTS" != "null" ]; then
            echo "   Session comments: $SESSION_COMMENTS"
        fi
        
        # Extract operation type
        OPERATION_TYPE=$(grep "^Operation Type:" "$LATEST_SESSION_FILE" 2>/dev/null | sed 's/^Operation Type: //' | head -1)
        if [ -n "$OPERATION_TYPE" ]; then
            echo "   Operation type: $OPERATION_TYPE"
        fi
        
        # Extract counts
        IMPLEMENT_COUNT=$(grep "- Implemented:" "$LATEST_SESSION_FILE" 2>/dev/null | sed 's/.*Implemented: \([0-9]*\).*/\1/' | head -1)
        GITHUB_COUNT=$(grep "- GitHub Issues:" "$LATEST_SESSION_FILE" 2>/dev/null | sed 's/.*GitHub Issues: \([0-9]*\).*/\1/' | head -1)
        DEFER_COUNT=$(grep "- Deferred:" "$LATEST_SESSION_FILE" 2>/dev/null | sed 's/.*Deferred: \([0-9]*\).*/\1/' | head -1)
        SKIP_COUNT=$(grep "- Skipped:" "$LATEST_SESSION_FILE" 2>/dev/null | sed 's/.*Skipped: \([0-9]*\).*/\1/' | head -1)
        
        # Validate counts are numbers
        IMPLEMENT_COUNT=$(echo "$IMPLEMENT_COUNT" | grep -E '^[0-9]+$' || echo "0")
        GITHUB_COUNT=$(echo "$GITHUB_COUNT" | grep -E '^[0-9]+$' || echo "0")
        DEFER_COUNT=$(echo "$DEFER_COUNT" | grep -E '^[0-9]+$' || echo "0")
        SKIP_COUNT=$(echo "$SKIP_COUNT" | grep -E '^[0-9]+$' || echo "0")
        
        echo "   Counts - Implemented: $IMPLEMENT_COUNT, GitHub: $GITHUB_COUNT, Deferred: $DEFER_COUNT, Skipped: $SKIP_COUNT"
    else
        echo "⚠️  Session file not readable or empty"
    fi
elif [ -n "$LATEST_COMMANDS" ] && [ -f "$LATEST_COMMANDS" ]; then
    echo "Extracting session data from commands file..."
    
    # Try to extract issue information from commands file
    if [ -r "$LATEST_COMMANDS" ] && [ -s "$LATEST_COMMANDS" ]; then
        # Look for issue patterns in the commands
        IMPLEMENTED_ISSUES=$(grep -oE 'OPT-[0-9]{3}' "$LATEST_COMMANDS" 2>/dev/null | sort -u | tr '\n' ',' | sed 's/,$//')
        if [ -n "$IMPLEMENTED_ISSUES" ]; then
            IMPLEMENT_COUNT=$(echo "$IMPLEMENTED_ISSUES" | tr ',' '\n' | grep -v '^$' | wc -l)
            echo "   Extracted issues from commands: $IMPLEMENTED_ISSUES"
            echo "   Implementation count: $IMPLEMENT_COUNT"
        fi
        
        # Try to extract operation type from commands structure
        if grep -q "gh issue create" "$LATEST_COMMANDS" 2>/dev/null; then
            GITHUB_COUNT=$(grep -c "gh issue create" "$LATEST_COMMANDS" 2>/dev/null || echo "0")
            echo "   GitHub issue creation commands found: $GITHUB_COUNT"
        fi
    else
        echo "⚠️  Commands file not readable or empty"
    fi
fi
```

## Generate Optimization-Aware Commit Message

Create contextually appropriate commit messages based on session data:

```bash
echo "Generating optimization-aware commit message..."

# Function to generate issue descriptions
get_issue_descriptions() {
    local issues="$1"
    local descriptions=""
    
    if [ -n "$issues" ] && [ -f ".claude/optimize/pending/issues.json" ]; then
        if command -v jq >/dev/null 2>&1; then
            # Use jq for proper JSON parsing
            echo "$issues" | tr ',' '\n' | while read -r issue; do
                if [ -n "$issue" ]; then
                    description=$(jq -r --arg id "$issue" '.issues[]? | select(.id == $id) | .title' .claude/optimize/pending/issues.json 2>/dev/null)
                    if [ -n "$description" ] && [ "$description" != "null" ]; then
                        echo "$issue ($description)"
                    else
                        echo "$issue"
                    fi
                fi
            done | head -5 | tr '\n' ',' | sed 's/,$//'
        else
            # Fallback without jq
            echo "$issues" | tr ',' '\n' | while read -r issue; do
                if [ -n "$issue" ]; then
                    description=$(grep -A 5 "\"id\": \"$issue\"" .claude/optimize/pending/issues.json 2>/dev/null | \
                                grep '"title":' | sed 's/.*"title": "\([^"]*\)".*/\1/' | head -1)
                    if [ -n "$description" ]; then
                        echo "$issue ($description)"
                    else
                        echo "$issue"
                    fi
                fi
            done | head -5 | tr '\n' ',' | sed 's/,$//'
        fi
    else
        echo "$issues"
    fi
}

# Create temporary file for commit message
COMMIT_MSG_FILE=".claude/optimize/commit_message.tmp.$$"

# Generate commit message based on optimization context
if [ -n "$LATEST_SESSION" ] && [ "$IMPLEMENT_COUNT" -gt 0 ]; then
    echo "Creating optimization session commit message..."
    
    # Get detailed issue descriptions
    ISSUE_DESCRIPTIONS=$(get_issue_descriptions "$IMPLEMENTED_ISSUES")
    
    # Create structured commit message
    {
        # Commit title with optimization context
        if [ "$IMPLEMENT_COUNT" -eq 1 ]; then
            printf "optimize(%s): implement %s improvement\n\n" "$LATEST_SESSION" "$IMPLEMENTED_ISSUES"
        else
            printf "optimize(%s): implement %d improvements (%s)\n\n" "$LATEST_SESSION" "$IMPLEMENT_COUNT" "$IMPLEMENTED_ISSUES"
        fi
        
        # Detailed session information
        printf "Session: %s\n" "$LATEST_SESSION"
        
        if [ -n "$ISSUE_DESCRIPTIONS" ]; then
            printf "Issues: %s\n" "$ISSUE_DESCRIPTIONS"
        elif [ -n "$IMPLEMENTED_ISSUES" ]; then
            printf "Issues: %s\n" "$IMPLEMENTED_ISSUES"
        fi
        
        # Impact summary
        if [ "$IMPLEMENT_COUNT" -gt 0 ] || [ "$GITHUB_COUNT" -gt 0 ] || [ "$DEFER_COUNT" -gt 0 ]; then
            printf "Impact: "
            impact_parts=""
            if [ "$IMPLEMENT_COUNT" -gt 0 ]; then
                impact_parts="${impact_parts}${IMPLEMENT_COUNT} implemented"
            fi
            if [ "$GITHUB_COUNT" -gt 0 ]; then
                if [ -n "$impact_parts" ]; then
                    impact_parts="${impact_parts}, "
                fi
                impact_parts="${impact_parts}${GITHUB_COUNT} GitHub issues"
            fi
            if [ "$DEFER_COUNT" -gt 0 ]; then
                if [ -n "$impact_parts" ]; then
                    impact_parts="${impact_parts}, "
                fi
                impact_parts="${impact_parts}${DEFER_COUNT} deferred"
            fi
            printf "%s\n" "$impact_parts"
        fi
        
        # Add session comments if available
        if [ -n "$SESSION_COMMENTS" ] && [ "$SESSION_COMMENTS" != "null" ]; then
            printf "Comments: %s\n" "$SESSION_COMMENTS"
        fi
        
        # Reference to session files
        printf "\nSee .claude/optimize/decisions/review_%s.md for session details" "$LATEST_SESSION"
        
    } > "$COMMIT_MSG_FILE"
    
elif [ -n "$IMPLEMENTED_ISSUES" ]; then
    echo "Creating commit message with detected optimization issues..."
    
    # Get issue descriptions
    ISSUE_DESCRIPTIONS=$(get_issue_descriptions "$IMPLEMENTED_ISSUES")
    
    {
        if [ "$IMPLEMENT_COUNT" -eq 1 ]; then
            printf "optimize: implement %s improvement\n\n" "$IMPLEMENTED_ISSUES"
        else
            printf "optimize: implement %d improvements (%s)\n\n" "$IMPLEMENT_COUNT" "$IMPLEMENTED_ISSUES"
        fi
        
        if [ -n "$ISSUE_DESCRIPTIONS" ]; then
            printf "Issues: %s\n" "$ISSUE_DESCRIPTIONS"
        fi
        
        printf "Impact: Code optimization and quality improvements\n"
        printf "\nOptimizations detected from recent system activity"
        
    } > "$COMMIT_MSG_FILE"
    
else
    echo "No optimization session data found, creating enhanced standard commit message..."
    
    # Check if there are any optimization files in the staging area
    OPTIMIZATION_FILES=$(git diff --cached --name-only | grep -E "(optimize|\.claude)" | head -5 | tr '\n' ' ')
    
    {
        if [ -n "$OPTIMIZATION_FILES" ]; then
            printf "feat: update optimization system\n\n"
            printf "Files: %s\n" "$OPTIMIZATION_FILES"
            printf "Impact: Optimization system maintenance and improvements\n"
        else
            # Fallback to user input for standard commit
            printf "feat: code improvements and updates\n\n"
            printf "Standard commit with optimization system awareness\n"
        fi
        
    } > "$COMMIT_MSG_FILE"
fi

# Validate commit message was created
if [ ! -f "$COMMIT_MSG_FILE" ] || [ ! -s "$COMMIT_MSG_FILE" ]; then
    echo "❌ Failed to generate commit message"
    exit 1
fi

echo "✓ Commit message generated"
```

## Git Integration and Commit Process

Handle git staging, review, and commit with user confirmation:

```bash
echo "Checking git status and staging area..."

# Check for uncommitted changes
if git diff --quiet && git diff --cached --quiet; then
    echo "❌ No changes to commit"
    echo "   Stage your changes with 'git add' before running this command"
    rm -f "$COMMIT_MSG_FILE"
    exit 1
fi

# Show current git status
echo ""
echo "Current git status:"
git status --porcelain

# Check if there are staged changes
STAGED_CHANGES=$(git diff --cached --name-only | wc -l)
UNSTAGED_CHANGES=$(git diff --name-only | wc -l)

echo ""
echo "📊 Changes summary:"
echo "   - Staged files: $STAGED_CHANGES"
echo "   - Unstaged files: $UNSTAGED_CHANGES"

# If there are unstaged changes, offer to stage them
if [ "$UNSTAGED_CHANGES" -gt 0 ] && [ "$STAGED_CHANGES" -eq 0 ]; then
    echo ""
    echo "⚠️  You have unstaged changes but nothing staged for commit"
    echo ""
    echo "Options:"
    echo "1. Stage all changes and commit"
    echo "2. Exit and stage changes manually"
    echo ""
    echo -n "Choose option (1/2): "
    read -r STAGE_OPTION
    
    case "$STAGE_OPTION" in
        1|"")
            echo "Staging all changes..."
            if ! git add .; then
                echo "❌ Failed to stage changes"
                rm -f "$COMMIT_MSG_FILE"
                exit 1
            fi
            echo "✓ All changes staged"
            STAGED_CHANGES=$(git diff --cached --name-only | wc -l)
            ;;
        2)
            echo "Please stage your changes with 'git add' and run this command again"
            rm -f "$COMMIT_MSG_FILE"
            exit 0
            ;;
        *)
            echo "❌ Invalid option"
            rm -f "$COMMIT_MSG_FILE"
            exit 1
            ;;
    esac
fi

# Show the generated commit message for review
echo ""
echo "📝 Generated commit message:"
echo "================================"
cat "$COMMIT_MSG_FILE"
echo "================================"
echo ""

# Offer to edit the commit message
echo "Options:"
echo "1. Use this commit message as-is"
echo "2. Edit the commit message"
echo "3. Enter a completely new commit message"
echo "4. Cancel commit"
echo ""
echo -n "Choose option (1/2/3/4): "
read -r COMMIT_OPTION

case "$COMMIT_OPTION" in
    1|"")
        echo "Using generated commit message..."
        ;;
    2)
        echo "Opening commit message for editing..."
        # Try to use the user's preferred editor
        if [ -n "${EDITOR:-}" ]; then
            "$EDITOR" "$COMMIT_MSG_FILE"
        elif command -v nano >/dev/null 2>&1; then
            nano "$COMMIT_MSG_FILE"
        elif command -v vim >/dev/null 2>&1; then
            vim "$COMMIT_MSG_FILE"
        else
            echo "⚠️  No suitable editor found. Please manually edit:"
            echo "   File: $COMMIT_MSG_FILE"
            echo -n "Press Enter when editing is complete..."
            read -r
        fi
        ;;
    3)
        echo "Enter your commit message (end with Ctrl+D on a blank line):"
        cat > "$COMMIT_MSG_FILE"
        ;;
    4)
        echo "Commit cancelled by user"
        rm -f "$COMMIT_MSG_FILE"
        exit 0
        ;;
    *)
        echo "❌ Invalid option"
        rm -f "$COMMIT_MSG_FILE"
        exit 1
        ;;
esac

# Final validation of commit message
if [ ! -s "$COMMIT_MSG_FILE" ]; then
    echo "❌ Commit message is empty"
    rm -f "$COMMIT_MSG_FILE"
    exit 1
fi

# Perform the commit
echo ""
echo "Committing changes..."
if ! git commit -F "$COMMIT_MSG_FILE"; then
    echo "❌ Git commit failed"
    echo "   The commit message has been saved to: $COMMIT_MSG_FILE"
    echo "   You can retry with: git commit -F $COMMIT_MSG_FILE"
    exit 1
fi

# Get the commit hash for tracking
COMMIT_HASH=$(git rev-parse HEAD)
echo "✅ Commit successful: $COMMIT_HASH"
```

## Update Optimization Session Tracking

Link the git commit back to the optimization session:

```bash
echo "Updating optimization session tracking..."

# Update session file with commit reference if we have an active session
if [ -n "$LATEST_SESSION" ] && [ -n "$LATEST_SESSION_FILE" ] && [ -f "$LATEST_SESSION_FILE" ]; then
    echo "Linking commit to optimization session..."
    
    # Create backup of session file
    SESSION_BACKUP="${LATEST_SESSION_FILE}.backup.$(date +%s)"
    if ! cp "$LATEST_SESSION_FILE" "$SESSION_BACKUP"; then
        echo "⚠️  Warning: Failed to backup session file"
    else
        echo "✓ Session file backed up to: $(basename "$SESSION_BACKUP")"
    fi
    
    # Add commit information to session file
    {
        echo ""
        echo "## Git Commit Information"
        echo "- Commit Hash: $COMMIT_HASH"
        echo "- Commit Date: $(date)"
        echo "- Staged Files: $STAGED_CHANGES files committed"
        if [ -n "$IMPLEMENTED_ISSUES" ]; then
            echo "- Implemented Issues: $IMPLEMENTED_ISSUES"
        fi
        echo ""
        echo "Commit created by /optimize-commit command"
    } >> "$LATEST_SESSION_FILE"
    
    echo "✓ Session file updated with commit reference"
fi

# Create commit tracking file for future reference
COMMIT_TRACKING_FILE=".claude/optimize/decisions/commit_${COMMIT_HASH:0:8}_${LATEST_SESSION:-$(date +%Y%m%d_%H%M%S)}.md"
{
    echo "# Optimization Commit Tracking"
    echo ""
    echo "## Commit Information"
    echo "- **Commit Hash**: $COMMIT_HASH"
    echo "- **Commit Date**: $(date)"
    echo "- **Author**: $(git config user.name) <$(git config user.email)>"
    echo ""
    echo "## Optimization Context"
    if [ -n "$LATEST_SESSION" ]; then
        echo "- **Session ID**: $LATEST_SESSION"
        echo "- **Session File**: $(basename "$LATEST_SESSION_FILE")"
    else
        echo "- **Session ID**: None (standard commit with optimization awareness)"
    fi
    echo ""
    if [ -n "$IMPLEMENTED_ISSUES" ]; then
        echo "## Implemented Issues"
        echo "- **Issues**: $IMPLEMENTED_ISSUES"
        echo "- **Count**: $IMPLEMENT_COUNT implemented"
        if [ -n "$SESSION_COMMENTS" ] && [ "$SESSION_COMMENTS" != "null" ]; then
            echo "- **Comments**: $SESSION_COMMENTS"
        fi
        echo ""
    fi
    echo "## Files Changed"
    git show --name-status "$COMMIT_HASH" | grep -E "^[AMD]" | sed 's/^/- /'
    echo ""
    echo "## Commit Message"
    echo '```'
    git show --format="%B" --no-patch "$COMMIT_HASH"
    echo '```'
    echo ""
    echo "---"
    echo "Generated by /optimize-commit command"
} > "$COMMIT_TRACKING_FILE"

echo "✓ Commit tracking file created: $(basename "$COMMIT_TRACKING_FILE")"

# Cleanup temporary files
rm -f "$COMMIT_MSG_FILE"

# Final summary
echo ""
echo "✅ OPTIMIZATION COMMIT COMPLETE"
echo ""
echo "📊 SUMMARY:"
echo "   • Commit Hash: $COMMIT_HASH"
echo "   • Files Committed: $STAGED_CHANGES"
if [ -n "$LATEST_SESSION" ]; then
    echo "   • Optimization Session: $LATEST_SESSION"
fi
if [ -n "$IMPLEMENTED_ISSUES" ]; then
    echo "   • Issues Implemented: $IMPLEMENTED_ISSUES ($IMPLEMENT_COUNT total)"
fi
echo ""
echo "📁 FILES UPDATED:"
if [ -n "$LATEST_SESSION_FILE" ]; then
    echo "   • Session Record: $(basename "$LATEST_SESSION_FILE")"
fi
echo "   • Commit Tracking: $(basename "$COMMIT_TRACKING_FILE")"
echo ""
echo "🚀 NEXT STEPS:"
echo "   • View commit: git show $COMMIT_HASH"
echo "   • Check status: /optimize-status"
if [ "$GITHUB_COUNT" -gt 0 ] || [ "$DEFER_COUNT" -gt 0 ]; then
    echo "   • Review remaining optimization tasks in system"
fi
if git remote >/dev/null 2>&1; then
    echo "   • Push to remote: git push"
fi
```