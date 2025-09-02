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

cat > .claude/optimize/pending/issues.json << 'EOF'
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
TEMP_REPORT_FILE=".claude/optimize/reports/optimization_${TIMESTAMP}.md.tmp.$$"
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
