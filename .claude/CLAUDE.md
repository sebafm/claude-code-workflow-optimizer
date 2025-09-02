# Claude Code Workflow Optimizer

This file provides guidance to Claude Code when working with this repository.

## Project Overview

The Claude Code Workflow Optimizer is a test-driven code optimization system for Claude Code users. It provides structured workflows for analyzing codebases, making improvement decisions, and implementing changes with safety guarantees.

**Current Status:** Alpha v0.1.0 - Core functionality working, API may evolve based on user feedback.

## Project Structure

```
claude-code-workflow-optimizer/
├── README.md                    # Main documentation & getting started
├── ROADMAP.md                  # Development roadmap & feature planning  
├── docs/
│   └── OPTIMIZE_SYSTEM.md      # Complete system documentation
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
- **docs/OPTIMIZE_SYSTEM.md**: Complete technical documentation and troubleshooting

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

### Current Limitations (v0.1.0)
- **Hardcoded Agent Lists**: Cannot discover or adapt to user's specific agents
- **Manual Installation**: Requires copying files to Claude Code directories
- **Basic Error Handling**: Limited guidance when things go wrong
- **No Configuration UI**: All setup is file-based

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

## Notes for Claude Code

- This is an **early-stage open source project** - be encouraging and constructive
- **Test safety** is paramount - never suggest changes that could break user's workflow  
- When updating commands, **preserve backward compatibility** where possible
- **Ask clarifying questions** if requirements seem to conflict with Alpha constraints
- **Suggest gradual improvements** rather than major architectural changes
- Always consider **user experience impact** of any modifications suggested

---

*Last updated: September 2025 - This file should be updated as the project evolves*