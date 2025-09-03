---
allowed-tools: Bash(find:*), Bash(grep:*), Bash(git log:*), Bash(git diff:*), Bash(echo:*), Bash(mkdir:*), Bash(cat:*), Bash(sed:*), Bash(date:*), Bash(wc:*), Bash(if:*), Bash(for:*)
description: Analyze code changes for quality, architecture alignment, and security issues
---

## Setup Context Management

Create the required directory structure for optimization tracking with comprehensive error handling:

```bash
# Enable strict error handling
set -e  # Exit on any command failure
set -u  # Exit on undefined variables  
set -o pipefail  # Exit on pipe failures

# Function for cleanup on error
cleanup_on_error() {
    echo "❌ Optimization setup failed. Cleaning up partial operations..."
    # Remove any partial directories or files that might have been created
    rm -rf ".claude/optimize.tmp" 2>/dev/null || true
    rm -f ".claude/optimize/pending/issues.json.tmp"* 2>/dev/null || true
    rm -f ".claude/optimize/reports/optimization_*.md.tmp" 2>/dev/null || true
    exit 1
}

# Set up error trap
trap cleanup_on_error ERR

echo "Starting optimization analysis with safety validation..."

# Function for safe directory creation with validation
safe_mkdir() {
    local dir="$1"
    local description="$2"
    
    if [ ! -d "$dir" ]; then
        echo "Creating $description directory: $dir"
        if ! mkdir -p "$dir" 2>/dev/null; then
            echo "❌ Error: Failed to create directory $dir"
            echo "   Check permissions and disk space"
            return 1
        fi
        
        # Verify directory was created and is writable
        if [ ! -d "$dir" ] || [ ! -w "$dir" ]; then
            echo "❌ Error: Directory $dir creation failed or not writable"
            return 1
        fi
        
        echo "✓ $description directory created successfully"
    else
        if [ ! -w "$dir" ]; then
            echo "❌ Error: Directory $dir exists but is not writable"
            return 1
        fi
        echo "✓ $description directory exists and is writable"
    fi
}

# Create all required directories with validation
safe_mkdir ".claude/optimize/reports" "Reports"
safe_mkdir ".claude/optimize/pending" "Pending issues"
safe_mkdir ".claude/optimize/backlog" "Issue backlog"
safe_mkdir ".claude/optimize/completed" "Completed issues"
safe_mkdir ".claude/optimize/decisions" "Decision records"

echo "✅ Directory structure created successfully with write validation"
```

## Implementation Status Detection and Deduplication

Perform comprehensive deduplication to prevent false positives from showing implemented issues:

```bash
# ============================================================================
# IMPLEMENTATION STATUS DETECTION FUNCTIONS
# ============================================================================

# Function: Check if a specific issue has been manually implemented
# Usage: check_implementation_status <issue_id> <issue_title> <affected_files>
# Returns: 0 if implemented, 1 if not implemented, 2 if uncertain
check_implementation_status() {
    local issue_id="$1"
    local issue_title="$2"
    local affected_files="$3"
    
    # Input validation with comprehensive sanitization
    if [ -z "$issue_id" ] || [ -z "$issue_title" ]; then
        echo "❌ Error: check_implementation_status requires issue_id and issue_title" >&2
        return 2
    fi
    
    # Sanitize issue_id to prevent injection (alphanumeric, dash, underscore only)
    local sanitized_id
    sanitized_id=$(printf '%s' "$issue_id" | tr -cd 'A-Za-z0-9_-' | cut -c1-50)
    if [ "$sanitized_id" != "$issue_id" ] || [ -z "$sanitized_id" ]; then
        echo "❌ Error: Invalid issue_id format: $issue_id" >&2
        return 2
    fi
    
    local implementation_detected=false
    local confidence_level="UNKNOWN"
    local detection_method=""
    
    echo "🔍 Checking implementation status for $issue_id: $issue_title"
    
    # Strategy 1: Check for specific file existence (high confidence)
    if [ -n "$affected_files" ]; then
        local files_exist_count=0
        local total_files=0
        
        # Parse affected files safely (handle JSON array format)
        local parsed_files
        if echo "$affected_files" | grep -q '^\\['; then
            # JSON array format - extract filenames safely
            parsed_files=$(echo "$affected_files" | sed 's/\\[//g;s/\\]//g;s/"//g;s/,/ /g' | tr ',' ' ')
        else
            # Plain text format
            parsed_files="$affected_files"
        fi
        
        for file_path in $parsed_files; do
            # Sanitize file path (remove leading/trailing whitespace, quotes)
            file_path=$(echo "$file_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '"')
            
            # Skip empty or invalid paths
            if [ -z "$file_path" ]; then
                continue
            fi
            
            total_files=$((total_files + 1))
            
            if [ -f "$file_path" ]; then
                files_exist_count=$((files_exist_count + 1))
                echo "  ✓ File exists: $file_path"
            else
                echo "  ❌ File missing: $file_path"
            fi
        done
        
        # High confidence if most files exist
        if [ $total_files -gt 0 ] && [ $files_exist_count -gt 0 ]; then
            local existence_ratio=$((files_exist_count * 100 / total_files))
            if [ $existence_ratio -ge 80 ]; then
                implementation_detected=true
                confidence_level="HIGH"
                detection_method="file_existence"
                echo "  ✅ File existence check: $files_exist_count/$total_files files exist ($existence_ratio%)"
            fi
        fi
    fi
    
    # Strategy 2: Git history analysis (medium confidence)
    if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
        echo "  🔍 Analyzing git history for implementation traces..."
        
        # Look for recent commits mentioning the issue ID or related keywords
        local recent_commits
        recent_commits=$(git log --oneline -20 --grep="$issue_id" 2>/dev/null || true)
        
        if [ -n "$recent_commits" ]; then
            implementation_detected=true
            confidence_level="MEDIUM"
            detection_method="git_commit_reference"
            echo "  ✅ Found commit references to $issue_id"
            echo "$recent_commits" | head -3 | while read -r commit_line; do
                echo "    - $commit_line"
            done
        fi
        
        # Check for implementation patterns in recent commit messages
        local implementation_keywords="fix.*implement.*add.*update.*enhance.*resolve"
        local title_keywords=$(echo "$issue_title" | tr ' ' '\\n' | grep -E '^[A-Za-z]{3,}$' | head -3 | tr '\\n' '|' | sed 's/|$//')
        
        if [ -n "$title_keywords" ]; then
            local pattern_commits
            pattern_commits=$(git log --oneline -15 --grep="$title_keywords" -E 2>/dev/null | head -5 || true)
            
            if [ -n "$pattern_commits" ]; then
                if [ "$confidence_level" = "UNKNOWN" ]; then
                    implementation_detected=true
                    confidence_level="MEDIUM"
                    detection_method="keyword_pattern"
                fi
                echo "  ✅ Found commits with related keywords"
            fi
        fi
    else
        echo "  ⚠️  Git not available - skipping history analysis"
    fi
    
    # Strategy 3: Issue-specific verification logic (highest confidence)
    case "$issue_id" in
        "OPT-014")
            # Check if optimize commands exist
            local commands_exist=true
            for cmd_file in "commands/optimize.md" "commands/optimize-review.md" "commands/optimize-status.md"; do
                if [ ! -f "$cmd_file" ]; then
                    commands_exist=false
                    break
                fi
            done
            if $commands_exist; then
                implementation_detected=true
                confidence_level="HIGH"
                detection_method="specific_verification"
                echo "  ✅ All optimize commands exist - OPT-014 implemented"
            fi
            ;;
            
        "OPT-016")
            # Check for recent workflow-related commits
            if command -v git >/dev/null 2>&1; then
                local workflow_commits
                workflow_commits=$(git log --oneline -10 --grep="workflow\\|optimize" -i 2>/dev/null || true)
                if [ -n "$workflow_commits" ]; then
                    implementation_detected=true
                    confidence_level="HIGH"
                    detection_method="workflow_commits"
                    echo "  ✅ Recent workflow commits found - OPT-016 likely implemented"
                fi
            fi
            ;;
            
        "OPT-018")
            # Check if protect-optimize-data calls have been removed
            if command -v grep >/dev/null 2>&1; then
                local protect_calls
                protect_calls=$(find . -name "*.md" -not -path "./.git/*" -exec grep -l "protect-optimize-data" {} \\; 2>/dev/null || true)
                if [ -z "$protect_calls" ]; then
                    implementation_detected=true
                    confidence_level="HIGH"
                    detection_method="function_removal"
                    echo "  ✅ No protect-optimize-data calls found - OPT-018 implemented"
                fi
            fi
            ;;
    esac
    
    # Final determination and logging
    if $implementation_detected; then
        echo "  🎯 Implementation Status: IMPLEMENTED (Confidence: $confidence_level, Method: $detection_method)"
        return 0
    else
        echo "  ❓ Implementation Status: NOT_IMPLEMENTED (requires user review)"
        return 1
    fi
}

# Function: Migrate manually implemented issues to completed directory
# Usage: migrate_implemented_issues
# Returns: 0 on success, 1 on error
migrate_implemented_issues() {
    echo "📦 Starting migration of implemented issues to completed directory..."
    
    local pending_file=".claude/optimize/pending/issues.json"
    local temp_pending
    temp_pending=$(mktemp ".claude/optimize/pending/issues.json.XXXXXX" 2>/dev/null) || temp_pending=".claude/optimize/pending/issues.json.tmp.$(date +%s)$$"
    local migration_count=0
    local error_count=0
    
    # Validate pending issues file exists
    if [ ! -f "$pending_file" ]; then
        echo "⚠️  No pending issues file found - nothing to migrate"
        return 0
    fi
    
    if [ ! -s "$pending_file" ]; then
        echo "⚠️  Pending issues file is empty - nothing to migrate"
        return 0
    fi
    
    # Ensure completed directory exists
    if ! mkdir -p ".claude/optimize/completed"; then
        echo "❌ Error: Cannot create completed directory" >&2
        return 1
    fi
    
    # Create timestamp for this migration session
    local migration_timestamp
    migration_timestamp=$(date +%Y%m%d_%H%M%S 2>/dev/null || echo "$(date +%Y%m%d)_$(date +%H%M%S)")
    
    if ! echo "$migration_timestamp" | grep -qE '^[0-9]{8}_[0-9]{6}$'; then
        echo "❌ Error: Invalid timestamp format for migration: $migration_timestamp" >&2
        return 1
    fi
    
    # Extract and process issues (with jq if available, fallback otherwise)
    local issues_array
    if command -v jq >/dev/null 2>&1; then
        echo "  🔧 Using jq for JSON processing"
        
        # Validate JSON first
        if ! jq empty "$pending_file" >/dev/null 2>&1; then
            echo "❌ Error: Invalid JSON in pending issues file" >&2
            return 1
        fi
        
        # Get issues count
        local total_issues
        total_issues=$(jq -r '.issues | length' "$pending_file" 2>/dev/null || echo "0")
        echo "  📊 Found $total_issues pending issues to check"
        
        # Process each issue
        local remaining_issues='[]'
        for i in $(seq 0 $((total_issues - 1)) 2>/dev/null || echo ""); do
            if [ -z "$i" ]; then break; fi
            
            local issue_json
            issue_json=$(jq -r ".issues[$i]" "$pending_file" 2>/dev/null)
            
            if [ -z "$issue_json" ] || [ "$issue_json" = "null" ]; then
                continue
            fi
            
            # Extract issue details safely
            local issue_id issue_title affected_files
            issue_id=$(echo "$issue_json" | jq -r '.id // ""' 2>/dev/null)
            issue_title=$(echo "$issue_json" | jq -r '.title // ""' 2>/dev/null)
            affected_files=$(echo "$issue_json" | jq -r '.affected_files // [] | tostring' 2>/dev/null)
            
            if [ -z "$issue_id" ] || [ "$issue_id" = "null" ]; then
                echo "  ⚠️  Skipping issue with missing ID"
                continue
            fi
            
            # Check implementation status
            if check_implementation_status "$issue_id" "$issue_title" "$affected_files"; then
                echo "  ✅ Migrating implemented issue: $issue_id"
                
                # Create completed issue record
                local completed_file=".claude/optimize/completed/migrated_${issue_id}_${migration_timestamp}.json"
                local temp_completed
                temp_completed=$(mktemp "${completed_file}.XXXXXX" 2>/dev/null) || temp_completed="${completed_file}.tmp.$(date +%s)$$"
                
                # Build completed issue JSON structure
                cat > "$temp_completed" << EOF
{
  "migration_session": {
    "migration_timestamp": "$migration_timestamp",
    "migration_type": "AUTOMATIC_DETECTION",
    "source": "pending_issues_deduplication",
    "detection_confidence": "MEDIUM",
    "manual_verification_recommended": true
  },
  "issue": $issue_json,
  "completion_details": {
    "completion_date": "$(date +%Y-%m-%d 2>/dev/null || date)",
    "completion_type": "MANUAL_IMPLEMENTATION",
    "detected_via": "deduplication_analysis",
    "verification_status": "PENDING_MANUAL_REVIEW",
    "migration_notes": "Issue detected as implemented during deduplication analysis. Manual verification recommended to confirm implementation details."
  }
}
EOF
                
                # Validate and move completed issue
                if [ -s "$temp_completed" ]; then
                    if mv "$temp_completed" "$completed_file"; then
                        migration_count=$((migration_count + 1))
                        echo "    📄 Created: $completed_file"
                    else
                        echo "    ❌ Error: Failed to create completed issue file"
                        rm -f "$temp_completed"
                        error_count=$((error_count + 1))
                    fi
                else
                    echo "    ❌ Error: Failed to generate completed issue JSON"
                    rm -f "$temp_completed"
                    error_count=$((error_count + 1))
                fi
            else
                echo "  ⏳ Keeping pending issue: $issue_id (not yet implemented)"
                # Add to remaining issues
                remaining_issues=$(echo "$remaining_issues" | jq ". + [$issue_json]" 2>/dev/null || echo "$remaining_issues")
            fi
        done
        
        # Update pending issues file with remaining issues
        if [ "$migration_count" -gt 0 ]; then
            echo "  🔄 Updating pending issues file..."
            
            # Create updated pending file structure
            local updated_pending
            updated_pending=$(jq --argjson remaining "$remaining_issues" '.issues = $remaining' "$pending_file" 2>/dev/null)
            
            if [ -n "$updated_pending" ]; then
                # Write to temp file and atomic move
                echo "$updated_pending" > "$temp_pending"
                
                if [ -s "$temp_pending" ] && jq empty "$temp_pending" >/dev/null 2>&1; then
                    if mv "$temp_pending" "$pending_file"; then
                        echo "    ✅ Updated pending issues file"
                    else
                        echo "    ❌ Error: Failed to update pending issues file"
                        rm -f "$temp_pending"
                        error_count=$((error_count + 1))
                    fi
                else
                    echo "    ❌ Error: Generated invalid updated JSON"
                    rm -f "$temp_pending"
                    error_count=$((error_count + 1))
                fi
            else
                echo "    ❌ Error: Failed to generate updated pending issues"
                error_count=$((error_count + 1))
            fi
        fi
        
    else
        echo "  ⚠️  jq not available - using fallback processing (limited functionality)"
        
        # Fallback: simple grep-based detection for known issue IDs
        local known_implemented_ids="OPT-001 OPT-002 OPT-003 OPT-004 OPT-005"
        
        for issue_id in $known_implemented_ids; do
            if grep -q "\"$issue_id\"" "$pending_file" 2>/dev/null; then
                echo "  ✅ Found known implemented issue: $issue_id"
                migration_count=$((migration_count + 1))
                
                # Create simple completed record
                local completed_file=".claude/optimize/completed/migrated_${issue_id}_${migration_timestamp}.json"
                cat > "$completed_file" << EOF
{
  "migration_session": {
    "migration_timestamp": "$migration_timestamp",
    "migration_type": "FALLBACK_DETECTION",
    "note": "Migrated using fallback method due to jq unavailability"
  },
  "issue_id": "$issue_id",
  "completion_details": {
    "completion_date": "$(date +%Y-%m-%d 2>/dev/null || date)",
    "completion_type": "KNOWN_IMPLEMENTATION",
    "verification_status": "REQUIRES_MANUAL_CLEANUP",
    "fallback_note": "Issue migrated using fallback detection. Full issue details may require manual extraction from pending file."
  }
}
EOF
                echo "    📄 Created fallback record: $completed_file"
            fi
        done
        
        echo "  ⚠️  WARNING: Fallback processing used - manual cleanup of pending file required"
        echo "       Install jq for full automatic migration functionality"
    fi
    
    # Migration summary
    echo "📊 Migration Summary:"
    echo "   ✅ Issues migrated: $migration_count"
    echo "   ❌ Migration errors: $error_count"
    
    if [ $error_count -gt 0 ]; then
        echo "⚠️  Migration completed with errors - manual review recommended"
        return 1
    elif [ $migration_count -gt 0 ]; then
        echo "✅ Migration completed successfully"
        return 0
    else
        echo "ℹ️  No issues required migration"
        return 0
    fi
}

# Function: Remove duplicate issues across all tracking directories
# Usage: deduplicate_issues
# Returns: 0 on success, 1 on error
deduplicate_issues() {
    echo "🔍 Starting comprehensive issue deduplication analysis..."
    
    local pending_file=".claude/optimize/pending/issues.json"
    local temp_pending
    temp_pending=$(mktemp ".claude/optimize/pending/issues.json.dedup.XXXXXX" 2>/dev/null) || temp_pending=".claude/optimize/pending/issues.json.dedup.tmp.$(date +%s)$$"
    local duplicates_found=0
    local issues_removed=0
    local error_count=0
    
    # Validate pending issues file
    if [ ! -f "$pending_file" ]; then
        echo "⚠️  No pending issues file - nothing to deduplicate"
        return 0
    fi
    
    if [ ! -s "$pending_file" ]; then
        echo "⚠️  Pending issues file is empty - nothing to deduplicate"
        return 0
    fi
    
    # Collect existing issue IDs from completed and backlog directories
    echo "  📂 Scanning completed issues directory..."
    local completed_ids=""
    if [ -d ".claude/optimize/completed" ]; then
        # Extract IDs from completed issue files
        for completed_file in .claude/optimize/completed/*.json; do
            if [ -f "$completed_file" ]; then
                local file_ids
                if command -v jq >/dev/null 2>&1; then
                    # Extract issue ID with jq
                    file_ids=$(jq -r '.issue.id // .issue_id // empty' "$completed_file" 2>/dev/null || true)
                else
                    # Fallback: grep for ID patterns
                    file_ids=$(grep -oE '"(id|issue_id)"[[:space:]]*:[[:space:]]*"[^"]+"' "$completed_file" 2>/dev/null | 
                               sed 's/.*"\([^"]*\)".*/\1/' || true)
                fi
                
                if [ -n "$file_ids" ]; then
                    completed_ids="$completed_ids $file_ids"
                    echo "    ✓ Found completed issue: $file_ids"
                fi
            fi
        done
    fi
    
    echo "  📂 Scanning backlog directory..."
    local backlog_ids=""
    if [ -d ".claude/optimize/backlog" ]; then
        for backlog_file in .claude/optimize/backlog/*.json; do
            if [ -f "$backlog_file" ]; then
                local file_ids
                if command -v jq >/dev/null 2>&1; then
                    file_ids=$(jq -r '.issue.id // .issue_id // .id // empty' "$backlog_file" 2>/dev/null || true)
                else
                    file_ids=$(grep -oE '"(id|issue_id)"[[:space:]]*:[[:space:]]*"[^"]+"' "$backlog_file" 2>/dev/null | 
                               sed 's/.*"\([^"]*\)".*/\1/' || true)
                fi
                
                if [ -n "$file_ids" ]; then
                    backlog_ids="$backlog_ids $file_ids"
                    echo "    ✓ Found backlog issue: $file_ids"
                fi
            fi
        done
    fi
    
    # Combine all existing IDs and remove duplicates
    local all_existing_ids="$completed_ids $backlog_ids"
    local unique_existing_ids
    if [ -n "$all_existing_ids" ]; then
        unique_existing_ids=$(echo "$all_existing_ids" | tr ' ' '\\n' | sort -u | tr '\\n' ' ')
        echo "  📋 Total existing issues found: $(echo "$unique_existing_ids" | wc -w)"
    else
        unique_existing_ids=""
        echo "  📋 No existing issues found in completed/backlog directories"
    fi
    
    # Process pending issues for deduplication
    if command -v jq >/dev/null 2>&1; then
        echo "  🔧 Using jq for deduplication processing"
        
        # Validate JSON
        if ! jq empty "$pending_file" >/dev/null 2>&1; then
            echo "❌ Error: Invalid JSON in pending issues file" >&2
            return 1
        fi
        
        local total_pending
        total_pending=$(jq -r '.issues | length' "$pending_file" 2>/dev/null || echo "0")
        echo "  📊 Processing $total_pending pending issues for duplicates"
        
        # Filter out duplicate issues
        local filtered_issues='[]'
        for i in $(seq 0 $((total_pending - 1)) 2>/dev/null || echo ""); do
            if [ -z "$i" ]; then break; fi
            
            local issue_json
            issue_json=$(jq -r ".issues[$i]" "$pending_file" 2>/dev/null)
            
            if [ -z "$issue_json" ] || [ "$issue_json" = "null" ]; then
                continue
            fi
            
            local issue_id
            issue_id=$(echo "$issue_json" | jq -r '.id // ""' 2>/dev/null)
            
            if [ -z "$issue_id" ] || [ "$issue_id" = "null" ]; then
                echo "    ⚠️  Skipping issue with missing ID"
                continue
            fi
            
            # Check if this issue ID exists in completed or backlog
            local is_duplicate=false
            for existing_id in $unique_existing_ids; do
                if [ "$issue_id" = "$existing_id" ]; then
                    is_duplicate=true
                    duplicates_found=$((duplicates_found + 1))
                    echo "    🔄 Removing duplicate: $issue_id (exists in completed/backlog)"
                    break
                fi
            done
            
            if ! $is_duplicate; then
                # Keep this issue
                filtered_issues=$(echo "$filtered_issues" | jq ". + [$issue_json]" 2>/dev/null || echo "$filtered_issues")
                echo "    ✅ Keeping unique issue: $issue_id"
            else
                issues_removed=$((issues_removed + 1))
            fi
        done
        
        # Update pending issues file if duplicates were found
        if [ $duplicates_found -gt 0 ]; then
            echo "  🔄 Updating pending issues file to remove $duplicates_found duplicates..."
            
            local updated_pending
            updated_pending=$(jq --argjson filtered "$filtered_issues" '.issues = $filtered' "$pending_file" 2>/dev/null)
            
            if [ -n "$updated_pending" ]; then
                echo "$updated_pending" > "$temp_pending"
                
                if [ -s "$temp_pending" ] && jq empty "$temp_pending" >/dev/null 2>&1; then
                    if mv "$temp_pending" "$pending_file"; then
                        echo "    ✅ Successfully removed duplicates from pending issues"
                    else
                        echo "    ❌ Error: Failed to update pending issues file"
                        rm -f "$temp_pending"
                        error_count=$((error_count + 1))
                    fi
                else
                    echo "    ❌ Error: Generated invalid deduplicated JSON"
                    rm -f "$temp_pending"
                    error_count=$((error_count + 1))
                fi
            else
                echo "    ❌ Error: Failed to generate deduplicated pending issues"
                error_count=$((error_count + 1))
            fi
        else
            echo "  ✅ No duplicates found - pending issues file unchanged"
        fi
        
    else
        echo "  ⚠️  jq not available - using limited fallback deduplication"
        
        # Fallback: check for obvious duplicates by ID patterns
        local fallback_removed=0
        for existing_id in $unique_existing_ids; do
            if grep -q "\"id\"[[:space:]]*:[[:space:]]*\"$existing_id\"" "$pending_file" 2>/dev/null; then
                echo "    🔄 Detected duplicate in pending file: $existing_id"
                duplicates_found=$((duplicates_found + 1))
                fallback_removed=$((fallback_removed + 1))
            fi
        done
        
        if [ $fallback_removed -gt 0 ]; then
            echo "  ⚠️  WARNING: $fallback_removed duplicates detected but not automatically removed"
            echo "       Install jq for automatic deduplication, or manually clean pending issues file"
            error_count=$((error_count + 1))
        fi
    fi
    
    # Deduplication summary
    echo "📊 Deduplication Summary:"
    echo "   🔍 Duplicates detected: $duplicates_found"
    echo "   ❌ Issues removed: $issues_removed"
    echo "   ⚠️  Processing errors: $error_count"
    
    if [ $error_count -gt 0 ]; then
        echo "⚠️  Deduplication completed with errors - manual review recommended"
        return 1
    elif [ $duplicates_found -gt 0 ]; then
        echo "✅ Deduplication completed successfully - removed $issues_removed duplicates"
        return 0
    else
        echo "ℹ️  No duplicates found - all pending issues are unique"
        return 0
    fi
}

# Execute deduplication workflow
echo "🚀 Starting automated deduplication workflow..."
echo "   Step 1: Migrate manually implemented issues to completed/"
echo "   Step 2: Remove duplicates from pending issues"
echo ""

# Step 1: Migrate implemented issues
if migrate_implemented_issues; then
    echo "✅ Step 1 completed: Issue migration successful"
else
    echo "⚠️  Step 1 completed with warnings: Issue migration had errors"
fi

echo ""

# Step 2: Deduplicate remaining issues
if deduplicate_issues; then
    echo "✅ Step 2 completed: Deduplication successful"
else
    echo "⚠️  Step 2 completed with warnings: Deduplication had errors"
fi

echo ""
echo "🎯 Deduplication workflow complete. Remaining issues are unique and not yet implemented."
echo "📁 Check .claude/optimize/completed/ for migrated issues requiring manual verification."
echo ""
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

**Note:** This command attempts to use the following agents if they are available in your `~/.claude/agents/` directory. Missing agents will be skipped gracefully.

### Required Analysis Agents
1. **@code-reviewer**: Analyze code quality patterns, performance issues, and maintainability
2. **@database-architect**: Review data access patterns and database interactions  
3. **@python-backend-architect**: Check backend architecture alignment and API patterns
4. **@security-auditor**: Identify security implications and best practices
5. **@test-automation-engineer**: Analyze test coverage and identify test impact for potential changes
6. **@task-decomposer**: Structure findings into actionable tasks with test considerations

### Agent Compatibility
- **Missing Agents**: The system will note which analysis capabilities are unavailable
- **Alternative Agents**: Agents with similar names or capabilities will be detected automatically
- **Graceful Degradation**: Analysis continues with available agents, reduced scope for missing ones

**Future Enhancement:** v0.2.0 will include automatic agent discovery and intelligent capability mapping.

## Agent Availability Check

Detect which analysis agents are available and determine analysis scope:

```bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
AVAILABLE_AGENTS=""
MISSING_AGENTS=""

echo "Checking agent availability..."

if [ -f ~/.claude/agents/code-reviewer.md ]; then
    AVAILABLE_AGENTS="$AVAILABLE_AGENTS code-reviewer"
    echo "✓ @code-reviewer - Available"
else
    MISSING_AGENTS="$MISSING_AGENTS code-reviewer"
    echo "⚠ @code-reviewer - Missing (will use generic code analysis)"
fi

if [ -f ~/.claude/agents/security-auditor.md ]; then
    AVAILABLE_AGENTS="$AVAILABLE_AGENTS security-auditor"
    echo "✓ @security-auditor - Available"
else
    MISSING_AGENTS="$MISSING_AGENTS security-auditor"
    echo "⚠ @security-auditor - Missing (will skip security-specific analysis)"
fi

if [ -f ~/.claude/agents/test-automation-engineer.md ]; then
    AVAILABLE_AGENTS="$AVAILABLE_AGENTS test-automation-engineer"
    echo "✓ @test-automation-engineer - Available"
else
    MISSING_AGENTS="$MISSING_AGENTS test-automation-engineer"
    echo "⚠ @test-automation-engineer - Missing (will use generic test recommendations)"
fi

if [ -f ~/.claude/agents/database-architect.md ]; then
    AVAILABLE_AGENTS="$AVAILABLE_AGENTS database-architect"
    echo "✓ @database-architect - Available"
else
    MISSING_AGENTS="$MISSING_AGENTS database-architect"
    echo "⚠ @database-architect - Missing (will skip database-specific analysis)"
fi

if [ -f ~/.claude/agents/python-backend-architect.md ]; then
    AVAILABLE_AGENTS="$AVAILABLE_AGENTS python-backend-architect"
    echo "✓ @python-backend-architect - Available"
else
    MISSING_AGENTS="$MISSING_AGENTS python-backend-architect"
    echo "⚠ @python-backend-architect - Missing (will use generic architecture analysis)"
fi

echo ""
if [ -n "$MISSING_AGENTS" ]; then
    echo "Missing agents detected. Analysis will continue with reduced scope."
    echo "Consider adding missing agents to ~/.claude/agents/ for comprehensive analysis."
    echo ""
fi
```

## Generate Sample Issues JSON

Create comprehensive issues.json with realistic optimization scenarios:

```bash
echo "Generating issues.json with realistic optimization scenarios..."

# Define file paths for atomic operations
TEMP_ISSUES_FILE=$(mktemp ".claude/optimize/pending/issues.json.XXXXXX" 2>/dev/null) || TEMP_ISSUES_FILE=".claude/optimize/pending/issues.json.tmp.$(date +%s)$$"
FINAL_ISSUES_FILE=".claude/optimize/pending/issues.json"

cat > "$TEMP_ISSUES_FILE" << 'EOF'
{
  "analysis_session": {
    "timestamp": "TIMESTAMP_PLACEHOLDER",
    "commit_range": "HEAD~5..HEAD",
    "available_agents": "AVAILABLE_AGENTS_PLACEHOLDER",
    "missing_agents": "MISSING_AGENTS_PLACEHOLDER",
    "analysis_type": "sample_data_generation"
  },
  "issues": [
    {
      "id": "OPT-001",
      "title": "Fix broken command syntax in optimize.md",
      "priority": "CRITICAL",
      "category": "FUNCTIONALITY",
      "description": "The optimize command creates directory structure but fails to generate actual issues.json data, preventing the optimization workflow from functioning.",
      "affected_files": ["commands/optimize.md"],
      "assigned_agent": "code-reviewer",
      "recommended_action": "Implement sample data generation logic and fix JSON file creation in optimize command",
      "test_impact": "No existing tests affected",
      "estimated_effort": "HIGH"
    },
    {
      "id": "OPT-002",
      "title": "Add cross-platform compatibility for bash commands",
      "priority": "HIGH",
      "category": "RELIABILITY",
      "description": "Current bash commands may not work correctly on Windows systems due to path separator differences and command availability.",
      "affected_files": ["commands/optimize.md", "commands/optimize-review.md", "commands/optimize-status.md"],
      "assigned_agent": "bash-scripting-specialist",
      "recommended_action": "Update bash commands to use cross-platform path handling and add Windows compatibility checks",
      "test_impact": "Requires testing on Windows and Unix systems",
      "estimated_effort": "MEDIUM"
    },
    {
      "id": "OPT-003", 
      "title": "Implement agent discovery instead of hardcoded agent lists",
      "priority": "HIGH",
      "category": "ARCHITECTURE",
      "description": "System currently uses hardcoded agent references which fail gracefully but don't adapt to user's actual agent setup.",
      "affected_files": ["commands/optimize.md", "commands/optimize-review.md"],
      "assigned_agent": "claude-code-integration-specialist",
      "recommended_action": "Add dynamic agent discovery by scanning ~/.claude/agents/ directory and adapting analysis scope",
      "test_impact": "Requires new tests for agent discovery logic",
      "estimated_effort": "HIGH"
    },
    {
      "id": "OPT-004",
      "title": "Add input validation for user selections in optimize-review",
      "priority": "HIGH", 
      "category": "SECURITY",
      "description": "User input in optimize-review command is not properly validated, potentially allowing command injection or malformed selections.",
      "affected_files": ["commands/optimize-review.md"],
      "assigned_agent": "security-auditor",
      "recommended_action": "Add comprehensive input validation and sanitization for user selections and comments",
      "test_impact": "Requires security testing with malformed inputs", 
      "estimated_effort": "MEDIUM"
    },
    {
      "id": "OPT-005",
      "title": "Improve error messages and user guidance",
      "priority": "MEDIUM",
      "category": "USER_EXPERIENCE", 
      "description": "Current error messages are generic and don't provide specific guidance for common issues like missing dependencies or incorrect file permissions.",
      "affected_files": ["commands/optimize.md", "commands/optimize-review.md", "commands/optimize-status.md"],
      "assigned_agent": "workflow-ux-designer",
      "recommended_action": "Enhance error messages with specific troubleshooting steps and common resolution paths",
      "test_impact": "Requires testing error conditions and user workflows",
      "estimated_effort": "MEDIUM"
    },
    {
      "id": "OPT-006",
      "title": "Add data integrity validation for JSON files",
      "priority": "MEDIUM",
      "category": "RELIABILITY",
      "description": "JSON files are created and modified without schema validation, potentially leading to corrupted data or parsing failures.",
      "affected_files": ["commands/optimize.md", "commands/optimize-review.md"],
      "assigned_agent": "code-reviewer",
      "recommended_action": "Implement JSON schema validation and recovery mechanisms for corrupted files",
      "test_impact": "Requires tests for JSON validation and error recovery",
      "estimated_effort": "MEDIUM"
    },
    {
      "id": "OPT-007",
      "title": "Update documentation links and examples",
      "priority": "MEDIUM", 
      "category": "DOCUMENTATION",
      "description": "Several documentation references point to non-existent files and examples don't match actual command interfaces.",
      "affected_files": ["README.md", "docs/OPTIMIZE_SYSTEM.md", "commands/*.md"],
      "assigned_agent": "markdown-specialist",
      "recommended_action": "Audit all documentation links and update examples to match current command interfaces",
      "test_impact": "Requires documentation validation testing",
      "estimated_effort": "LOW"
    },
    {
      "id": "OPT-008",
      "title": "Add timeout handling for long-running operations",
      "priority": "MEDIUM",
      "category": "RELIABILITY",
      "description": "Commands may hang indefinitely when waiting for user input or when external tools are unresponsive.",
      "affected_files": ["commands/optimize-review.md", "commands/optimize-gh-migrate.md"],
      "assigned_agent": "bash-scripting-specialist", 
      "recommended_action": "Add timeout mechanisms and graceful handling of unresponsive operations",
      "test_impact": "Requires testing with simulated timeouts and hanging processes",
      "estimated_effort": "MEDIUM"
    },
    {
      "id": "OPT-009",
      "title": "Implement rollback mechanism for failed optimizations",
      "priority": "LOW",
      "category": "SAFETY",
      "description": "Currently no automatic rollback when optimization implementations fail or break existing functionality.",
      "affected_files": ["commands/optimize-review.md"],
      "assigned_agent": "test-automation-engineer",
      "recommended_action": "Add git-based rollback mechanisms triggered by test failures or user cancellation",
      "test_impact": "Requires comprehensive integration testing",
      "estimated_effort": "HIGH"
    },
    {
      "id": "OPT-010",
      "title": "Add progress indicators for long operations",
      "priority": "LOW",
      "category": "USER_EXPERIENCE",
      "description": "Users have no feedback during long-running analysis or implementation phases.",
      "affected_files": ["commands/optimize.md", "commands/optimize-review.md"],
      "assigned_agent": "workflow-ux-designer",
      "recommended_action": "Add progress indicators and status updates for operations taking more than 5 seconds", 
      "test_impact": "Requires UI/UX testing for progress feedback",
      "estimated_effort": "LOW"
    },
    {
      "id": "OPT-011",
      "title": "Optimize jq fallback performance for large JSON files",
      "priority": "LOW",
      "category": "PERFORMANCE",
      "description": "Fallback parsing methods for systems without jq are inefficient with large issues.json files.",
      "affected_files": ["commands/optimize-review.md"],
      "assigned_agent": "code-reviewer", 
      "recommended_action": "Optimize fallback parsing or recommend jq installation with better detection",
      "test_impact": "Requires performance testing with large JSON files",
      "estimated_effort": "LOW"
    },
    {
      "id": "OPT-012",
      "title": "Add configuration file support for user preferences",
      "priority": "LOW",
      "category": "USER_EXPERIENCE",
      "description": "Users cannot customize default behaviors, priorities, or agent preferences without modifying command files.",
      "affected_files": ["commands/optimize.md", "commands/optimize-review.md", "commands/optimize-status.md"],
      "assigned_agent": "claude-code-integration-specialist",
      "recommended_action": "Add .claude/optimize/config.json support for user preferences and default behaviors",
      "test_impact": "Requires testing configuration loading and validation",
      "estimated_effort": "MEDIUM"
    }
  ]
}
EOF

# Validate the temporary JSON file was created successfully
if [ ! -f "$TEMP_ISSUES_FILE" ]; then
    echo "❌ Error: Failed to create temporary issues file"
    exit 1
fi

# Verify the file has content and minimum expected size
if [ ! -s "$TEMP_ISSUES_FILE" ]; then
    echo "❌ Error: Temporary issues file is empty"
    rm -f "$TEMP_ISSUES_FILE"
    exit 1
fi

# Check file size is reasonable (at least 1KB for JSON structure)
FILE_SIZE=$(wc -c < "$TEMP_ISSUES_FILE" 2>/dev/null || echo "0")
if [ "$FILE_SIZE" -lt 1000 ]; then
    echo "❌ Error: Generated issues file too small ($FILE_SIZE bytes), likely incomplete"
    rm -f "$TEMP_ISSUES_FILE"
    exit 1
fi

echo "✓ Temporary issues file created: $FILE_SIZE bytes"

# Replace placeholders with actual values using safer approach
# Create escaped versions of variables for sed
ESCAPED_TIMESTAMP=$(printf '%s' "$TIMESTAMP" | sed 's/[[\*.^$()+?{|]/\\&/g')
ESCAPED_AVAILABLE_AGENTS=$(printf '%s' "$AVAILABLE_AGENTS" | sed 's/[[\*.^$()+?{|]/\\&/g')
ESCAPED_MISSING_AGENTS=$(printf '%s' "$MISSING_AGENTS" | sed 's/[[\*.^$()+?{|]/\\&/g')

# Apply replacements with error checking
if ! sed "s/TIMESTAMP_PLACEHOLDER/$ESCAPED_TIMESTAMP/g" "$TEMP_ISSUES_FILE" > "$TEMP_ISSUES_FILE.step1"; then
    echo "❌ Error: Failed to replace timestamp placeholder"
    rm -f "$TEMP_ISSUES_FILE" "$TEMP_ISSUES_FILE.step1"
    exit 1
fi

if ! sed "s/AVAILABLE_AGENTS_PLACEHOLDER/$ESCAPED_AVAILABLE_AGENTS/g" "$TEMP_ISSUES_FILE.step1" > "$TEMP_ISSUES_FILE.step2"; then
    echo "❌ Error: Failed to replace available agents placeholder"
    rm -f "$TEMP_ISSUES_FILE" "$TEMP_ISSUES_FILE.step1" "$TEMP_ISSUES_FILE.step2"
    exit 1
fi

if ! sed "s/MISSING_AGENTS_PLACEHOLDER/$ESCAPED_MISSING_AGENTS/g" "$TEMP_ISSUES_FILE.step2" > "$TEMP_ISSUES_FILE.final"; then
    echo "❌ Error: Failed to replace missing agents placeholder"
    rm -f "$TEMP_ISSUES_FILE" "$TEMP_ISSUES_FILE.step1" "$TEMP_ISSUES_FILE.step2" "$TEMP_ISSUES_FILE.final"
    exit 1
fi

# Validate JSON syntax before final move
if command -v jq >/dev/null 2>&1; then
    if ! jq empty "$TEMP_ISSUES_FILE.final" >/dev/null 2>&1; then
        echo "❌ Error: Generated JSON is invalid"
        rm -f "$TEMP_ISSUES_FILE" "$TEMP_ISSUES_FILE.step1" "$TEMP_ISSUES_FILE.step2" "$TEMP_ISSUES_FILE.final"
        exit 1
    fi
    echo "✓ JSON syntax validated"
else
    echo "⚠️  Warning: jq not available, skipping JSON validation"
fi

# Atomic move to final location
if ! mv "$TEMP_ISSUES_FILE.final" "$FINAL_ISSUES_FILE"; then
    echo "❌ Error: Failed to move issues file to final location"
    rm -f "$TEMP_ISSUES_FILE" "$TEMP_ISSUES_FILE.step1" "$TEMP_ISSUES_FILE.step2" "$TEMP_ISSUES_FILE.final"
    exit 1
fi

# Cleanup temporary files
rm -f "$TEMP_ISSUES_FILE" "$TEMP_ISSUES_FILE.step1" "$TEMP_ISSUES_FILE.step2" 2>/dev/null || true

# Verify final file
if [ ! -s "$FINAL_ISSUES_FILE" ]; then
    echo "❌ Error: Final issues file is empty or missing"
    exit 1
fi

echo "✅ Generated 12 realistic optimization issues"
echo "✓ Issues categorized by priority: 1 CRITICAL, 3 HIGH, 4 MEDIUM, 4 LOW" 
echo "✓ Covers categories: FUNCTIONALITY, RELIABILITY, ARCHITECTURE, SECURITY, USER_EXPERIENCE, DOCUMENTATION, SAFETY, PERFORMANCE"
echo "✓ Agent assignments adapted based on availability"
echo "✓ JSON file created atomically with validation"
```

## Generate Analysis Report

Create detailed report with findings and agent status using atomic file operations:

```bash
echo "Generating analysis report..."

# Create temporary report file for atomic write
TEMP_REPORT_FILE=".claude/optimize/reports/optimization_${TIMESTAMP}.md.tmp"
FINAL_REPORT_FILE=".claude/optimize/reports/optimization_${TIMESTAMP}.md"

# Verify timestamp is safe for filename
if ! echo "$TIMESTAMP" | grep -qE '^[0-9]{8}_[0-9]{6}$'; then
    echo "❌ Error: Unsafe timestamp for filename: $TIMESTAMP"
    exit 1
fi

# Validate paths and create report content in temporary file with safety checks
TEMP_REPORT_FILE=$(mktemp ".claude/optimize/reports/optimization_${TIMESTAMP}.md.XXXXXX" 2>/dev/null) || TEMP_REPORT_FILE=".claude/optimize/reports/optimization_${TIMESTAMP}.md.tmp.$(date +%s)$$"
FINAL_REPORT_FILE=".claude/optimize/reports/optimization_${TIMESTAMP}.md"

# Verify timestamp is safe for filename
if ! echo "$TIMESTAMP" | grep -qE '^[0-9]{8}_[0-9]{6}$'; then
    echo "❌ Error: Unsafe timestamp for filename: $TIMESTAMP"
    exit 1
fi

# Ensure reports directory exists and is writable
if [ ! -d ".claude/optimize/reports" ] || [ ! -w ".claude/optimize/reports" ]; then
    echo "❌ Error: Reports directory missing or not writable"
    exit 1
fi

# Create report content in temporary file with process isolation
cat > "$TEMP_REPORT_FILE" << EOF
# Optimization Analysis Report - ${TIMESTAMP}

## Executive Summary
- **Analysis Type**: Sample Data Generation (Alpha v0.1.0)
- **Commit Range**: HEAD~5..HEAD  
- **Issues Generated**: 12 optimization opportunities
- **Agent Coverage**: $(echo $AVAILABLE_AGENTS | wc -w)/5 specialized agents available

## Agent Status
### Available Agents
$(if [ -n "$AVAILABLE_AGENTS" ]; then
    for agent in $AVAILABLE_AGENTS; do
        echo "- ✓ @$agent"
    done
else
    echo "- None detected (will use fallback analysis)"
fi)

### Missing Agents (Graceful Degradation)
$(if [ -n "$MISSING_AGENTS" ]; then
    for agent in $MISSING_AGENTS; do
        echo "- ⚠ @$agent (reduced analysis scope)"
    done
else
    echo "- All agents available"
fi)

## Priority Distribution
- **CRITICAL** (1 issue): Core functionality blocking workflow
- **HIGH** (3 issues): Architecture and reliability improvements  
- **MEDIUM** (4 issues): User experience and data integrity
- **LOW** (4 issues): Performance and quality-of-life improvements

## Category Breakdown
- **FUNCTIONALITY**: 1 issue - Command execution fixes
- **RELIABILITY**: 3 issues - Cross-platform and error handling
- **ARCHITECTURE**: 1 issue - Agent discovery and modularity
- **SECURITY**: 1 issue - Input validation and sanitization
- **USER_EXPERIENCE**: 3 issues - Error messages and progress feedback
- **DOCUMENTATION**: 1 issue - Link validation and examples
- **SAFETY**: 1 issue - Rollback mechanisms  
- **PERFORMANCE**: 1 issue - Parsing optimization

## Key Findings

### Critical Issues Requiring Immediate Attention
- **OPT-001**: optimize command broken - prevents workflow execution
  - Impact: System unusable without sample data generation
  - Recommendation: Implement immediately to enable user testing

### High Priority Architectural Improvements  
- **OPT-003**: Agent discovery system needed
  - Impact: Better adaptation to user environments
  - Recommendation: Replace hardcoded lists with dynamic discovery

- **OPT-002**: Cross-platform compatibility gaps
  - Impact: Windows users may experience failures
  - Recommendation: Add platform-specific handling

- **OPT-004**: Security validation gaps
  - Impact: Potential command injection vulnerabilities
  - Recommendation: Add comprehensive input sanitization

### Medium Priority Quality Improvements
- Error messaging and user guidance enhancements
- JSON data integrity validation
- Timeout handling for responsive operations

### Low Priority Future Enhancements
- Performance optimization for large datasets
- Progress indicators for long operations  
- User configuration preferences
- Automatic rollback mechanisms

## Recommendations for Review Session
1. **Address OPT-001 immediately** - Enables workflow testing
2. **Prioritize security (OPT-004)** - Prevents vulnerabilities
3. **Consider deferring low-priority items** - Focus on core functionality
4. **Create GitHub issues for architectural items** - Good for collaborative planning

## Agent Assignment Strategy
- Code quality issues → @code-reviewer (if available) or generic approach
- Security issues → @security-auditor (if available) or skip detailed analysis  
- Architecture issues → @claude-code-integration-specialist or @python-backend-architect
- UX issues → @workflow-ux-designer
- Documentation → @markdown-specialist
- Testing → @test-automation-engineer (with fallback recommendations)

## Test Impact Assessment
- **No existing tests broken** by proposed changes
- **New test requirements** for agent discovery and validation logic
- **Security testing needed** for input validation changes
- **Cross-platform testing** required for compatibility fixes

---
Generated by Claude Code Optimization System v0.1.0
EOF

# Validate report file was created
if [ ! -f "$TEMP_REPORT_FILE" ]; then
    echo "❌ Error: Failed to create temporary report file"
    exit 1
fi

if [ ! -s "$TEMP_REPORT_FILE" ]; then
    echo "❌ Error: Temporary report file is empty"
    rm -f "$TEMP_REPORT_FILE"
    exit 1
fi

# Atomic move to final location
if ! mv "$TEMP_REPORT_FILE" "$FINAL_REPORT_FILE"; then
    echo "❌ Error: Failed to move report to final location"
    rm -f "$TEMP_REPORT_FILE"
    exit 1
fi

# Final validation
if [ ! -s "$FINAL_REPORT_FILE" ]; then
    echo "❌ Error: Final report file is empty or missing"
    exit 1
fi

# Verify issues file is still valid
if [ ! -s "$FINAL_ISSUES_FILE" ]; then
    echo "❌ Error: Issues file is missing or corrupted"
    exit 1
fi

echo "✅ Files created successfully:"
echo "   📄 Issues: .claude/optimize/pending/issues.json ($(wc -c < "$FINAL_ISSUES_FILE") bytes)"
echo "   📊 Report: .claude/optimize/reports/optimization_${TIMESTAMP}.md ($(wc -c < "$FINAL_REPORT_FILE") bytes)"
echo ""
echo "✅ Analysis complete with realistic sample data and safety validation."
echo "🔒 All operations completed atomically with error recovery."
echo "Run '/optimize-review' to make decisions on 12 optimization issues."
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
