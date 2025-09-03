# Claude Code Workflow Optimizer - Test Suite

This directory contains comprehensive tests for the optimization workflow system.

## Test Structure

```
test/
├── unit/                    # Unit tests for individual components
│   └── command_syntax_test.sh   # Validates command file syntax and structure
├── integration/             # End-to-end workflow tests
│   └── optimize_workflow_test.sh # Complete 6-command workflow validation
└── README.md               # This file
```

## Running Tests

### Quick Test (Syntax Only)
```bash
# Test command syntax and structure
./test/unit/command_syntax_test.sh
```

### Full Integration Test
```bash
# Test complete optimization workflow
./test/integration/optimize_workflow_test.sh
```

### Run All Tests
```bash
# Run complete test suite
./test/run_all_tests.sh
```

## Test Coverage

### Unit Tests
- ✅ Command file syntax validation
- ✅ YAML frontmatter structure
- ✅ Bash code block syntax
- ✅ Required field validation

### Integration Tests  
- ✅ `/optimize-setup` - Project initialization
- ✅ `/optimize` - Analysis and issue generation
- ✅ `/optimize-status` - System health monitoring
- ✅ `/optimize-review` - Decision making workflow
- ✅ `/protect-optimize-data` - Backup functionality
- ✅ End-to-end workflow validation
- ✅ File integrity verification
- ✅ Error handling and recovery

## Test Environment

Tests create isolated environments in `test/integration/test_project/` and clean up automatically. Logs are written to `test/integration/optimize_workflow_test.log` for debugging.

## Requirements

- Bash 4.0+ (cross-platform compatible)
- Git (for workflow testing)
- Basic Unix utilities (find, grep, awk)

## CI/CD Integration

These tests can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions step
- name: Run Optimization Tests
  run: |
    chmod +x test/unit/command_syntax_test.sh
    chmod +x test/integration/optimize_workflow_test.sh
    ./test/unit/command_syntax_test.sh
    ./test/integration/optimize_workflow_test.sh
```

## Test Philosophy

Tests follow the same safety-first approach as the optimization system:
- Atomic operations with cleanup
- Comprehensive error handling  
- Isolated test environments
- Detailed logging for troubleshooting

## Adding New Tests

When adding new optimization commands:

1. Add syntax validation to `unit/command_syntax_test.sh`
2. Add workflow integration to `integration/optimize_workflow_test.sh`
3. Update this README with new test coverage
4. Ensure tests clean up properly on success and failure