---
allowed-tools: Bash(find:*), Bash(tar:*), Bash(gzip:*), Bash(mkdir:*), Bash(echo:*), Bash(date:*), Bash(ls:*), Bash(wc:*), Bash(cp:*), Bash(test:*), Bash(du:*)
description: Create timestamped backups of optimization data to prevent data loss
---

## Optimization Data Backup System

Create comprehensive backups of optimization session data with integrity verification and recovery guidance:

```bash
# Enable strict error handling
set -e  # Exit on any command failure
set -u  # Exit on undefined variables
set -o pipefail  # Exit on pipe failures

# Function for cleanup on error
cleanup_on_error() {
    echo "❌ Backup operation failed. Cleaning up partial operations..."
    rm -rf ".claude/optimize-backup.tmp" 2>/dev/null || true
    rm -f ".claude/optimize-backup-"*.tar.gz.tmp 2>/dev/null || true
    exit 1
}

# Set up error trap
trap cleanup_on_error ERR

echo "OPTIMIZATION DATA BACKUP SYSTEM"
echo "================================"
echo ""

# Function for safe directory validation
validate_directory() {
    local dir="$1"
    local description="$2"
    
    if [ ! -e "$dir" ]; then
        echo "⚠️  Warning: $description not found at $dir"
        return 1
    fi
    
    if [ ! -d "$dir" ]; then
        echo "❌ Error: $description exists but is not a directory: $dir"
        return 1
    fi
    
    if [ ! -r "$dir" ]; then
        echo "❌ Error: Cannot read $description directory: $dir"
        return 1
    fi
    
    return 0
}

# Function for safe file counting
count_files_safely() {
    local dir="$1"
    local pattern="$2"
    
    if [ ! -d "$dir" ]; then
        echo "0"
        return 0
    fi
    
    local count
    count=$(find "$dir" -name "$pattern" -type f 2>/dev/null | wc -l) || echo "0"
    echo "$count"
}

# Validate Claude Code environment
echo "Validating environment..."

if ! validate_directory ".claude" "Claude Code directory"; then
    echo "❌ This command must be run from the root of a Claude Code project"
    echo "   Expected: .claude/ directory in current working directory"
    exit 1
fi

# Check if optimization system is initialized
if ! validate_directory ".claude/optimize" "optimization system"; then
    echo "❌ Optimization system not initialized"
    echo "   Run '/optimize' first to set up the optimization workflow"
    echo "   There is no data to backup at this time"
    exit 1
fi

echo "✓ Environment validation passed"

# Generate timestamp for backup naming
TIMESTAMP=$(date '+%Y%m%d_%H%M%S' 2>/dev/null || echo "unknown_time")
BACKUP_NAME="optimize-backup-${TIMESTAMP}"
BACKUP_PATH=".claude/${BACKUP_NAME}.tar.gz"
TEMP_DIR=".claude/optimize-backup.tmp"

echo "Analyzing optimization data..."

# Count existing data to determine backup value
PENDING=$(count_files_safely ".claude/optimize/pending" "*.json")
BACKLOG=$(count_files_safely ".claude/optimize/backlog" "*.json")  
COMPLETED=$(count_files_safely ".claude/optimize/completed" "*.json")
DECISIONS=$(count_files_safely ".claude/optimize/decisions" "*.md")
REPORTS=$(count_files_safely ".claude/optimize/reports" "*.md")

TOTAL_FILES=$((PENDING + BACKLOG + COMPLETED + DECISIONS + REPORTS))

echo "📊 Data inventory:"
echo "   📋 Pending issues: $PENDING"
echo "   ⏸️  Backlog issues: $BACKLOG"
echo "   ✅ Completed issues: $COMPLETED" 
echo "   📝 Decision records: $DECISIONS"
echo "   📄 Analysis reports: $REPORTS"
echo "   📊 Total files: $TOTAL_FILES"

if [ "$TOTAL_FILES" -eq 0 ]; then
    echo ""
    echo "ℹ️  No optimization data found to backup"
    echo "   This is normal for a newly initialized system"
    echo "   Run '/optimize' to generate data worth backing up"
    exit 0
fi

# Check disk space before proceeding
if command -v du >/dev/null 2>&1; then
    DATA_SIZE_KB=$(du -sk ".claude/optimize" 2>/dev/null | cut -f1 2>/dev/null || echo "1024")
    # Estimate compressed size (typically 70% compression for text files)
    ESTIMATED_BACKUP_KB=$((DATA_SIZE_KB * 3 / 10))
    
    if command -v df >/dev/null 2>&1; then
        AVAILABLE_KB=$(df . 2>/dev/null | tail -1 | awk '{print $4}' 2>/dev/null || echo "999999")
        
        if echo "$AVAILABLE_KB" | grep -qE '^[0-9]+$' && [ "$AVAILABLE_KB" -lt "$((ESTIMATED_BACKUP_KB + 10240))" ]; then
            echo "❌ Error: Insufficient disk space for backup"
            echo "   Required: ~${ESTIMATED_BACKUP_KB}KB, Available: ${AVAILABLE_KB}KB"
            echo "   Please free up disk space before creating backup"
            exit 1
        fi
    fi
    
    echo "💾 Data size: ${DATA_SIZE_KB}KB (~${ESTIMATED_BACKUP_KB}KB compressed estimate)"
fi

echo ""
echo "Creating backup..."

# Create temporary staging area
echo "Preparing backup staging area..."
if ! mkdir -p "$TEMP_DIR" 2>/dev/null; then
    echo "❌ Error: Cannot create temporary directory $TEMP_DIR"
    echo "   Check permissions and disk space"
    exit 1
fi

# Copy data to staging area with verification
echo "Copying optimization data to staging area..."

# Function for safe directory copy
safe_copy_directory() {
    local src="$1"
    local dest="$2"
    local description="$3"
    
    if [ -d "$src" ]; then
        echo "  Copying $description..."
        if ! cp -r "$src" "$dest" 2>/dev/null; then
            echo "❌ Error: Failed to copy $description from $src"
            return 1
        fi
        
        # Verify copy completed successfully
        src_count=$(find "$src" -type f 2>/dev/null | wc -l)
        dest_count=$(find "$dest/$(basename "$src")" -type f 2>/dev/null | wc -l)
        
        if [ "$src_count" -ne "$dest_count" ]; then
            echo "❌ Error: File count mismatch in $description copy"
            echo "   Source: $src_count files, Destination: $dest_count files"
            return 1
        fi
        
        echo "  ✓ $description copied successfully ($src_count files)"
    else
        echo "  Skipping $description (directory not found)"
    fi
    
    return 0
}

# Copy all optimization directories
if ! safe_copy_directory ".claude/optimize/pending" "$TEMP_DIR" "pending issues"; then
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    exit 1
fi

if ! safe_copy_directory ".claude/optimize/backlog" "$TEMP_DIR" "backlog issues"; then
    rm -rf "$TEMP_DIR" 2>/dev/null || true  
    exit 1
fi

if ! safe_copy_directory ".claude/optimize/completed" "$TEMP_DIR" "completed issues"; then
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    exit 1
fi

if ! safe_copy_directory ".claude/optimize/decisions" "$TEMP_DIR" "decision records"; then
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    exit 1
fi

if ! safe_copy_directory ".claude/optimize/reports" "$TEMP_DIR" "analysis reports"; then
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    exit 1
fi

# Create backup metadata
echo "Generating backup metadata..."
cat > "$TEMP_DIR/backup_metadata.txt" << EOF
Optimization Data Backup
========================
Created: $(date 2>/dev/null || echo "unknown date")
Timestamp: $TIMESTAMP
Source Directory: .claude/optimize
Backup Command: /protect-optimize-data

File Counts:
- Pending Issues: $PENDING
- Backlog Issues: $BACKLOG  
- Completed Issues: $COMPLETED
- Decision Records: $DECISIONS
- Analysis Reports: $REPORTS
- Total Files: $TOTAL_FILES

System Information:
- Working Directory: $(pwd 2>/dev/null || echo "unknown")
- User: $(whoami 2>/dev/null || echo "unknown")
- Platform: $(uname -s 2>/dev/null || echo "unknown")

Restoration Instructions:
1. Extract backup: tar -xzf $BACKUP_NAME.tar.gz
2. Stop any optimization processes
3. Backup current data: mv .claude/optimize .claude/optimize.old
4. Restore data: mv optimize-backup.tmp/*/optimize .claude/
5. Verify restoration with: /optimize-status
EOF

echo "✓ Backup metadata created"

# Create compressed archive
echo "Creating compressed archive..."

# Use tar with gzip compression (cross-platform compatible)
if command -v tar >/dev/null 2>&1; then
    cd "$TEMP_DIR" || exit 1
    
    if ! tar -czf "../${BACKUP_NAME}.tar.gz" . 2>/dev/null; then
        echo "❌ Error: Failed to create compressed archive"
        cd .. 2>/dev/null || true
        rm -rf "$TEMP_DIR" 2>/dev/null || true
        exit 1
    fi
    
    cd .. || exit 1
    echo "✓ Compressed archive created successfully"
else
    echo "❌ Error: tar command not available"
    echo "   Cannot create compressed backup archive"
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    exit 1
fi

# Verify backup integrity
echo "Verifying backup integrity..."

if [ ! -f "$BACKUP_PATH" ]; then
    echo "❌ Error: Backup file was not created: $BACKUP_PATH"
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    exit 1
fi

# Check backup file size
BACKUP_SIZE=$(wc -c < "$BACKUP_PATH" 2>/dev/null || echo "0")
if [ "$BACKUP_SIZE" -lt 100 ]; then
    echo "❌ Error: Backup file too small ($BACKUP_SIZE bytes) - likely corrupted"
    rm -f "$BACKUP_PATH" 2>/dev/null || true
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    exit 1
fi

# Test archive extraction
echo "Testing archive extraction..."
VERIFY_DIR=".claude/verify-backup.tmp"
mkdir -p "$VERIFY_DIR" || exit 1

if ! tar -xzf "$BACKUP_PATH" -C "$VERIFY_DIR" 2>/dev/null; then
    echo "❌ Error: Backup archive is corrupted (extraction failed)"
    rm -f "$BACKUP_PATH" 2>/dev/null || true
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    rm -rf "$VERIFY_DIR" 2>/dev/null || true
    exit 1
fi

# Verify extracted contents
if [ ! -f "$VERIFY_DIR/backup_metadata.txt" ]; then
    echo "❌ Error: Backup missing metadata file"
    rm -f "$BACKUP_PATH" 2>/dev/null || true
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    rm -rf "$VERIFY_DIR" 2>/dev/null || true
    exit 1
fi

echo "✓ Backup integrity verified"

# Clean up temporary directories
rm -rf "$TEMP_DIR" 2>/dev/null || true
rm -rf "$VERIFY_DIR" 2>/dev/null || true

echo ""
echo "🎉 BACKUP COMPLETED SUCCESSFULLY!"
echo "================================="
echo ""
echo "📦 Backup Details:"
echo "   File: $BACKUP_PATH"
echo "   Size: ${BACKUP_SIZE} bytes"
echo "   Contains: $TOTAL_FILES optimization files"
echo "   Created: $(date 2>/dev/null || echo "now")"
echo ""

echo "🔐 Security Recommendations:"
echo "   • Store backup in a secure location outside the project"
echo "   • Consider encrypting backup for sensitive projects"
echo "   • Test restoration procedure in a safe environment"
echo "   • Create regular backups before major optimization sessions"
echo ""

echo "📋 Quick Restoration Commands:"
echo "   # Extract backup contents"
echo "   tar -xzf $BACKUP_PATH"
echo ""
echo "   # View backup metadata"  
echo "   tar -xzOf $BACKUP_PATH backup_metadata.txt"
echo ""
echo "   # Full restoration (DESTRUCTIVE - current data will be lost):"
echo "   mv .claude/optimize .claude/optimize.backup.$(date +%Y%m%d_%H%M%S)"
echo "   tar -xzf $BACKUP_PATH"
echo "   mv optimize-backup.tmp/*/* .claude/"
echo "   rm -rf optimize-backup.tmp"
echo "   /optimize-status  # Verify restoration"
echo ""

echo "⚠️  IMPORTANT RESTORATION NOTES:"
echo "   • Always backup current data before restoring"
echo "   • Test restoration in a separate directory first"
echo "   • Run /optimize-status after restoration to verify system health"
echo "   • Restoration will overwrite ALL current optimization data"
echo ""

echo "💡 Backup Management Tips:"
echo "   • List all backups: ls -la .claude/optimize-backup-*.tar.gz"
echo "   • Check backup size: ls -lh .claude/optimize-backup-*.tar.gz"
echo "   • Remove old backups: rm .claude/optimize-backup-YYYYMMDD_*.tar.gz"
echo "   • Archive important backups outside the project directory"
echo ""

# List existing backups for reference
if ls .claude/optimize-backup-*.tar.gz >/dev/null 2>&1; then
    echo "📚 Existing Backups:"
    ls -lah .claude/optimize-backup-*.tar.gz | while IFS= read -r line; do
        echo "   $line"
    done
    echo ""
    
    # Count total backups
    BACKUP_COUNT=$(ls .claude/optimize-backup-*.tar.gz 2>/dev/null | wc -l)
    echo "   Total backups: $BACKUP_COUNT"
    
    if [ "$BACKUP_COUNT" -gt 5 ]; then
        echo "   ⚠️  Consider cleaning up old backups to save disk space"
    fi
else
    echo "📚 This is your first optimization data backup"
fi

echo ""
echo "✅ Backup operation completed successfully!"
echo "   Your optimization data is now safely backed up"
echo "   Use this backup before risky operations or major changes"
```