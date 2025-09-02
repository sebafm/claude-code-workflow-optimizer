---
allowed-tools: Bash(find:*), Bash(grep:*), Bash(cat:*), Bash(cp:*), Bash(mkdir:*), Bash(echo:*), Bash(sed:*), Bash(which:*), Bash(test:*), Bash(if:*), Bash(git:*), Bash(wc:*), Bash(head:*), Bash(tail:*), Bash(ls:*), Bash(date:*), Bash(mktemp:*), Bash(mv:*)
description: Initialize Claude Code Workflow Optimizer with intelligent CLAUDE.md integration, customized agents, and project-specific configuration
---

## Pre-Setup Validation

Comprehensive environment and project checks with safety validation:

```bash
# Enable strict error handling
set -e  # Exit on any command failure
set -u  # Exit on undefined variables  
set -o pipefail  # Exit on pipe failures

# Function for cleanup on error
cleanup_on_error() {
    echo "❌ Setup failed. Cleaning up partial operations..."
    rm -rf ".claude/optimize.tmp" 2>/dev/null || true
    rm -rf ".claude/optimize/agents.tmp" 2>/dev/null || true
    rm -f ".claude/optimize/config.json.tmp"* 2>/dev/null || true
    exit 1
}

# Set up error trap
trap cleanup_on_error ERR

echo "🚀 Claude Code Workflow Optimizer - Project Setup"
echo "========================================"
echo ""

echo "Validating environment and project structure..."

# Check if we're in a directory (basic sanity check)
if [ ! -d "." ]; then
    echo "❌ Error: Cannot access current directory"
    exit 1
fi

# Check for basic write permissions
if ! touch ".claude_setup_test.tmp" 2>/dev/null; then
    echo "❌ Error: No write permissions in current directory"
    echo "   Please run this command from a directory where you have write access"
    exit 1
fi
rm -f ".claude_setup_test.tmp" 2>/dev/null || true

# Validate this is a reasonable project directory
current_dir=$(pwd)
echo "Working directory: $current_dir"

# Check if already setup (idempotency check)
if [ -f ".claude/optimize/config.json" ]; then
    echo "⚠️  Optimization system already initialized"
    
    # Read existing setup date if available
    if command -v jq >/dev/null 2>&1; then
        setup_date=$(jq -r '.setup_date // "Unknown"' .claude/optimize/config.json 2>/dev/null || echo "Unknown")
        echo "   Original setup: $setup_date"
    fi
    
    echo ""
    echo "Choose an option:"
    echo "1) Update configuration (preserves existing data)"
    echo "2) Reset completely (removes all optimization data)"
    echo "3) Exit (no changes)"
    echo ""
    echo -n "Enter choice (1-3): "
    read -r choice
    
    case "$choice" in
        1)
            echo "Updating existing configuration..."
            UPDATE_MODE="true"
            ;;
        2)
            echo "⚠️  WARNING: This will delete all optimization data!"
            echo -n "Type 'DELETE' to confirm: "
            read -r confirm
            if [ "$confirm" = "DELETE" ]; then
                echo "Removing existing optimization system..."
                rm -rf ".claude/optimize" 2>/dev/null || true
                UPDATE_MODE="false"
            else
                echo "Operation cancelled"
                exit 0
            fi
            ;;
        3)
            echo "Setup cancelled"
            exit 0
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
else
    UPDATE_MODE="false"
fi

echo "✓ Environment validation completed"
```

## Project Analysis and Detection

Smart detection of project characteristics and tooling:

```bash
echo "📊 Project Analysis:"
echo "=================="

# Initialize detection variables
PROJECT_TYPE="unknown"
PRIMARY_LANGUAGE=""
FRAMEWORK=""
TEST_FRAMEWORK=""
PACKAGE_MANAGER=""
STYLE_TOOLS=""
LANGUAGES=()

# Function for safe command checking
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function for safe file detection
has_files() {
    local pattern="$1"
    [ $(find . -maxdepth 3 -name "$pattern" -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./.venv/*" -not -path "./__pycache__/*" -type f 2>/dev/null | wc -l) -gt 0 ]
}

# Language Detection
echo "Detecting programming languages..."

if has_files "*.py"; then
    LANGUAGES+=("Python")
    if [ -z "$PRIMARY_LANGUAGE" ]; then
        PRIMARY_LANGUAGE="Python"
    fi
    
    # Python framework detection
    if [ -f "requirements.txt" ] || [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
        if has_files "*fastapi*" || grep -q "fastapi" requirements.txt 2>/dev/null || grep -q "fastapi" pyproject.toml 2>/dev/null; then
            FRAMEWORK="FastAPI"
        elif has_files "*django*" || grep -q "Django" requirements.txt 2>/dev/null || grep -q "django" pyproject.toml 2>/dev/null; then
            FRAMEWORK="Django"
        elif has_files "*flask*" || grep -q "Flask" requirements.txt 2>/dev/null || grep -q "flask" pyproject.toml 2>/dev/null; then
            FRAMEWORK="Flask"
        fi
    fi
    
    # Python package manager detection
    if [ -f "poetry.lock" ]; then
        PACKAGE_MANAGER="Poetry"
    elif [ -f "Pipfile" ]; then
        PACKAGE_MANAGER="Pipenv"
    elif [ -f "requirements.txt" ]; then
        PACKAGE_MANAGER="pip"
    fi
    
    # Python test framework detection
    if has_files "*pytest*" || grep -q "pytest" requirements.txt 2>/dev/null || command_exists pytest; then
        TEST_FRAMEWORK="pytest"
    elif has_files "*unittest*" || python3 -c "import unittest" 2>/dev/null; then
        TEST_FRAMEWORK="unittest"
    fi
    
    # Python style tools detection
    style_tools=()
    if command_exists black || grep -q "black" requirements.txt 2>/dev/null; then
        style_tools+=("black")
    fi
    if command_exists ruff || grep -q "ruff" requirements.txt 2>/dev/null; then
        style_tools+=("ruff")
    fi
    if command_exists flake8 || grep -q "flake8" requirements.txt 2>/dev/null; then
        style_tools+=("flake8")
    fi
    STYLE_TOOLS=$(IFS=","; echo "${style_tools[*]}")
fi

if has_files "*.js" || has_files "*.ts" || has_files "*.jsx" || has_files "*.tsx"; then
    if has_files "*.ts" || has_files "*.tsx"; then
        LANGUAGES+=("TypeScript")
        if [ -z "$PRIMARY_LANGUAGE" ]; then
            PRIMARY_LANGUAGE="TypeScript"
        fi
    else
        LANGUAGES+=("JavaScript")
        if [ -z "$PRIMARY_LANGUAGE" ]; then
            PRIMARY_LANGUAGE="JavaScript"
        fi
    fi
    
    # Node.js framework detection
    if [ -f "package.json" ]; then
        if grep -q "\"next\"" package.json 2>/dev/null; then
            FRAMEWORK="Next.js"
        elif grep -q "\"react\"" package.json 2>/dev/null; then
            FRAMEWORK="React"
        elif grep -q "\"express\"" package.json 2>/dev/null; then
            FRAMEWORK="Express"
        elif grep -q "\"vue\"" package.json 2>/dev/null; then
            FRAMEWORK="Vue.js"
        fi
        
        # Node.js package manager detection
        if [ -f "yarn.lock" ]; then
            PACKAGE_MANAGER="Yarn"
        elif [ -f "pnpm-lock.yaml" ]; then
            PACKAGE_MANAGER="pnpm"
        else
            PACKAGE_MANAGER="npm"
        fi
        
        # JavaScript/TypeScript test framework detection
        if grep -q "\"jest\"" package.json 2>/dev/null; then
            TEST_FRAMEWORK="Jest"
        elif grep -q "\"mocha\"" package.json 2>/dev/null; then
            TEST_FRAMEWORK="Mocha"
        elif grep -q "\"vitest\"" package.json 2>/dev/null; then
            TEST_FRAMEWORK="Vitest"
        fi
        
        # JavaScript/TypeScript style tools
        style_tools=()
        if grep -q "\"prettier\"" package.json 2>/dev/null; then
            style_tools+=("prettier")
        fi
        if grep -q "\"eslint\"" package.json 2>/dev/null; then
            style_tools+=("eslint")
        fi
        STYLE_TOOLS=$(IFS=","; echo "${style_tools[*]}")
    fi
fi

if has_files "*.go"; then
    LANGUAGES+=("Go")
    if [ -z "$PRIMARY_LANGUAGE" ]; then
        PRIMARY_LANGUAGE="Go"
    fi
    TEST_FRAMEWORK="go test"
    PACKAGE_MANAGER="go mod"
    
    # Go framework detection
    if [ -f "go.mod" ]; then
        if grep -q "gin-gonic" go.mod 2>/dev/null; then
            FRAMEWORK="Gin"
        elif grep -q "echo" go.mod 2>/dev/null; then
            FRAMEWORK="Echo"
        elif grep -q "fiber" go.mod 2>/dev/null; then
            FRAMEWORK="Fiber"
        fi
    fi
fi

if has_files "*.rs"; then
    LANGUAGES+=("Rust")
    if [ -z "$PRIMARY_LANGUAGE" ]; then
        PRIMARY_LANGUAGE="Rust"
    fi
    if [ -f "Cargo.toml" ]; then
        PACKAGE_MANAGER="Cargo"
        TEST_FRAMEWORK="cargo test"
        
        # Rust framework detection
        if grep -q "actix" Cargo.toml 2>/dev/null; then
            FRAMEWORK="Actix"
        elif grep -q "axum" Cargo.toml 2>/dev/null; then
            FRAMEWORK="Axum"
        elif grep -q "rocket" Cargo.toml 2>/dev/null; then
            FRAMEWORK="Rocket"
        fi
    fi
fi

# Project type classification
if [ -f "package.json" ] && [ "$PRIMARY_LANGUAGE" = "TypeScript" ] || [ "$PRIMARY_LANGUAGE" = "JavaScript" ]; then
    PROJECT_TYPE="node"
elif [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
    PROJECT_TYPE="python"
elif [ -f "go.mod" ]; then
    PROJECT_TYPE="go"
elif [ -f "Cargo.toml" ]; then
    PROJECT_TYPE="rust"
elif [ -d ".git" ]; then
    PROJECT_TYPE="git-repo"
else
    PROJECT_TYPE="general"
fi

# Git repository detection
IS_GIT_REPO="false"
if [ -d ".git" ]; then
    IS_GIT_REPO="true"
    if command_exists git; then
        CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
        echo "✓ Git repository detected (branch: $CURRENT_BRANCH)"
    else
        echo "✓ Git repository detected (git command not available)"
    fi
else
    echo "⚠ Not a git repository (some features will be limited)"
fi

# Display analysis results
echo "✓ Language: ${PRIMARY_LANGUAGE:-"Multi-language/Unknown"}"
if [ -n "$FRAMEWORK" ]; then
    echo "✓ Framework: $FRAMEWORK"
fi
if [ -n "$TEST_FRAMEWORK" ]; then
    echo "✓ Tests: $TEST_FRAMEWORK"
fi
if [ -n "$STYLE_TOOLS" ]; then
    echo "✓ Style: $STYLE_TOOLS"
fi
if [ -n "$PACKAGE_MANAGER" ]; then
    echo "✓ Package Manager: $PACKAGE_MANAGER"
fi

if [ ${#LANGUAGES[@]} -gt 1 ]; then
    echo "✓ Additional languages: ${LANGUAGES[*]}"
fi

echo ""
```

## Directory Structure Creation

Create the optimization directory structure with safety validation:

```bash
echo "📁 Created Structure:"
echo "=================="

# Function for safe directory creation with validation
safe_mkdir() {
    local dir="$1"
    local description="$2"
    
    if [ ! -d "$dir" ]; then
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
        
        echo "✓ $description"
    else
        if [ ! -w "$dir" ]; then
            echo "❌ Error: Directory $dir exists but is not writable"
            return 1
        fi
        echo "✓ $description (already exists)"
    fi
}

# Create all required directories with validation
safe_mkdir ".claude/optimize" "Main optimization directory"
safe_mkdir ".claude/optimize/agents" "Customized agents directory"
safe_mkdir ".claude/optimize/config" "Configuration directory"
safe_mkdir ".claude/optimize/templates" "Issue templates directory"
safe_mkdir ".claude/optimize/reports" "Analysis reports directory"
safe_mkdir ".claude/optimize/pending" "Pending optimizations directory"
safe_mkdir ".claude/optimize/backlog" "Deferred items directory"
safe_mkdir ".claude/optimize/completed" "Completed optimizations directory"
safe_mkdir ".claude/optimize/decisions" "Decision logs directory"

# Create .gitkeep files for empty directories
for dir in reports pending backlog completed decisions; do
    if [ ! -f ".claude/optimize/$dir/.gitkeep" ]; then
        echo "# Directory for optimization system" > ".claude/optimize/$dir/.gitkeep"
        echo "✓ Created .gitkeep for $dir/"
    fi
done

echo ""
```

## Agent Customization Process

Detect available agents and customize them for the project:

```bash
echo "🤖 Agent Customization:"
echo "====================="

# List of agents that are beneficial for optimization
RECOMMENDED_AGENTS=(
    "code-reviewer"
    "security-auditor"
    "test-automation-engineer"
    "database-architect"
    "python-backend-architect"
    "bash-scripting-specialist"
    "markdown-specialist"
    "command-reviewer"
    "workflow-ux-designer"
    "claude-code-integration-specialist"
    "github-integration-specialist"
    "project-scribe"
)

# Language/framework specific agents
case "$PRIMARY_LANGUAGE" in
    "Python")
        RECOMMENDED_AGENTS+=("python-backend-architect")
        ;;
    "JavaScript"|"TypeScript")
        RECOMMENDED_AGENTS+=("frontend-architect" "nodejs-backend-specialist")
        ;;
    "Go")
        RECOMMENDED_AGENTS+=("go-backend-specialist" "microservices-architect")
        ;;
    "Rust")
        RECOMMENDED_AGENTS+=("systems-programmer" "performance-optimizer")
        ;;
esac

AVAILABLE_AGENTS=()
MISSING_AGENTS=()
CUSTOMIZED_AGENTS=()

echo "Checking agent availability..."

# Check for agents in user's global directory
if [ -d "$HOME/.claude/agents" ] && [ -r "$HOME/.claude/agents" ]; then
    echo "✓ Global agents directory found"
    
    for agent in "${RECOMMENDED_AGENTS[@]}"; do
        if [ -f "$HOME/.claude/agents/$agent.md" ] && [ -r "$HOME/.claude/agents/$agent.md" ]; then
            AVAILABLE_AGENTS+=("$agent")
            echo "✓ @$agent - Available"
        else
            MISSING_AGENTS+=("$agent")
            echo "⚠ @$agent - Not found (will use fallback)"
        fi
    done
else
    echo "⚠ Global agents directory not found ($HOME/.claude/agents)"
    echo "  All agents will be marked as missing (system will use fallbacks)"
    MISSING_AGENTS=("${RECOMMENDED_AGENTS[@]}")
fi

# Check for agents in current project
if [ -d ".claude/agents" ] && [ -r ".claude/agents" ]; then
    echo "✓ Project agents directory found"
    
    for agent_file in .claude/agents/*.md; do
        if [ -f "$agent_file" ] && [ -r "$agent_file" ]; then
            agent_name=$(basename "$agent_file" .md)
            # Add to available if not already there
            if [[ ! " ${AVAILABLE_AGENTS[@]} " =~ " ${agent_name} " ]]; then
                AVAILABLE_AGENTS+=("$agent_name")
                echo "✓ @$agent_name - Available (project-local)"
            fi
        fi
    done
fi

echo ""
echo "Customizing available agents for your project..."

# Create temporary directory for safe operations
TEMP_AGENTS_DIR=".claude/optimize/agents.tmp"
mkdir -p "$TEMP_AGENTS_DIR"

for agent in "${AVAILABLE_AGENTS[@]}"; do
    SOURCE_FILE=""
    
    # Find the agent file (prefer global over project)
    if [ -f "$HOME/.claude/agents/$agent.md" ]; then
        SOURCE_FILE="$HOME/.claude/agents/$agent.md"
    elif [ -f ".claude/agents/$agent.md" ]; then
        SOURCE_FILE=".claude/agents/$agent.md"
    fi
    
    if [ -n "$SOURCE_FILE" ] && [ -r "$SOURCE_FILE" ]; then
        TARGET_FILE="$TEMP_AGENTS_DIR/$agent.md"
        
        # Copy base agent
        if ! cp "$SOURCE_FILE" "$TARGET_FILE"; then
            echo "❌ Failed to copy $agent agent"
            continue
        fi
        
        # Customize agent with project context
        PROJECT_CONTEXT=""
        
        case "$agent" in
            "code-reviewer")
                PROJECT_CONTEXT="

## Project Context for Code Review

**Project Type:** $PROJECT_TYPE
**Primary Language:** ${PRIMARY_LANGUAGE:-"Multi-language"}
**Framework:** ${FRAMEWORK:-"None detected"}
**Test Framework:** ${TEST_FRAMEWORK:-"None detected"}

### Focus Areas for This Project:
- Review ${PRIMARY_LANGUAGE:-"multi-language"} code quality and patterns"
                if [ -n "$STYLE_TOOLS" ]; then
                    PROJECT_CONTEXT="$PROJECT_CONTEXT
- Ensure compliance with $STYLE_TOOLS style guidelines"
                fi
                if [ -n "$FRAMEWORK" ]; then
                    PROJECT_CONTEXT="$PROJECT_CONTEXT
- Validate $FRAMEWORK best practices and patterns"
                fi
                ;;
            
            "security-auditor")
                PROJECT_CONTEXT="

## Security Context for This Project

**Technology Stack:** ${PRIMARY_LANGUAGE:-"Multi-language"}${FRAMEWORK:+" + $FRAMEWORK"}
**Package Manager:** ${PACKAGE_MANAGER:-"None detected"}

### Security Focus Areas:
- ${PRIMARY_LANGUAGE:-"General"} security best practices"
                if [ "$IS_GIT_REPO" = "true" ]; then
                    PROJECT_CONTEXT="$PROJECT_CONTEXT
- Git repository security (secrets detection, .gitignore validation)"
                fi
                if [ -n "$FRAMEWORK" ]; then
                    PROJECT_CONTEXT="$PROJECT_CONTEXT
- $FRAMEWORK security patterns and vulnerability prevention"
                fi
                ;;
                
            "test-automation-engineer")
                PROJECT_CONTEXT="

## Testing Context for This Project

**Test Framework:** ${TEST_FRAMEWORK:-"None detected - recommend suitable framework"}
**Primary Language:** ${PRIMARY_LANGUAGE:-"Multi-language"}

### Testing Priorities:
- ${TEST_FRAMEWORK:-"Generic testing"} best practices and patterns"
                if [ -n "$FRAMEWORK" ]; then
                    PROJECT_CONTEXT="$PROJECT_CONTEXT
- $FRAMEWORK testing strategies and integration patterns"
                fi
                PROJECT_CONTEXT="$PROJECT_CONTEXT
- Test coverage analysis and improvement recommendations
- Test-driven development workflow integration"
                ;;
                
            "python-backend-architect")
                if [ "$PRIMARY_LANGUAGE" = "Python" ]; then
                    PROJECT_CONTEXT="

## Python Architecture Context

**Framework:** ${FRAMEWORK:-"None detected"}
**Package Manager:** ${PACKAGE_MANAGER:-"pip"}
**Testing:** ${TEST_FRAMEWORK:-"None detected"}

### Architecture Focus:
- Python project structure and organization"
                    if [ -n "$FRAMEWORK" ]; then
                        PROJECT_CONTEXT="$PROJECT_CONTEXT
- $FRAMEWORK architecture patterns and best practices"
                    fi
                    PROJECT_CONTEXT="$PROJECT_CONTEXT
- Dependency management with $PACKAGE_MANAGER
- Code modularity and maintainability patterns"
                fi
                ;;
                
            "bash-scripting-specialist")
                PROJECT_CONTEXT="

## Bash Scripting Context

**Project Type:** $PROJECT_TYPE
**Platform:** Cross-platform (prioritize Windows compatibility via bash emulation)

### Scripting Focus:
- Claude Code command development and optimization
- Cross-platform bash compatibility
- Safe file operations and error handling
- Integration with ${PACKAGE_MANAGER:-"project toolchain"}"
                ;;
        esac
        
        # Append project context to agent file
        if [ -n "$PROJECT_CONTEXT" ]; then
            echo "$PROJECT_CONTEXT" >> "$TARGET_FILE"
            CUSTOMIZED_AGENTS+=("$agent")
            echo "✓ @$agent → Adapted for ${PRIMARY_LANGUAGE:-"multi-language"} project"
        else
            CUSTOMIZED_AGENTS+=("$agent")
            echo "✓ @$agent → Copied (no specific customization)"
        fi
    fi
done

# Atomically move customized agents to final location
if [ ${#CUSTOMIZED_AGENTS[@]} -gt 0 ]; then
    for agent in "${CUSTOMIZED_AGENTS[@]}"; do
        if [ -f "$TEMP_AGENTS_DIR/$agent.md" ]; then
            if ! mv "$TEMP_AGENTS_DIR/$agent.md" ".claude/optimize/agents/$agent.md"; then
                echo "❌ Failed to finalize $agent customization"
            fi
        fi
    done
fi

# Cleanup temporary directory
rm -rf "$TEMP_AGENTS_DIR" 2>/dev/null || true

echo "✓ Customized ${#CUSTOMIZED_AGENTS[@]} agents with project-specific context"

if [ ${#MISSING_AGENTS[@]} -gt 0 ]; then
    echo ""
    echo "Recommended agents not found:"
    for agent in "${MISSING_AGENTS[@]}"; do
        echo "  - @$agent (optimization scope will be reduced)"
    done
    echo ""
    echo "Consider adding these agents to ~/.claude/agents/ for better analysis."
fi

echo ""
```

## Configuration File Generation

Generate project configuration with detected settings:

```bash
echo "⚙️ Configuration:"
echo "==============="

# Generate configuration with safe timestamp
SETUP_TIMESTAMP=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')

# Create configuration file with atomic operations
CONFIG_TEMP_FILE=".claude/optimize/config.json.tmp.$$"
CONFIG_FINAL_FILE=".claude/optimize/config.json"

# Build languages array for JSON
LANGUAGES_JSON="["
for i in "${!LANGUAGES[@]}"; do
    if [ $i -gt 0 ]; then
        LANGUAGES_JSON="$LANGUAGES_JSON,"
    fi
    LANGUAGES_JSON="$LANGUAGES_JSON\"${LANGUAGES[i]}\""
done
LANGUAGES_JSON="$LANGUAGES_JSON]"

# Build available agents array for JSON
AVAILABLE_AGENTS_JSON="["
for i in "${!AVAILABLE_AGENTS[@]}"; do
    if [ $i -gt 0 ]; then
        AVAILABLE_AGENTS_JSON="$AVAILABLE_AGENTS_JSON,"
    fi
    AVAILABLE_AGENTS_JSON="$AVAILABLE_AGENTS_JSON\"${AVAILABLE_AGENTS[i]}\""
done
AVAILABLE_AGENTS_JSON="$AVAILABLE_AGENTS_JSON]"

# Build customized agents array for JSON
CUSTOMIZED_AGENTS_JSON="["
for i in "${!CUSTOMIZED_AGENTS[@]}"; do
    if [ $i -gt 0 ]; then
        CUSTOMIZED_AGENTS_JSON="$CUSTOMIZED_AGENTS_JSON,"
    fi
    CUSTOMIZED_AGENTS_JSON="$CUSTOMIZED_AGENTS_JSON\"${CUSTOMIZED_AGENTS[i]}\""
done
CUSTOMIZED_AGENTS_JSON="$CUSTOMIZED_AGENTS_JSON]"

# Build missing agents array for JSON
MISSING_AGENTS_JSON="["
for i in "${!MISSING_AGENTS[@]}"; do
    if [ $i -gt 0 ]; then
        MISSING_AGENTS_JSON="$MISSING_AGENTS_JSON,"
    fi
    MISSING_AGENTS_JSON="$MISSING_AGENTS_JSON\"${MISSING_AGENTS[i]}\""
done
MISSING_AGENTS_JSON="$MISSING_AGENTS_JSON]"

# Create comprehensive configuration
cat > "$CONFIG_TEMP_FILE" << EOF
{
  "version": "0.1.0",
  "setup_date": "$SETUP_TIMESTAMP",
  "update_mode": $UPDATE_MODE,
  "project": {
    "type": "$PROJECT_TYPE",
    "languages": $LANGUAGES_JSON,
    "primary_language": "${PRIMARY_LANGUAGE:-"unknown"}",
    "framework": "${FRAMEWORK:-"none"}",
    "test_framework": "${TEST_FRAMEWORK:-"none"}",
    "package_manager": "${PACKAGE_MANAGER:-"none"}",
    "style_tools": "${STYLE_TOOLS:-"none"}",
    "is_git_repo": $IS_GIT_REPO
  },
  "agents": {
    "available": $AVAILABLE_AGENTS_JSON,
    "customized": $CUSTOMIZED_AGENTS_JSON,
    "missing": $MISSING_AGENTS_JSON,
    "recommended_count": ${#RECOMMENDED_AGENTS[@]},
    "coverage_percentage": $(( ${#AVAILABLE_AGENTS[@]} * 100 / ${#RECOMMENDED_AGENTS[@]} ))
  },
  "optimization": {
    "scope": [
      "*.${PRIMARY_LANGUAGE,,}",
      "*.md",
      "*.yaml",
      "*.yml",
      "*.json"
    ],
    "exclude": [
      ".claude/commands/",
      "node_modules/",
      "__pycache__/",
      ".venv/",
      ".git/",
      "dist/",
      "build/",
      "target/"
    ],
    "priorities": {
      "security": "HIGH",
      "performance": "MEDIUM", 
      "maintainability": "HIGH",
      "testing": "HIGH"
    }
  },
  "tooling": {
    "commands_available": {
      "git": $(command_exists git && echo "true" || echo "false"),
      "jq": $(command_exists jq && echo "true" || echo "false"),
      "gh": $(command_exists gh && echo "true" || echo "false")
    },
    "detected_commands": {
      "test": "${TEST_FRAMEWORK:-"none"}",
      "style": "${STYLE_TOOLS:-"none"}",
      "package": "${PACKAGE_MANAGER:-"none"}"
    }
  }
}
EOF

# Validate JSON if jq is available
if command_exists jq; then
    if ! jq empty "$CONFIG_TEMP_FILE" >/dev/null 2>&1; then
        echo "❌ Error: Generated configuration contains invalid JSON"
        rm -f "$CONFIG_TEMP_FILE"
        exit 1
    fi
    echo "✓ JSON configuration validated"
else
    echo "⚠️  Warning: jq not available, skipping JSON validation"
fi

# Atomically move to final location
if ! mv "$CONFIG_TEMP_FILE" "$CONFIG_FINAL_FILE"; then
    echo "❌ Error: Failed to create configuration file"
    rm -f "$CONFIG_TEMP_FILE"
    exit 1
fi

# Display configuration summary
echo "- Optimization scope: *.${PRIMARY_LANGUAGE,,}, *.md, *.yaml"
echo "- Excluded: .claude/commands/, ${PACKAGE_MANAGER:-"build"} artifacts"  
echo "- Priority focus: Security, Maintainability, Testing"
echo ""
```

## Template Generation

Create issue and report templates for consistency:

```bash
echo "Creating issue templates..."

# Create issue template
cat > ".claude/optimize/templates/issue_template.md" << 'EOF'
# Optimization Issue Template

## Issue Information
- **ID**: {ISSUE_ID}
- **Title**: {ISSUE_TITLE}
- **Priority**: {PRIORITY}
- **Category**: {CATEGORY}

## Description
{DESCRIPTION}

## Affected Files
{AFFECTED_FILES}

## Recommended Action
{RECOMMENDED_ACTION}

## Agent Assignment
- **Assigned Agent**: {ASSIGNED_AGENT}
- **Fallback Strategy**: {FALLBACK_STRATEGY}

## Test Impact
- **Existing Tests Affected**: {TEST_IMPACT}
- **New Tests Required**: {NEW_TESTS}

## Implementation Notes
- **Estimated Effort**: {EFFORT_LEVEL}
- **Dependencies**: {DEPENDENCIES}
- **Risks**: {RISKS}

## Session Context
- **Analysis Date**: {ANALYSIS_DATE}
- **Commit Range**: {COMMIT_RANGE}
- **Project Context**: {PROJECT_CONTEXT}
EOF

# Create report template
cat > ".claude/optimize/templates/report_template.md" << 'EOF'
# Optimization Report Template

## Executive Summary
- **Analysis Date**: {ANALYSIS_DATE}
- **Project Type**: {PROJECT_TYPE}
- **Issues Generated**: {ISSUE_COUNT}
- **Agent Coverage**: {AGENT_COVERAGE}

## Project Context
- **Primary Language**: {PRIMARY_LANGUAGE}
- **Framework**: {FRAMEWORK}
- **Test Framework**: {TEST_FRAMEWORK}

## Findings Summary
### By Priority
- **CRITICAL**: {CRITICAL_COUNT} issues
- **HIGH**: {HIGH_COUNT} issues  
- **MEDIUM**: {MEDIUM_COUNT} issues
- **LOW**: {LOW_COUNT} issues

### By Category
{CATEGORY_BREAKDOWN}

## Agent Performance
### Available Agents
{AVAILABLE_AGENTS_LIST}

### Missing Agents
{MISSING_AGENTS_LIST}

## Recommendations
{RECOMMENDATIONS}

## Next Steps
{NEXT_STEPS}
EOF

echo "✓ Issue templates (2 templates)"
echo ""
```

## CLAUDE.md Integration

Intelligent integration of optimization system documentation with existing CLAUDE.md:

```bash
echo "📝 CLAUDE.md Integration:"
echo "========================"

# Function for safe backup with timestamp
safe_backup_file() {
    local file="$1"
    local backup_suffix="$(date +%Y%m%d_%H%M%S)"
    if [ -f "$file" ]; then
        cp "$file" "${file}.backup_${backup_suffix}" || {
            echo "❌ Error: Failed to backup $file"
            return 1
        }
        echo "✓ Backup created: ${file}.backup_${backup_suffix}"
    fi
}

# Function to check if content section exists in CLAUDE.md
section_exists() {
    local file="$1"
    local section_marker="$2"
    [ -f "$file" ] && grep -q "^$section_marker" "$file"
}

# Function to safely insert content at end of file
append_to_file() {
    local file="$1"
    local content="$2"
    local temp_file="${file}.tmp.$$"
    
    # Create temp file with existing content plus new content
    if [ -f "$file" ]; then
        cat "$file" > "$temp_file" || return 1
    fi
    echo "$content" >> "$temp_file" || return 1
    
    # Atomic move to final location
    mv "$temp_file" "$file" || {
        rm -f "$temp_file"
        return 1
    }
}

# Function to safely update existing section
update_section() {
    local file="$1"
    local start_marker="$2"
    local end_marker="$3"
    local new_content="$4"
    local temp_file="${file}.tmp.$$"
    
    # Extract content before section
    sed -n "1,/^${start_marker}/p" "$file" | sed '$d' > "$temp_file" || return 1
    
    # Add the section markers and new content
    echo "$start_marker" >> "$temp_file"
    echo "$new_content" >> "$temp_file"
    echo "$end_marker" >> "$temp_file"
    
    # Extract content after section
    sed -n "/^${end_marker}/,\$p" "$file" | sed '1d' >> "$temp_file" || return 1
    
    # Atomic move to final location
    mv "$temp_file" "$file" || {
        rm -f "$temp_file"
        return 1
    }
}

# Generate the critical safety section content
generate_safety_section() {
    cat << 'EOF'
## 🚨 CRITICAL SAFETY WARNING: .claude/optimize/ Directory Protection

**⚠️ DIRECTORY PRESERVATION ALERT ⚠️**

The `.claude/optimize/` directory contains **IRREPLACEABLE** user optimization session data and MUST be preserved at all costs:

### 🛡️ NEVER DELETE THESE DIRECTORIES:
- `.claude/optimize/` - **Contains all optimization session history**
- `.claude/optimize/decisions/` - **User decision records and audit trails**
- `.claude/optimize/completed/` - **Completed optimization tracking**
- `.claude/optimize/agents/` - **Dynamic agent assignments and configurations**

### ❌ FORBIDDEN OPERATIONS:
```bash
# NEVER run these commands - they will cause DATA LOSS:
rm -rf .claude/optimize/          # DESTROYS all optimization history
rm -rf .claude/optimize/*         # DESTROYS all session data
rmdir .claude/optimize/           # REMOVES optimization infrastructure
find .claude/optimize/ -delete    # DELETES all optimization files
```

### ✅ SAFE FILE OPERATIONS ONLY:
```bash
# Safe: Create individual files
echo "content" > .claude/optimize/decisions/review_$(date +%s).md

# Safe: Modify existing files
echo "update" >> .claude/optimize/backlog.json

# Safe: Create directories if missing
mkdir -p .claude/optimize/decisions/
mkdir -p .claude/optimize/completed/

# Safe: Remove specific files (with confirmation)
[ -f .claude/optimize/temp.json ] && rm .claude/optimize/temp.json
```

### 📋 MANDATORY SAFETY CHECKLIST:

Before ANY operation involving `.claude/optimize/`:

1. **✓ Verify backup exists**: Check that protective backup was created (`tar -tzf`)
2. **✓ Use atomic operations**: Write to temp files, then move into place
3. **✓ Test commands first**: Use `--dry-run` or `echo` to preview operations
4. **✓ Individual file operations**: Never use wildcards or recursive delete
5. **✓ Check directory existence**: Always verify paths before operations

### 🔧 ATOMIC OPERATION PATTERNS:

```bash
# Correct: Atomic file creation
temp_file=$(mktemp)
echo "session data" > "$temp_file"
mv "$temp_file" .claude/optimize/decisions/session_123.md

# Correct: Safe file update
if [ -f .claude/optimize/backlog.json ]; then
    jq '.issues += [new_issue]' .claude/optimize/backlog.json > temp.json
    mv temp.json .claude/optimize/backlog.json
fi

# Correct: Directory structure creation
for dir in decisions completed agents; do
    mkdir -p ".claude/optimize/$dir"
done
```

### 🗂️ DATA RECOVERY REFERENCE:

If deletion occurs despite these warnings:
1. **Immediate**: Stop all optimization commands
2. **Backup**: Use the protective backup command from commit-changes.md
3. **Restore**: Extract session data from git history if available
4. **Report**: Document the incident for system improvement

### 🎯 INTEGRATION WITH GIT:

The `.claude/optimize/` directory is **intentionally excluded** from git tracking:
- **Why**: Contains user-specific session data that shouldn't be shared
- **Effect**: Each user maintains their own optimization history
- **Backup**: Use the protective tar.gz backup system instead of git

**Remember**: Once deleted, optimization session history is **PERMANENTLY LOST** and cannot be recovered from git. The backup systems are the ONLY recovery mechanism.
EOF
}

# Generate optimization system integration section
generate_optimization_integration() {
    cat << EOF
## Optimization System Integration

This project includes comprehensive optimization tracking and documentation:

**Optimization Commands Available:**
- \`/optimize\` - Analyze code changes for improvement opportunities
- \`/optimize-review\` - Make decisions on findings with flexible batch operations  
- \`/optimize-status\` - Monitor system health and progress
- \`/optimize-gh-migrate\` - Convert backlog to GitHub issues for project management
- \`/optimize-setup\` - Initialize optimization system with project-specific configuration

**Project Configuration:**
- **Project Type**: $PROJECT_TYPE
- **Primary Language**: ${PRIMARY_LANGUAGE:-"Multi-language"}
- **Framework**: ${FRAMEWORK:-"None detected"}
- **Test Framework**: ${TEST_FRAMEWORK:-"None detected"}
- **Package Manager**: ${PACKAGE_MANAGER:-"None detected"}

**Agent Configuration:**
- **Available Agents**: ${#AVAILABLE_AGENTS[@]} of ${#RECOMMENDED_AGENTS[@]} recommended
- **Customized Agents**: ${#CUSTOMIZED_AGENTS[@]} project-specific customizations
- **Agent Coverage**: $(( ${#AVAILABLE_AGENTS[@]} * 100 / ${#RECOMMENDED_AGENTS[@]} ))% of recommended agents

**Directory Structure:**
\`\`\`
.claude/optimize/
├── agents/ (${#CUSTOMIZED_AGENTS[@]} customized agents)
├── config.json (project configuration)
├── templates/ (2 issue templates)
├── decisions/ (user decision records)
├── completed/ (finished optimizations)
├── pending/ (queued optimizations)
└── backlog/ (deferred items)
\`\`\`

**Integration Points:**
- Optimization sessions automatically update \`CHANGELOG.md\`
- Requirements documentation reflects implemented improvements
- Context files updated with optimization insights for future sessions
- Cross-reference with GitHub issues for project management

**Setup Date**: $SETUP_TIMESTAMP
**Configuration**: Located at \`.claude/optimize/config.json\`
EOF
}

# Check if CLAUDE.md exists
CLAUDE_MD_PATH=".claude/CLAUDE.md"
CLAUDE_INTEGRATION_SUCCESS=false

if [ -f "$CLAUDE_MD_PATH" ]; then
    echo "Existing CLAUDE.md detected - integrating with optimization system..."
    
    # Create backup
    if safe_backup_file "$CLAUDE_MD_PATH"; then
        echo "✓ Original CLAUDE.md backed up"
    else
        echo "❌ Error: Failed to backup CLAUDE.md - aborting integration"
        echo "   Manual integration required"
        CLAUDE_INTEGRATION_SUCCESS=false
    fi
    
    # Check if safety section already exists
    if section_exists "$CLAUDE_MD_PATH" "## 🚨 CRITICAL SAFETY WARNING: .claude/optimize/ Directory Protection"; then
        echo "✓ Safety warnings already present in CLAUDE.md"
        
        # Check if integration section exists
        if section_exists "$CLAUDE_MD_PATH" "## Optimization System Integration"; then
            echo "Updating existing optimization integration section..."
            INTEGRATION_CONTENT=$(generate_optimization_integration)
            
            if update_section "$CLAUDE_MD_PATH" "## Optimization System Integration" "---" "$INTEGRATION_CONTENT"; then
                echo "✓ Optimization integration section updated"
                CLAUDE_INTEGRATION_SUCCESS=true
            else
                echo "❌ Error: Failed to update optimization integration section"
            fi
        else
            echo "Adding optimization integration section..."
            INTEGRATION_CONTENT="

---

$(generate_optimization_integration)

---

*Last updated: $SETUP_TIMESTAMP - Updated with optimization setup configuration*"
            
            if append_to_file "$CLAUDE_MD_PATH" "$INTEGRATION_CONTENT"; then
                echo "✓ Optimization integration section added"
                CLAUDE_INTEGRATION_SUCCESS=true
            else
                echo "❌ Error: Failed to add optimization integration section"
            fi
        fi
    else
        echo "Adding critical safety warnings to existing CLAUDE.md..."
        SAFETY_CONTENT="

$(generate_safety_section)"
        
        if append_to_file "$CLAUDE_MD_PATH" "$SAFETY_CONTENT"; then
            echo "✓ Safety warnings added"
            
            # Now add integration section
            echo "Adding optimization integration section..."
            INTEGRATION_CONTENT="

---

$(generate_optimization_integration)

---

*Last updated: $SETUP_TIMESTAMP - Updated with optimization setup configuration*"
            
            if append_to_file "$CLAUDE_MD_PATH" "$INTEGRATION_CONTENT"; then
                echo "✓ Optimization integration section added"
                CLAUDE_INTEGRATION_SUCCESS=true
            else
                echo "❌ Error: Failed to add optimization integration section"
            fi
        else
            echo "❌ Error: Failed to add safety warnings to CLAUDE.md"
        fi
    fi
else
    echo "No existing CLAUDE.md found - creating project-specific CLAUDE.md..."
    
    # Create new CLAUDE.md with project context
    NEW_CLAUDE_CONTENT="# $PROJECT_TYPE Project - Claude Code Configuration

This file provides guidance to Claude Code when working with this project.

## Project Overview

**Project Type**: $PROJECT_TYPE
**Primary Language**: ${PRIMARY_LANGUAGE:-"Multi-language"}
**Framework**: ${FRAMEWORK:-"None detected"}
**Test Framework**: ${TEST_FRAMEWORK:-"None detected"}

$(generate_safety_section)

## Development Context

### Technology Stack
- **Languages**: $(IFS=', '; echo "${LANGUAGES[*]}")
- **Package Manager**: ${PACKAGE_MANAGER:-"None detected"}
- **Style Tools**: ${STYLE_TOOLS:-"None detected"}
- **Git Repository**: $([ "$IS_GIT_REPO" = "true" ] && echo "Yes" || echo "No")

### Project-Specific Guidelines
- Focus on ${PRIMARY_LANGUAGE:-"multi-language"} best practices
- Ensure compatibility with ${FRAMEWORK:-"project requirements"}
- Follow ${TEST_FRAMEWORK:-"appropriate"} testing patterns
- Maintain ${STYLE_TOOLS:-"consistent"} code formatting

---

$(generate_optimization_integration)

---

*Generated: $SETUP_TIMESTAMP - Created during optimization system setup*"
    
    if echo "$NEW_CLAUDE_CONTENT" > "$CLAUDE_MD_PATH"; then
        echo "✓ Created project-specific CLAUDE.md"
        CLAUDE_INTEGRATION_SUCCESS=true
    else
        echo "❌ Error: Failed to create CLAUDE.md"
        CLAUDE_INTEGRATION_SUCCESS=false
    fi
fi

# Display integration results
if [ "$CLAUDE_INTEGRATION_SUCCESS" = "true" ]; then
    echo "✅ CLAUDE.md integration completed successfully"
    echo "   - Safety warnings: Present and updated"
    echo "   - Project context: Integrated"
    echo "   - Optimization system: Documented"
else
    echo "⚠️  CLAUDE.md integration partially failed"
    echo "   Please manually review and integrate optimization system documentation"
fi

echo ""
```

## Final Validation and Summary

Comprehensive setup completion with status display:

```bash
echo "✅ Setup Complete!"
echo "================"
echo ""

# Final validation
echo "Running setup validation..."

# Check all required files exist
VALIDATION_PASSED=true

required_files=(
    ".claude/optimize/config.json"
    ".claude/optimize/templates/issue_template.md"
    ".claude/optimize/templates/report_template.md"
)

required_dirs=(
    ".claude/optimize/agents"
    ".claude/optimize/reports"
    ".claude/optimize/pending"
    ".claude/optimize/backlog"
    ".claude/optimize/completed"
    ".claude/optimize/decisions"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ] || [ ! -r "$file" ]; then
        echo "❌ Missing or unreadable: $file"
        VALIDATION_PASSED=false
    fi
done

for dir in "${required_dirs[@]}"; do
    if [ ! -d "$dir" ] || [ ! -w "$dir" ]; then
        echo "❌ Missing or non-writable directory: $dir"
        VALIDATION_PASSED=false
    fi
done

if [ "$VALIDATION_PASSED" = "true" ]; then
    echo "✓ All required files and directories verified"
else
    echo "❌ Setup validation failed"
    echo "Some components may not work correctly"
    exit 1
fi

# Display comprehensive summary
echo ""
echo "📊 Setup Summary:"
echo "=================="
echo "✓ Project Type: $PROJECT_TYPE"
echo "✓ Primary Language: ${PRIMARY_LANGUAGE:-"Multi-language"}"
if [ -n "$FRAMEWORK" ]; then
    echo "✓ Framework: $FRAMEWORK"
fi
echo "✓ Agents: ${#CUSTOMIZED_AGENTS[@]} customized, ${#MISSING_AGENTS[@]} missing"
echo "✓ CLAUDE.md: $([ "$CLAUDE_INTEGRATION_SUCCESS" = "true" ] && echo "Successfully integrated" || echo "Integration failed - manual review needed")"

if [ ${#MISSING_AGENTS[@]} -gt 0 ]; then
    echo ""
    echo "The optimizer found ${#AVAILABLE_AGENTS[@]} of ${#RECOMMENDED_AGENTS[@]} recommended agents."
    echo "Consider adding missing agents for better analysis coverage."
fi

echo ""
echo "📁 Directory Structure:"
echo ".claude/optimize/"
echo "├── agents/ (${#CUSTOMIZED_AGENTS[@]} customized agents)"  
echo "├── config.json (project configuration)"
echo "├── templates/ (2 issue templates)"
echo "└── 5 tracking directories with .gitkeep files"

if [ "$CLAUDE_INTEGRATION_SUCCESS" = "true" ]; then
    echo ""
    echo "📝 CLAUDE.md Integration:"
    echo "✓ Critical safety warnings included"
    echo "✓ Optimization system documentation added" 
    echo "✓ Project-specific configuration documented"
    echo "✓ Backup created for existing file (if present)"
fi

echo ""
echo "🚀 Next Steps:"
echo "============="
echo "1. Run '/optimize' to analyze your code"
echo "2. Review agents in .claude/optimize/agents/ for accuracy"  
echo "3. Adjust config.json if needed"
if [ "$CLAUDE_INTEGRATION_SUCCESS" = "true" ]; then
    echo "4. Review .claude/CLAUDE.md for project-specific guidance"
else
    echo "4. Manually integrate optimization system documentation into .claude/CLAUDE.md"
fi
echo ""

if [ ${#MISSING_AGENTS[@]} -gt 0 ]; then
    echo "💡 Tip: Add missing agents to ~/.claude/agents/ for comprehensive analysis:"
    for agent in "${MISSING_AGENTS[@]:0:3}"; do
        echo "   - @$agent"
    done
    if [ ${#MISSING_AGENTS[@]} -gt 3 ]; then
        echo "   ... and $((${#MISSING_AGENTS[@]} - 3)) others"
    fi
    echo ""
fi

echo "✅ Claude Code Workflow Optimizer is ready with intelligent CLAUDE.md integration!"
```

## System Integration Check

Verify compatibility with existing optimize commands:

```bash
echo "Verifying integration with optimization system..."

# Check if other optimize commands exist
MISSING_COMMANDS=()
required_commands=("optimize.md" "optimize-review.md" "optimize-status.md")

for cmd in "${required_commands[@]}"; do
    if [ ! -f "commands/$cmd" ]; then
        MISSING_COMMANDS+=("$cmd")
    fi
done

if [ ${#MISSING_COMMANDS[@]} -gt 0 ]; then
    echo "⚠️  Warning: Some optimization commands are missing:"
    for cmd in "${MISSING_COMMANDS[@]}"; do
        echo "   - /$(basename "$cmd" .md)"
    done
    echo ""
    echo "The optimization system may not function completely without these commands."
    echo "Please install the complete Claude Code Workflow Optimizer package."
else
    echo "✓ All required optimization commands detected"
fi

# Final status
echo ""
echo "System Status: $([ ${#MISSING_COMMANDS[@]} -eq 0 ] && echo "✅ READY" || echo "⚠️  PARTIALLY READY")"
echo "Configuration saved to: .claude/optimize/config.json"
echo ""
echo "Run '/optimize-status' to see detailed system information."
```