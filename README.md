# Claude Code Workflow Optimizer

**Test-driven code optimization system with GitHub integration for Claude Code**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Compatible-blue)](https://docs.anthropic.com/en/docs/claude-code)
[![GitHub Integration](https://img.shields.io/badge/GitHub-CLI%20Integration-green)](https://cli.github.com/)
[![Alpha Release](https://img.shields.io/badge/Status-Alpha%20v0.1.0-orange)](https://github.com/sebafm/claude-code-workflow-optimizer/releases)

> **⚠️ Alpha Release Notice:** This is an early-stage project (v0.1.0) under active development. Core functionality works, but the API may change based on user feedback. Perfect for experimentation and feedback, use with caution in production environments.

## Overview

Claude Code Workflow Optimizer is a comprehensive system that integrates seamlessly with Claude Code to provide automated, test-driven code optimization workflows. It analyzes your codebase for quality, architecture, security, and performance issues, then guides you through a structured decision process to implement improvements safely.

### Key Features

🔍 **Automated Code Analysis** - Deep analysis of code changes across multiple dimensions  
🧪 **Test-First Approach** - TDD-driven optimization ensures no regressions  
📋 **Structured Decision Making** - Review and prioritize optimization opportunities  
🐙 **GitHub Integration** - Create issues directly from optimization sessions  
📊 **Progress Tracking** - Comprehensive history and status monitoring  
🛡️ **Safe Operations** - Isolated file structure preserves existing configurations

## Quick Start

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and configured
- [GitHub CLI](https://cli.github.com/) (optional, for GitHub integration)
- Git repository with existing codebase
- Test suite (recommended for test-driven optimization)

### Installation

**Note:** As an alpha release, installation requires manual setup. We're working toward simpler installation methods in future versions.

1. **Clone the repository:**
   ```bash
   git clone https://github.com/sebafm/claude-code-workflow-optimizer.git
   cd claude-code-workflow-optimizer
   ```

2. **Copy commands to your Claude Code commands directory:**
   ```bash
   cp commands/*.md ~/.claude/commands/
   ```

3. **Copy the enhanced project-scribe agent:**
   ```bash
   cp agents/project-scribe.md ~/.claude/agents/
   ```

4. **Verify installation:**
   ```bash
   claude-code /optimize-status
   ```

For detailed system documentation, troubleshooting, and advanced usage, see [OPTIMIZE_SYSTEM.md](OPTIMIZE_SYSTEM.md).

### Basic Usage

The optimizer follows a simple 4-step workflow:

```bash
# 1. Analyze your code changes
/optimize

# 2. Review and make decisions
/optimize-review
# Input: "Implement #1, #3, gh-issue #2, Skip #4"

# 3. Execute improvements
bash .claude/optimize/pending/commands.sh

# 4. Check system status
/optimize-status
```

## Core Commands

### `/optimize` - Analysis Phase
Analyzes recent code changes and generates structured optimization recommendations across:
- **Code Quality** - Performance, maintainability, patterns
- **Architecture** - Design alignment, API consistency
- **Security** - Vulnerabilities, best practices
- **Testing** - Coverage gaps, test impact analysis

### `/optimize-review` - Decision Phase
Interactive decision-making with flexible command syntax:

**Individual Decisions:**
```bash
"Implement #1, #3, #8"                    # Immediate implementation
"Defer #2, #4 --comment='After v2.0'"    # Backlog for later
"gh-issue #5, #7 --comment='Sprint planning'" # Create GitHub issues
"Skip #6, #10"                            # Permanently dismiss
```

**Batch Operations:**
```bash
"Implement all critical"      # Priority-based batch operations
"gh-issue all high"          # Create issues for all high-priority items
"Skip all low"               # Dismiss all low-priority issues
"Defer all"                  # Move everything to backlog
```

### `/optimize-status` - Monitoring
Real-time dashboard showing:
- Pending issues awaiting review
- Backlogged items for future sessions
- Completed optimizations history
- Recent activity and next steps

### `/optimize-gh-migrate` - GitHub Integration
Convert backlogged issues to GitHub issues for project management:
```bash
"Convert all"                # Migrate entire backlog
"Convert #2, #4"            # Specific issues
"Convert all high"          # Priority-based conversion
```

## Test-Driven Approach

The optimizer follows a rigorous test-first methodology:

1. **Test Impact Analysis** - Identifies which tests will be affected by proposed changes
2. **Test Updates** - Updates or creates tests before implementation
3. **Guided Implementation** - Subagents implement changes with test safety guards
4. **Validation Gates** - All changes must pass tests before documentation
5. **Rollback on Failure** - Automatic rollback if tests fail

This ensures **zero regressions** and maintains code quality throughout optimization.

## File Structure

The system creates an isolated directory structure that preserves your existing Claude Code configuration:

```
.claude/
├── agents/           # Your existing agents (preserved)
├── commands/         # Your existing commands (preserved)  
└── optimize/         # Optimization System (isolated)
    ├── pending/      # Current session data
    ├── backlog/      # Deferred issues
    ├── completed/    # Implementation history
    ├── decisions/    # Decision tracking
    └── reports/      # Detailed analysis reports
```

## Integration with Subagents

The system leverages specialized Claude Code subagents for comprehensive analysis and implementation. The current release includes optimized versions of these general-purpose agents:

### **Included Agents**
- **`@code-reviewer`** - Code quality, performance, and maintainability analysis
- **`@database-architect`** - Database optimization and data access patterns
- **`@security-auditor`** - Security vulnerability assessment and best practices
- **`@test-automation-engineer`** - Test impact analysis and automated test updates
- **`@project-scribe`** - Enhanced documentation and change tracking with optimization integration
- **`@task-decomposer`** - Complex task breakdown and structured implementation planning

### **Agent Configuration**
The system automatically detects available agents and can be customized via configuration:

```json
// ~/.claude/optimize/config/active-agents.json
{
  "analysis_agents": [
    "code-reviewer",
    "database-architect", 
    "security-auditor",
    "test-automation-engineer"
  ],
  "implementation_agents": [
    "task-decomposer",
    "project-scribe"
  ],
  "custom_agents": [
    "your-custom-performance-agent"
  ]
}
```

**Analysis Phase:** Configured analysis agents examine code changes from their specialized perspectives
**Implementation Phase:** Task decomposition and guided implementation with automatic documentation

### **Extensibility**
- **Custom Agents**: Add your own domain-specific agents to the configuration
- **Agent Discovery**: System automatically detects new agents matching the expected interface
- **Selective Usage**: Enable/disable agents based on project needs and optimization focus

## Advanced Features

### GitHub Integration
- **Issue Creation** - Structured GitHub issues with optimization context
- **Label Management** - Automatic labeling by priority and category
- **Backlog Migration** - Convert deferred items to project management issues
- **Tracking Integration** - Links optimization sessions to GitHub activity

### Decision Tracking
- **Historical Record** - Complete audit trail of all optimization decisions
- **Comment System** - Rich context for why decisions were made
- **Progress Metrics** - Quantitative tracking of optimization impact
- **Team Coordination** - Shareable reports for team alignment

### Safety Features
- **Isolated Structure** - No interference with existing Claude Code setup
- **Safe Cleanup** - `rm -rf .claude/optimize/` without affecting agents/commands
- **Test Validation** - Mandatory test passage before changes are documented
- **Rollback Support** - Easy recovery from problematic optimizations

## Examples

### Daily Development Workflow
```bash
# After implementing a feature
git commit -m "feat: user authentication system"

# Run optimization analysis
/optimize
# → Finds 6 issues: 2 security, 2 performance, 1 architecture, 1 testing

# Strategic decision making
/optimize-review
# → "Implement #1, #4 (critical security), gh-issue #2, #3 (for next sprint), Defer #5, #6"

# Execute with confidence
bash .claude/optimize/pending/commands.sh
# → Tests updated → Changes implemented → Tests pass → Documentation updated
```

### Sprint Planning Integration
```bash
# Convert optimization findings to sprint items
/optimize-review
# → "gh-issue all high --comment='Sprint 2024-Q1'"

# Result: Structured GitHub issues ready for sprint planning
```

### Quarterly Cleanup
```bash
# Review accumulated backlog
/optimize-status
# → Shows 15 deferred issues from past sessions

# Convert to GitHub for project management
/optimize-gh-migrate
# → "Convert all --comment='Q1 tech debt cleanup'"
```

## Documentation & Examples

### Available Now
- **Installation** - See Quick Start section above
- **Basic Usage** - Core commands and examples throughout this README
- **Complete System Guide** - [OPTIMIZE_SYSTEM.md](OPTIMIZE_SYSTEM.md) for detailed workflows, troubleshooting, and advanced usage
- **Roadmap** - [ROADMAP.md](ROADMAP.md) for planned features and timeline

### Coming Soon
We're actively working on comprehensive documentation:

- **📚 Detailed Installation Guide** - Platform-specific instructions and troubleshooting
- **🔄 Workflow Guide** - Advanced usage patterns and best practices  
- **💡 Examples Repository** - Real-world scenarios and integration patterns
- **🛠️ Troubleshooting Guide** - Common issues and solutions

**Help us prioritize:** [What documentation would be most useful?](https://github.com/sebafm/claude-code-workflow-optimizer/issues/new?labels=documentation&template=documentation-request.md)

## Contributing

We welcome contributions and feedback! This is an early-stage project and community input is invaluable.

### Current Focus
- **User feedback** on core workflow and command interface
- **Agent compatibility** testing across different setups
- **Documentation improvements** and real-world usage examples
- **Bug reports** and edge case identification

### Development Setup
```bash
git clone https://github.com/sebafm/claude-code-workflow-optimizer.git
cd claude-code-workflow-optimizer
# Test commands in a separate Claude Code environment
```

### How to Contribute
1. **Try the Alpha** - Use the commands in your projects
2. **Report Issues** - Share bugs, edge cases, or unexpected behavior  
3. **Request Features** - Tell us what optimization scenarios you need
4. **Improve Documentation** - Help us write better guides and examples
5. **Share Usage** - Show us how you're using the optimizer

**First-time contributors welcome!** This is a learning-friendly project.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support & Community

- **Questions & Usage Help**: [GitHub Discussions](https://github.com/sebafm/claude-code-workflow-optimizer/discussions)
- **Bug Reports**: [GitHub Issues](https://github.com/sebafm/claude-code-workflow-optimizer/issues/new?template=bug_report.md)
- **Feature Requests**: [GitHub Issues](https://github.com/sebafm/claude-code-workflow-optimizer/issues/new?template=feature_request.md)
- **Documentation Requests**: [GitHub Issues](https://github.com/sebafm/claude-code-workflow-optimizer/issues/new?labels=documentation)

**Alpha Users:** Your feedback shapes the future of this project!

---

**Made with ❤️ for the Claude Code community**
