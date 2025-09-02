# Claude Code Workflow Optimizer

This file provides guidance to Claude Code when working with this repository.

## Project Overview

The Claude Code Workflow Optimizer is a test-driven code optimization system for Claude Code users. It provides structured workflows for analyzing codebases, making improvement decisions, and implementing changes with safety guarantees.

**Current Status:** Alpha v0.1.0 - ✅ **FULLY FUNCTIONAL** - Critical fixes completed, ready for Alpha testing

## Project Structure

```
claude-code-workflow-optimizer/
├── README.md                    # Main documentation & getting started
├── ROADMAP.md                  # Development roadmap & feature planning  
├── docs/
│   ├── OPTIMIZE_SYSTEM.md      # Complete system documentation
│   └── PROJECT_REQUIREMENTS.md # Comprehensive requirements & roadmap
├── commands/                   # Slash commands for Claude Code
│   ├── optimize.md             # Analysis phase - detect optimization opportunities
│   ├── optimize-review.md      # Decision phase - user review & command generation  
│   ├── optimize-status.md      # Monitoring - system health & next steps
│   └── optimize-gh-migrate.md  # GitHub integration - convert backlog to issues
└── .claude/agents/             # Claude Code agents
    ├── project-scribe.md       # Documentation agent with optimization integration
    ├── markdown-specialist.md  # Markdown documentation expert
    ├── bash-scripting-specialist.md # Cross-platform bash scripting expert
    ├── command-reviewer.md     # Command quality reviewer
    ├── workflow-ux-designer.md # Developer workflow design expert
    ├── claude-code-integration-specialist.md # Claude Code ecosystem expert
    └── github-integration-specialist.md # GitHub features & API expert
```

## Project Boundaries

- Project commands: commands/optimize*.md (modifiable)
- Project agents: .claude/optimize/agents/*.md (modifiable)
- External tools: .claude/commands/*.md (DO NOT MODIFY)

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

## Core Concepts

### Optimization Workflow
1. **Analysis** (`/optimize`) - Scan code changes using multiple specialized agents
2. **Review** (`/optimize-review`) - User makes decisions on findings with flexible commands
3. **Implementation** - Test-first execution of selected improvements
4. **Monitoring** (`/optimize-status`) - Track progress and system health

### Test-First Philosophy
- All optimizations must pass existing tests before documentation
- Test impact analysis precedes any refactoring
- Automatic rollback on test failures
- Safety gates prevent broken code from being committed

### Agent Integration Strategy
- **v0.1.0 Current:** Hardcoded agent assignments with graceful degradation
- **v0.2.0 Planned:** Dynamic agent discovery and capability mapping
- **Philosophy:** Work with existing user agents, recommend additions when gaps detected

## Key Files & Their Purpose

### Commands (`/commands/`)
- **optimize.md**: Orchestrates analysis agents to examine code changes
- **optimize-review.md**: Processes user decisions and generates implementation commands
- **optimize-status.md**: Shows system state and suggests next actions
- **optimize-gh-migrate.md**: Converts deferred issues to GitHub issues

### Documentation
- **README.md**: User-facing documentation, installation, basic usage
- **ROADMAP.md**: Development timeline and feature planning (flexible, not date-bound)
- **CHANGELOG.md**: Complete record of all changes and optimization sessions
- **docs/OPTIMIZE_SYSTEM.md**: Complete technical documentation and troubleshooting
- **docs/PROJECT_REQUIREMENTS.md**: Comprehensive requirements, metrics, and strategic documentation

## Development Principles

### Alpha Project Approach
- **Honest Communication**: Clear about current limitations and future plans
- **User Feedback Driven**: Features prioritized based on real usage patterns
- **Iterative Development**: Small, stable improvements over large changes
- **Community-First**: Welcoming to new contributors and feedback

### Code Quality Standards
- **Markdown-First Documentation**: All guidance in readable .md files
- **No Hardcoded Assumptions**: System adapts to different environments
- **Graceful Degradation**: Missing components don't break core functionality
- **Clear Error Messages**: Users understand what went wrong and how to fix it

## Working with This Project

### When Adding Features
1. **Update ROADMAP.md** if adding new major features
2. **Test with missing agents** - ensure graceful degradation works
3. **Update docs/OPTIMIZE_SYSTEM.md** with new functionality
4. **Consider backwards compatibility** for existing users

### When Modifying Commands
1. **Test hardcoded agent assignments** work with common agent setups
2. **Ensure clean bash syntax** - no `#` comments inside code blocks  
3. **Update examples** in README.md if command interface changes
4. **Verify cross-platform compatibility** (tested on Windows via bash emulation)

### When Writing Documentation
- **Be honest about Alpha status** - set realistic expectations
- **Include practical examples** - real workflow scenarios
- **Link documents together** - create clear navigation paths
- **Test all code examples** - ensure they actually work

## Important Constraints & Preferences

### File Naming & Organization
- All commands use `.md` extension with YAML frontmatter
- Use descriptive names: `optimize-review.md` not `review.md`
- Technical documentation goes in `/docs/` directory
- Agents are located in `.claude/agents/` directory
- Keep related functionality grouped logically

### Code Style in Commands
- **No bash comments (`#`) inside code blocks** - they render as markdown headers
- Use descriptive echo statements instead of comments for clarity  
- Prefer `mkdir -p` over complex conditional directory creation
- Always handle missing files/commands gracefully
- **MANDATORY: Use atomic operations** for all `.claude/optimize/` file modifications
- **FORBIDDEN: Directory deletion commands** - especially `rm -rf .claude/optimize/`
- **REQUIRED: Individual file operations** - never use wildcards in delete operations
- **SAFETY FIRST: Test destructive commands** with `--dry-run` or `echo` before execution

### User Experience Priorities
1. **Immediate Value**: System works out-of-box with minimal setup
2. **Clear Feedback**: Users always know what's happening and what's next
3. **Safe Operations**: Never delete user data without explicit confirmation  
4. **Honest Limitations**: Upfront about what doesn't work yet

## Development Context

### Target Users
- **Primary**: Claude Code users seeking structured code optimization
- **Secondary**: Teams wanting systematic code quality processes
- **Technical Level**: Comfortable with command-line tools, basic git knowledge

### Technology Choices
- **Bash Commands**: Cross-platform compatibility via Claude Code environment
- **Markdown Documentation**: Human-readable, git-friendly, widely supported
- **JSON Data Files**: Simple structured data for issue tracking
- **GitHub CLI Integration**: Leverages existing developer workflows

### Enhanced System Implementation (September 2025) - COMPLETE 6-COMMAND WORKFLOW

**🔄 CRITICAL DATA LOSS INCIDENT - RESOLVED:**
- **Incident**: Complete `.claude/optimize/` directory deletion during first self-optimization session
- **Impact**: Total loss of optimization session history, decision records, and audit trails
- **Timeline**: September 2, 2025, approximately 13:30-14:00 UTC
- **Recovery**: Complete system restoration and enhanced preventive measures implemented

**✅ CRITICAL FIXES COMPLETED - OPT-001 through OPT-005 (VERIFIED POST-RECOVERY):**
- **OPT-001**: ✅ User input collection fixed (optimize-review now fully functional)
- **OPT-002**: ✅ Command generation logic completed (JSON parsing, agent assignment)  
- **OPT-003**: ✅ Mock data generation implemented (graceful agent fallback)
- **OPT-004**: ✅ Security vulnerabilities eliminated (command injection prevention)
- **OPT-005**: ✅ Comprehensive safety infrastructure (atomic operations, error handling)
- **OPT-006**: ✅ Intelligent project setup with automatic configuration and agent customization
- **OPT-007**: ✅ Advanced commit attribution with optimization session tracking
- **OPT-008**: ✅ Project-specific intelligence with framework-aware optimization
- **OPT-009**: ✅ Enhanced documentation system with comprehensive workflow examples
- **OPT-010**: ✅ Complete audit trail and session management system

**Enhanced System Status:**
**Intelligence Status:** 🧠 Project-specific customization operational across multiple tech stacks
**Security Status:** 🛡️ Enhanced security coverage across complete 6-command workflow
**Reliability Status:** 🔒 Bulletproof error handling with project-specific context and recovery
**Attribution Status:** 📝 Complete commit-session linking with comprehensive audit trails
**Functionality Status:** 🚀 Complete 6-command lifecycle validated and operational
**Evolution Status:** ✅ Enhanced workflow system with intelligent automation and complete documentation

### Remaining Limitations (v0.1.0)
- **Hardcoded Agent Lists**: Cannot discover or adapt to user's specific agents (planned v0.2.0)
- **Manual Installation**: Requires copying files to Claude Code directories
- **No Configuration UI**: All setup is file-based (suitable for Alpha release)

## Future Vision

### Near-term (v0.2.0)
- **Agent Auto-Discovery**: Scan user's agents and adapt optimization scope
- **Intelligent Recommendations**: Suggest missing agents based on project type
- **Better Error Messages**: Specific guidance for common setup issues

### Long-term (v1.0+)
- **GitHub App Integration**: Replace CLI with proper API integration
- **Team Workflows**: Multi-developer optimization sessions
- **Analytics Dashboard**: Track optimization impact over time

## Commands for Common Tasks

When working on this project, you'll frequently need these commands:

```bash
# Test command syntax (no execution)
claude --dry-run /optimize

# Validate markdown structure  
markdownlint *.md commands/*.md

# Check for broken internal links
find . -name "*.md" -exec grep -l "docs/OPTIMIZE_SYSTEM.md" {} \;
```

### 🛡️ Safety Verification Commands

**ALWAYS run these before ANY .claude/optimize/ operations:**

```bash
# Verify optimize directory structure exists and is protected
ls -la .claude/optimize/ 2>/dev/null || echo "Directory missing - safe to create"

# Check for existing optimization session data
find .claude/optimize/ -name "*.json" -o -name "*.md" 2>/dev/null | wc -l

# Verify backup protection exists (should show tar.gz files)
ls -la .claude/*backup*.tar.gz 2>/dev/null || echo "No backups found - create backup first"

# Test atomic operation pattern (safe preview)
echo "mkdir -p .claude/optimize/decisions/" && echo "echo 'test' > /tmp/test.tmp && mv /tmp/test.tmp .claude/optimize/test.json"

# Verify git ignore is protecting optimize directory
git check-ignore .claude/optimize/test.json && echo "✅ Protected by .gitignore" || echo "❌ WARNING: Not protected by .gitignore"
```

### 🚨 Emergency Data Protection Commands

**If you suspect .claude/optimize/ might be at risk:**

```bash
# Create immediate protective backup
tar -czf ".claude/optimize-emergency-backup-$(date +%s).tar.gz" .claude/optimize/ 2>/dev/null

# Verify backup was created successfully
ls -la .claude/optimize-emergency-backup-*.tar.gz | tail -1

# Test backup integrity
tar -tzf .claude/optimize-emergency-backup-*.tar.gz | head -5
```

## Notes for Claude Code

- This is an **early-stage open source project** - be encouraging and constructive
- **Test safety** is paramount - never suggest changes that could break user's workflow  
- **🚨 DATA PROTECTION PRIORITY**: Never suggest operations that could delete `.claude/optimize/`
- **ATOMIC OPERATIONS REQUIRED**: All file modifications in `.claude/optimize/` must use temp-file-then-move pattern
- **BACKUP VERIFICATION**: Always confirm protective backups exist before optimization operations
- When updating commands, **preserve backward compatibility** where possible
- **Ask clarifying questions** if requirements seem to conflict with Alpha constraints
- **Suggest gradual improvements** rather than major architectural changes
- Always consider **user experience impact** of any modifications suggested
- **INCIDENT AWARENESS**: This project has recovered from a complete `.claude/optimize/` deletion incident - prevention is critical

---

## Optimization System Integration

This project includes comprehensive optimization tracking and documentation:

**Optimization Commands Available:**
- `/optimize` - Analyze code changes for improvement opportunities
- `/optimize-review` - Make decisions on findings with flexible batch operations  
- `/optimize-status` - Monitor system health and progress
- `/optimize-gh-migrate` - Convert backlog to GitHub issues for project management

**Recent Optimization Results (Post-Recovery):**
- **Session Date**: September 2, 2025
- **Issues Implemented**: 5 critical functionality and security fixes (verified post-recovery)
- **Security Impact**: All command injection vulnerabilities eliminated (verified operational)
- **Reliability Impact**: Bulletproof error handling with atomic operations, enhanced with recovery procedures
- **Data Loss Incident**: Complete recovery from .claude/optimize/ directory deletion
- **System Status**: Ready for Alpha user testing with enhanced data protection

**Integration Points:**
- Optimization sessions automatically update `CHANGELOG.md`
- Requirements documentation reflects implemented improvements
- Context files updated with optimization insights for future sessions
- Cross-reference with GitHub issues for project management

---

*Last updated: September 2, 2025 - Updated with optimization session results*