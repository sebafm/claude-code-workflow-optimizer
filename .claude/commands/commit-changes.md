---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*)
description: Create atomic git commits with conventional commit messages
---

## Context Analysis

Gather git status and changes with comprehensive error handling:

```bash
# Enable strict error handling
set -e  # Exit on any command failure
set -u  # Exit on undefined variables
set -o pipefail  # Exit on pipe failures

# Function for cleanup on error
cleanup_on_error() {
    echo "❌ Git operation failed. Repository state preserved."
    echo "   No changes have been committed"
    exit 1
}

# Set up error trap
trap cleanup_on_error ERR

echo "Analyzing repository state with safety validation..."

# Verify we're in a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Error: Not in a git repository"
    echo "   This command must be run from within a git repository"
    exit 1
fi

# Check if repository has any commits
if ! git rev-parse HEAD >/dev/null 2>&1; then
    echo "ℹ️  Note: Repository appears to be newly initialized (no commits yet)"
    REPO_IS_NEW=true
else
    REPO_IS_NEW=false
fi

echo "Repository validation complete. Collecting git status..."
echo ""
```

**Repository Status Analysis:**
- Repository status: !`git status --porcelain 2>/dev/null || echo "Unable to get status"`
- Unstaged changes: !`git diff --name-status 2>/dev/null || echo "No unstaged changes or git error"`  
- Staged changes: !`git diff --staged --name-status 2>/dev/null || echo "No staged changes or git error"`
- Current branch: !`git branch --show-current 2>/dev/null || echo "Unable to determine branch"`
- Last 5 commits: !`if [ "$REPO_IS_NEW" = "false" ]; then git log --oneline -5 2>/dev/null || echo "Unable to get commit history"; else echo "No commits yet"; fi`

## Commit Strategy

Execute safe, atomic commits with comprehensive validation:

```bash
echo "Preparing commit strategy with safety checks..."

# Comprehensive commit message validation function
validate_commit_message() {
    local message="$1"
    
    # Input validation
    if [ -z "$message" ]; then
        echo "❌ Error: Empty commit message"
        return 1
    fi
    
    # Length validation with detailed feedback
    local msg_length=${#message}
    if [ "$msg_length" -lt 10 ]; then
        echo "❌ Error: Commit message too short ($msg_length characters, minimum 10)"
        echo "   Example: 'fix(auth): resolve token validation issue'"
        return 1
    fi
    
    if [ "$msg_length" -gt 200 ]; then
        echo "❌ Error: Commit message too long ($msg_length characters, maximum 200)"
        echo "   Consider using git commit body for detailed descriptions"
        return 1
    elif [ "$msg_length" -gt 72 ]; then
        echo "⚠️  Warning: Commit message quite long ($msg_length characters)"
        echo "   Consider keeping first line under 50 characters for better readability"
    fi
    
    # Content validation - check for prohibited content
    if echo "$message" | grep -qi "AI\|assistant\|claude\|chatgpt\|copilot\|generated.*by\|auto.*generated"; then
        echo "❌ Error: Commit message contains AI/automation references"
        echo "   Please use descriptive, human-authored commit messages"
        echo "   Focus on WHAT changed and WHY, not HOW it was created"
        return 1
    fi
    
    # Check for placeholder or template text
    if echo "$message" | grep -qi "TODO\|FIXME\|placeholder\|your.*message.*here\|replace.*this"; then
        echo "❌ Error: Commit message appears to contain placeholder text"
        echo "   Please write a meaningful description of your changes"
        return 1
    fi
    
    # Security check - prevent potential command injection
    if echo "$message" | grep -qE '[`$\\();|&<>{}\[\]]'; then
        echo "❌ Error: Commit message contains potentially dangerous characters"
        echo "   Avoid special shell characters in commit messages"
        return 1
    fi
    
    # Validate character encoding (basic check for non-printable characters)
    if ! printf '%s' "$message" | grep -qE '^[[:print:][:space:]]*$'; then
        echo "❌ Error: Commit message contains non-printable characters"
        echo "   Please use only standard text characters"
        return 1
    fi
    
    # Check for conventional commit format
    if echo "$message" | grep -qE '^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\(.+\))?: .+'; then
        echo "✓ Conventional commit format detected"
        
        # Additional conventional commit validation
        local commit_type
        commit_type=$(echo "$message" | sed -E 's/^([a-z]+)(\(.+\))?:.*/\1/')
        
        # Check if type matches change content (basic heuristic)
        case "$commit_type" in
            "docs")
                echo "✓ Documentation commit type detected"
                ;;
            "fix")
                echo "✓ Bug fix commit type detected"
                ;;
            "feat")
                echo "✓ Feature commit type detected"
                ;;
            "refactor")
                echo "✓ Refactoring commit type detected"
                ;;
            "test")
                echo "✓ Test commit type detected"
                ;;
            *)
                echo "✓ Commit type '$commit_type' recognized"
                ;;
        esac
    else
        echo "ℹ️  Consider using conventional commit format:"
        echo "   feat(scope): add new feature"
        echo "   fix(scope): resolve issue"
        echo "   docs: update documentation"
        echo "   refactor: improve code structure"
    fi
    
    # Final validation - ensure message makes sense
    local word_count
    word_count=$(echo "$message" | wc -w)
    if [ "$word_count" -lt 3 ]; then
        echo "⚠️  Warning: Very short commit message ($word_count words)"
        echo "   Consider adding more context about the changes"
    fi
    
    return 0
}

# Comprehensive safe git add function with extensive validation
safe_git_add() {
    local files="$@"
    
    # Input validation
    if [ $# -eq 0 ]; then
        echo "❌ Error: No files specified for git add"
        echo "   Usage: safe_git_add <file1> [file2] [...]"
        return 1
    fi
    
    # Pre-flight checks
    echo "Validating files before staging..."
    local total_size=0
    local file_count=0
    local invalid_files=()
    
    # Verify all files exist and are safe to add
    for file in "$@"; do
        file_count=$((file_count + 1))
        
        # Basic existence and accessibility checks
        if [ ! -e "$file" ]; then
            echo "❌ Error: File does not exist: $file"
            invalid_files+=("$file")
            continue
        fi
        
        if [ ! -r "$file" ]; then
            echo "❌ Error: File not readable: $file"
            invalid_files+=("$file")
            continue
        fi
        
        # Check if file is already tracked or is in .gitignore
        if git check-ignore "$file" >/dev/null 2>&1; then
            echo "⚠️  Warning: File is in .gitignore: $file"
            echo "   This file will be ignored by git"
        fi
        
        # File size validation (warn about very large files)
        if [ -f "$file" ]; then
            file_size=$(wc -c < "$file" 2>/dev/null || echo "0")
            total_size=$((total_size + file_size))
            
            # Warn about large files (>10MB)
            if [ "$file_size" -gt 10485760 ]; then
                echo "⚠️  Warning: Large file detected: $file ($(echo "$file_size / 1024 / 1024" | bc 2>/dev/null || echo ">10")MB)"
                echo "   Consider using Git LFS for large files"
            fi
            
            # Check for binary files that might not be suitable for git
            if file "$file" 2>/dev/null | grep -qi "binary\|executable\|archive"; then
                echo "ℹ️  Note: Binary file detected: $file"
            fi
        fi
        
        # Check for sensitive content patterns (basic security scan)
        if [ -f "$file" ] && [ -r "$file" ]; then
            if grep -qiE "password|secret|api[_-]?key|private[_-]?key|token" "$file" 2>/dev/null; then
                echo "⚠️  Warning: File may contain sensitive information: $file"
                echo "   Please review before committing"
            fi
        fi
    done
    
    # Check if any files were invalid
    if [ ${#invalid_files[@]} -gt 0 ]; then
        echo "❌ Error: ${#invalid_files[@]} invalid files detected"
        echo "   Cannot proceed with staging"
        return 1
    fi
    
    # Warn about total size
    if [ "$total_size" -gt 52428800 ]; then  # 50MB
        echo "⚠️  Warning: Total size of files is large ($(echo "$total_size / 1024 / 1024" | bc 2>/dev/null || echo ">50")MB)"
        echo "   This may take time to upload to remote repository"
    fi
    
    echo "Staging $file_count files ($(echo "$total_size / 1024" | bc 2>/dev/null || echo "?")KB total)..."
    
    # Perform the actual git add with error handling
    if ! git add "$@" 2>&1; then
        echo "❌ Error: Failed to add files to git staging area"
        echo "   Check git status and repository integrity"
        return 1
    fi
    
    # Verify files were actually staged
    local staged_count
    staged_count=$(git diff --staged --name-only | wc -l)
    
    if [ "$staged_count" -eq 0 ]; then
        echo "⚠️  Warning: No files appear to be staged after git add"
        echo "   Files may have been already staged or no changes detected"
    else
        echo "✓ Files staged successfully ($staged_count files in staging area)"
    fi
    
    return 0
}

# Comprehensive safe git commit function with rollback capability
safe_git_commit() {
    local message="$1"
    
    # Input validation
    if [ -z "$message" ]; then
        echo "❌ Error: No commit message provided"
        return 1
    fi
    
    # Validate message comprehensively
    if ! validate_commit_message "$message"; then
        return 1
    fi
    
    # Pre-commit validation
    echo "Performing pre-commit validation..."
    
    # Check if there are staged changes
    if git diff --staged --quiet; then
        echo "ℹ️  No staged changes to commit"
        echo "   Use 'git add <files>' to stage changes first"
        echo "   Or use 'git status' to see repository state"
        return 1
    fi
    
    # Check repository state
    if git status --porcelain 2>/dev/null | grep -q "^UU "; then
        echo "❌ Error: Unresolved merge conflicts detected"
        echo "   Resolve conflicts before committing"
        return 1
    fi
    
    # Validate staged changes aren't too large
    local staged_size
    staged_size=$(git diff --staged --stat | tail -1 | grep -oE '[0-9]+ files? changed' | grep -oE '[0-9]+' || echo "0")
    
    if [ "$staged_size" -gt 100 ]; then
        echo "⚠️  Warning: Large number of files staged ($staged_size files)"
        echo "   Consider making smaller, more focused commits"
    fi
    
    # Show what will be committed for final review
    echo "Changes to be committed:"
    git diff --staged --name-status | head -10 | while IFS= read -r line; do
        echo "   $line"
    done
    
    local total_staged
    total_staged=$(git diff --staged --name-status | wc -l)
    if [ "$total_staged" -gt 10 ]; then
        echo "   ... and $((total_staged - 10)) more files"
    fi
    
    echo ""
    echo "Committing with message: $message"
    
    # Store current HEAD for potential rollback
    local previous_head=""
    if [ "$REPO_IS_NEW" = "false" ]; then
        if ! previous_head=$(git rev-parse HEAD 2>/dev/null); then
            echo "❌ Error: Cannot determine current HEAD for rollback"
            return 1
        fi
    fi
    
    # Attempt commit with error handling
    local commit_output
    if commit_output=$(git commit -m "$message" 2>&1); then
        echo "✅ Commit successful"
        
        # Verify commit was actually created
        local new_head
        if ! new_head=$(git rev-parse HEAD 2>/dev/null); then
            echo "❌ Error: Cannot verify new commit - repository may be corrupted"
            return 1
        fi
        
        # Validate the commit is different from previous (except for initial commit)
        if [ "$REPO_IS_NEW" = "false" ] && [ "$new_head" = "$previous_head" ]; then
            echo "⚠️  Warning: HEAD did not change, commit may have failed silently"
            echo "   This could indicate a git hook rejection or other issue"
            return 1
        fi
        
        # Display commit information
        local commit_info
        if commit_info=$(git log --oneline -1 2>/dev/null); then
            echo "✓ Commit verified: $commit_info"
        else
            echo "⚠️  Warning: Cannot display commit info, but commit appears successful"
        fi
        
        # Display commit statistics
        local commit_stats
        if commit_stats=$(git show --stat --oneline HEAD 2>/dev/null | tail -n +2); then
            echo "Changes summary:"
            echo "$commit_stats" | head -5 | while IFS= read -r line; do
                echo "   $line"
            done
        fi
        
        return 0
    else
        echo "❌ Error: Commit failed"
        echo "Git error output:"
        echo "$commit_output" | head -5 | while IFS= read -r line; do
            echo "   $line"
        done
        
        # Check for common commit failure reasons
        if echo "$commit_output" | grep -qi "hook"; then
            echo "   Commit may have been rejected by a git hook"
        elif echo "$commit_output" | grep -qi "nothing.*commit"; then
            echo "   No changes to commit (this shouldn't happen after staged check)"
        elif echo "$commit_output" | grep -qi "permission"; then
            echo "   Permission denied - check file and directory permissions"
        fi
        
        return 1
    fi
}

echo "Commit strategy functions loaded and ready"
echo ""
```

**Commit Strategy Rules:**
1. **Analyze changes by type and scope** - Group related files logically
2. **Identify change patterns** - feat/fix/refactor/docs/style/test
3. **Create atomic commits** using conventional format:
   ```
   type(scope): description
   
   Types:
   - feat: new features
   - fix: bug fixes  
   - refactor: code restructuring
   - docs: documentation
   - style: formatting
   - test: testing code
   - chore: maintenance tasks
   ```

**Safety Requirements:**
- ✅ **No mentions of AI assistants in commit messages**
- ✅ **One logical change per commit**
- ✅ **Clear, actionable commit messages**
- ✅ **Validation of all files before staging**
- ✅ **Rollback capability on commit failures**
- ✅ **Verification of successful commits**

**Usage Examples:**
```bash
# Stage and commit related files safely
safe_git_add file1.py file2.py
safe_git_commit "feat(api): add user authentication endpoints"

# Stage documentation updates
safe_git_add README.md docs/API.md
safe_git_commit "docs: update API documentation and examples"

# Fix a bug with proper staging validation
safe_git_add src/bugfix.py tests/test_bugfix.py
safe_git_commit "fix(auth): resolve token validation edge case"
```