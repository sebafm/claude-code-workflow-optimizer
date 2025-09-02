---
allowed-tools: Bash(find:*), Bash(wc:*), Bash(ls:*), Bash(cat:*)
description: Show overview of optimization issue status across all categories
---

## System Status Overview

Display comprehensive status of the optimization system with error handling:

```bash
# Enable strict error handling
set -e  # Exit on any command failure
set -u  # Exit on undefined variables
set -o pipefail  # Exit on pipe failures

# Function for cleanup on error
cleanup_on_error() {
    echo "❌ Status check failed. System state may be inconsistent."
    echo "   Check file permissions and disk space"
    exit 1
}

# Set up error trap
trap cleanup_on_error ERR

# Function for safe file counting with comprehensive validation
safe_count_files() {
    local dir="$1"
    local pattern="$2"
    local description="$3"
    
    # Input validation
    if [ -z "$dir" ] || [ -z "$pattern" ] || [ -z "$description" ]; then
        echo "❌ Error: Missing parameters for safe_count_files"
        echo "0"
        return 1
    fi
    
    # Directory existence check
    if [ ! -e "$dir" ]; then
        echo "0  # Directory $dir does not exist"
        return 0
    fi
    
    if [ ! -d "$dir" ]; then
        echo "❌ Warning: Path $dir exists but is not a directory"
        echo "0"
        return 0
    fi
    
    # Permission checks
    if [ ! -r "$dir" ]; then
        echo "❌ Warning: Cannot read directory $dir (permission denied)"
        echo "0"
        return 0
    fi
    
    # Safe file counting with multiple validation layers
    local count temp_count
    
    # Primary count method
    if ! count=$(find "$dir" -maxdepth 2 -name "$pattern" -type f 2>/dev/null | wc -l); then
        echo "❌ Warning: Failed to count files in $dir"
        echo "0"
        return 0
    fi
    
    # Validate count is a number
    if ! echo "$count" | grep -qE '^[0-9]+$'; then
        echo "❌ Warning: Invalid count result for $description"
        echo "0"
        return 0
    fi
    
    # Sanity check: count should be reasonable (less than 10000 files)
    if [ "$count" -gt 10000 ]; then
        echo "❌ Warning: Unusually high file count ($count) for $description"
        echo "   This may indicate a system issue or runaway process"
        # Still return the count but warn the user
    fi
    
    echo "$count"
    return 0
}

echo "OPTIMIZATION SYSTEM STATUS"
echo "=========================="
echo ""

# Comprehensive system initialization check
echo "Validating optimization system initialization..."

if [ ! -e ".claude" ]; then
    echo "❌ Claude Code directory not found"
    echo "   This command must be run from the root of a Claude Code project"
    echo "   Expected: .claude/ directory in current working directory"
    exit 1
fi

if [ ! -d ".claude" ]; then
    echo "❌ .claude exists but is not a directory"
    echo "   Please check your Claude Code project structure"
    exit 1
fi

if [ ! -r ".claude" ]; then
    echo "❌ Cannot read .claude directory (permission denied)"
    echo "   Check file permissions for the .claude directory"
    exit 1
fi

if [ ! -d ".claude/optimize" ]; then
    echo "❌ Optimization system not initialized"
    echo "   Run '/optimize' to set up the optimization workflow"
    echo "   This will create the required directory structure"
    echo ""
    exit 1
fi

if [ ! -w ".claude/optimize" ]; then
    echo "❌ Optimization directory exists but is not writable"
    echo "   Check file permissions for .claude/optimize"
    exit 1
fi

echo "✓ Optimization system initialized and accessible"

echo "Collecting system status with safety validation..."

# Count files with error handling
PENDING=$(safe_count_files ".claude/optimize/pending" "*.json" "pending issues")
BACKLOG=$(safe_count_files ".claude/optimize/backlog" "*.json" "backlog issues")
COMPLETED=$(safe_count_files ".claude/optimize/completed" "*.json" "completed issues")
DECISIONS=$(safe_count_files ".claude/optimize/decisions" "*.md" "decision records")

# Display status with validation
echo "📋 PENDING: ${PENDING} issues waiting for review"
echo "⏸️  DEFERRED: ${BACKLOG} issues in backlog"
echo "✅ COMPLETED: ${COMPLETED} issues implemented/skipped"
echo "📝 DECISIONS: ${DECISIONS} review sessions recorded"

# Calculate totals for validation
TOTAL_ISSUES=$((PENDING + BACKLOG + COMPLETED))
if [ "$TOTAL_ISSUES" -eq 0 ]; then
    echo ""
    echo "ℹ️  No optimization issues found in system"
    echo "   This may indicate the system is newly initialized"
else
    echo "📊 TOTAL ISSUES TRACKED: ${TOTAL_ISSUES}"
fi

echo ""

echo "RECENT ACTIVITY:"
echo "==============="

# Safe listing of recent reports with comprehensive error handling
echo "Checking recent reports..."
if [ -d ".claude/optimize/reports" ] && [ -r ".claude/optimize/reports" ]; then
    # Use safer counting method
    REPORT_COUNT=$(safe_count_files ".claude/optimize/reports" "*.md" "analysis reports")
    
    if [ "$REPORT_COUNT" -gt 0 ]; then
        echo "Latest reports ($REPORT_COUNT total):"
        
        # Cross-platform compatible file listing
        if command -v stat >/dev/null 2>&1; then
            # Use stat for more reliable sorting on different platforms
            find .claude/optimize/reports -name "*.md" -type f 2>/dev/null | \
                head -10 | \
                while IFS= read -r file; do
                    if [ -f "$file" ] && [ -r "$file" ]; then
                        # Safe basename extraction
                        filename=$(basename "$file" 2>/dev/null || echo "unknown")
                        if [ "$filename" != "unknown" ]; then
                            echo "  - $filename"
                        fi
                    fi
                done | head -3
        else
            # Fallback method without stat
            find .claude/optimize/reports -name "*.md" -type f 2>/dev/null | \
                head -3 | \
                while IFS= read -r file; do
                    if [ -f "$file" ] && [ -r "$file" ]; then
                        filename=$(basename "$file" 2>/dev/null || echo "unknown")
                        if [ "$filename" != "unknown" ]; then
                            echo "  - $filename"
                        fi
                    fi
                done
        fi
    else
        echo "No reports found"
    fi
else
    if [ ! -d ".claude/optimize/reports" ]; then
        echo "Reports directory does not exist (this is normal for new installations)"
    else
        echo "Reports directory not accessible (check permissions)"
    fi
fi
echo ""

# Safe listing of recent decisions with comprehensive error handling
echo "Checking recent decisions..."
if [ -d ".claude/optimize/decisions" ] && [ -r ".claude/optimize/decisions" ]; then
    # Use safer counting method
    DECISION_COUNT=$(safe_count_files ".claude/optimize/decisions" "*.md" "decision records")
    
    if [ "$DECISION_COUNT" -gt 0 ]; then
        echo "Recent decisions ($DECISION_COUNT total):"
        
        # Cross-platform compatible file listing
        if command -v stat >/dev/null 2>&1; then
            # Use stat for more reliable sorting on different platforms
            find .claude/optimize/decisions -name "*.md" -type f 2>/dev/null | \
                head -10 | \
                while IFS= read -r file; do
                    if [ -f "$file" ] && [ -r "$file" ]; then
                        # Safe basename extraction
                        filename=$(basename "$file" 2>/dev/null || echo "unknown")
                        if [ "$filename" != "unknown" ]; then
                            echo "  - $filename"
                        fi
                    fi
                done | head -3
        else
            # Fallback method without stat
            find .claude/optimize/decisions -name "*.md" -type f 2>/dev/null | \
                head -3 | \
                while IFS= read -r file; do
                    if [ -f "$file" ] && [ -r "$file" ]; then
                        filename=$(basename "$file" 2>/dev/null || echo "unknown")
                        if [ "$filename" != "unknown" ]; then
                            echo "  - $filename"
                        fi
                    fi
                done
        fi
    else
        echo "No decision records found"
    fi
else
    if [ ! -d ".claude/optimize/decisions" ]; then
        echo "Decisions directory does not exist (this is normal for new installations)"
    else
        echo "Decisions directory not accessible (check permissions)"
    fi
fi
echo ""

# Provide intelligent next steps based on system state
echo "RECOMMENDED ACTIONS:"
echo "==================="

if [ "$PENDING" -gt 0 ]; then
    echo "🚀 NEXT STEPS: Run '/optimize-review' to process $PENDING pending issues"
    if [ "$PENDING" -gt 10 ]; then
        echo "   ⚠️  Large number of pending issues - consider batch processing"
    fi
elif [ "$BACKLOG" -gt 0 ]; then
    echo "🚀 NEXT STEPS: Choose from these options:"
    echo "   1. Run '/optimize' to include backlog issues in new analysis"
    echo "   2. Run '/optimize-gh-migrate' to convert backlog to GitHub issues"
    echo "   3. Review backlog files manually in .claude/optimize/backlog/"
elif [ "$TOTAL_ISSUES" -eq 0 ]; then
    echo "🚀 NEXT STEPS: Run '/optimize' to analyze recent code changes"
    echo "   This will scan your repository for optimization opportunities"
else
    echo "🚀 NEXT STEPS: System appears to be up to date"
    echo "   Run '/optimize' when you have new code changes to analyze"
fi
echo ""

echo "QUICK COMMANDS:"
echo "==============="
echo "Core Operations:"
echo "  /optimize              - Analyze recent code changes for optimization opportunities"
echo "  /optimize-review       - Review and decide on pending optimization issues"
echo "  /optimize-status       - Show this status overview"
echo ""
echo "Advanced Operations:"
echo "  /optimize-gh-migrate   - Convert backlog issues to GitHub issues"
echo ""
echo "Manual Operations:"
if [ -f ".claude/optimize/pending/commands.sh" ]; then
    echo "  bash .claude/optimize/pending/commands.sh  - Execute generated commands"
else
    echo "  (No pending commands to execute)"
fi
echo ""
echo "System Health:"
echo "  Check logs: find .claude/optimize -name '*.log' -type f"
echo "  Disk usage: du -sh .claude/optimize/"
echo "  Cleanup: See docs/OPTIMIZE_SYSTEM.md for maintenance procedures"

# Comprehensive system validation
echo ""
echo "SYSTEM HEALTH CHECK:"
echo "==================="

# Initialize health check counters
CRITICAL_ISSUES=0
WARNING_ISSUES=0

echo "Running comprehensive health validation..."

# Check critical files and data consistency
if [ "$PENDING" -gt 0 ] && [ ! -f ".claude/optimize/pending/issues.json" ]; then
    echo "❌ Critical: Pending count > 0 but no issues.json file found"
    echo "   Data inconsistency detected - run '/optimize' to regenerate"
    CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
fi

# Check directory structure integrity
for required_dir in ".claude/optimize/pending" ".claude/optimize/backlog" ".claude/optimize/completed" ".claude/optimize/decisions" ".claude/optimize/reports"; do
    if [ ! -d "$required_dir" ]; then
        echo "❌ Critical: Required directory missing: $required_dir"
        CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
    elif [ ! -w "$required_dir" ]; then
        echo "❌ Critical: Directory not writable: $required_dir"
        CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
    fi
done

# Check for orphaned or corrupted files
if [ -f ".claude/optimize/pending/issues.json" ]; then
    # Validate JSON structure if jq is available
    if command -v jq >/dev/null 2>&1; then
        if ! jq empty ".claude/optimize/pending/issues.json" >/dev/null 2>&1; then
            echo "❌ Critical: Corrupted issues.json file detected"
            echo "   File contains invalid JSON - run '/optimize' to regenerate"
            CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
        else
            # Check for expected JSON structure
            if ! jq -e '.issues' ".claude/optimize/pending/issues.json" >/dev/null 2>&1; then
                echo "⚠️  Warning: issues.json missing expected 'issues' array"
                WARNING_ISSUES=$((WARNING_ISSUES + 1))
            fi
        fi
    else
        echo "ℹ️  Note: jq not available - skipping JSON validation"
    fi
fi

# Check for reasonable file sizes to detect corruption
if [ -f ".claude/optimize/pending/issues.json" ]; then
    file_size=$(wc -c < ".claude/optimize/pending/issues.json" 2>/dev/null || echo "0")
    if [ "$file_size" -lt 50 ]; then
        echo "❌ Critical: issues.json file too small ($file_size bytes) - likely corrupted"
        CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
    elif [ "$file_size" -gt 1048576 ]; then  # 1MB
        echo "⚠️  Warning: issues.json file very large ($file_size bytes) - may indicate runaway generation"
        WARNING_ISSUES=$((WARNING_ISSUES + 1))
    fi
fi

# Check for disk space (require at least 10MB for safety)
if command -v df >/dev/null 2>&1; then
    available_kb=$(df . 2>/dev/null | tail -1 | awk '{print $4}' 2>/dev/null || echo "999999")
    # Validate the result is a number
    if echo "$available_kb" | grep -qE '^[0-9]+$'; then
        if [ "$available_kb" -lt 10240 ]; then  # 10MB
            if [ "$available_kb" -lt 5120 ]; then  # 5MB
                echo "❌ Critical: Very low disk space ($(echo "$available_kb / 1024" | bc 2>/dev/null || echo "<5")MB available)"
                CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
            else
                echo "⚠️  Warning: Low disk space ($(echo "$available_kb / 1024" | bc 2>/dev/null || echo "<10")MB available)"
                WARNING_ISSUES=$((WARNING_ISSUES + 1))
            fi
        fi
    else
        echo "⚠️  Warning: Could not determine disk space"
        WARNING_ISSUES=$((WARNING_ISSUES + 1))
    fi
else
    echo "ℹ️  Note: df command not available - skipping disk space check"
fi

# Check for potential permission issues
if [ ! -r ".claude/optimize" ] || [ ! -x ".claude/optimize" ]; then
    echo "❌ Critical: Cannot access optimization directory"
    CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
fi

# Summary of health check
echo ""
echo "Health Check Summary:"
if [ "$CRITICAL_ISSUES" -eq 0 ] && [ "$WARNING_ISSUES" -eq 0 ]; then
    echo "✅ System health: Excellent - All checks passed"
elif [ "$CRITICAL_ISSUES" -eq 0 ]; then
    echo "⚠️  System health: Good - $WARNING_ISSUES warnings detected"
    echo "   System is functional but could benefit from maintenance"
else
    echo "❌ System health: Poor - $CRITICAL_ISSUES critical issues, $WARNING_ISSUES warnings"
    echo "   Immediate attention required before using optimization system"
    echo ""
    echo "Recovery Steps:"
    echo "   1. Check file permissions on .claude/optimize directory"
    echo "   2. Ensure adequate disk space (at least 10MB free)"
    echo "   3. Run '/optimize' to regenerate corrupted files"
    echo "   4. If issues persist, see docs/OPTIMIZE_SYSTEM.md for troubleshooting"
fi
```
