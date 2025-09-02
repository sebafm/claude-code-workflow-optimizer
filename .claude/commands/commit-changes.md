---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*)
description: Create atomic git commits with conventional commit messages
---

## Context Analysis

# Sammle Git-Status und Änderungen
- Repository status: !`git status --porcelain`
- Unstaged changes: !`git diff --name-status`  
- Staged changes: !`git diff --staged --name-status`
- Current branch: !`git branch --show-current`
- Last 5 commits: !`git log --oneline -5`

## Commit Strategy

1. **Analyze changes by type and scope**
   - Group related files logically
   - Identify change patterns (feat/fix/refactor/docs)

2. **Create atomic commits using conventional format:**
   ```
   type(scope): description
   
   - feat: new features
   - fix: bug fixes  
   - refactor: code restructuring
   - docs: documentation
   - style: formatting
   - test: testing code
   ```

3. **Commit workflow:**
   - Stage related files together: `git add <files>`
   - Commit with descriptive message
   - Repeat for each logical group

## Rules
- **No mentions of AI assistants in commit messages**
- **One logical change per commit**
- **Clear, actionable commit messages**