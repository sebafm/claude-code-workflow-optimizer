#!/bin/bash
# Test Runner: Execute all tests in the correct order

set -e

echo "🧪 Claude Code Workflow Optimizer - Test Suite"
echo "==============================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run a test and track results
run_test() {
    local test_name="$1"
    local test_script="$2"
    
    echo "Running $test_name..."
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ ! -f "$test_script" ]; then
        echo "❌ Test script not found: $test_script"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
    
    if [ ! -x "$test_script" ]; then
        echo "⚠️  Making test script executable: $test_script"
        chmod +x "$test_script"
    fi
    
    echo "----------------------------------------"
    
    if "$test_script"; then
        echo "✅ $test_name - PASSED"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        echo ""
        return 0
    else
        echo "❌ $test_name - FAILED"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo ""
        return 1
    fi
}

# Test execution order
echo "📋 Test Execution Plan:"
echo "1. Unit Tests - Command syntax validation"
echo "2. Integration Tests - End-to-end workflow"
echo ""

# Run unit tests first
echo "🔬 Phase 1: Unit Tests"
echo "====================="
run_test "Command Syntax Validation" "$SCRIPT_DIR/unit/command_syntax_test.sh"

# Run integration tests
echo "🔗 Phase 2: Integration Tests"
echo "============================="
run_test "Complete Workflow Validation" "$SCRIPT_DIR/integration/optimize_workflow_test.sh"

# Test results summary
echo "🏁 Test Suite Results"
echo "===================="
echo "Total tests run: $TOTAL_TESTS"
echo "Passed: $PASSED_TESTS"
echo "Failed: $FAILED_TESTS"
echo ""

if [ "$FAILED_TESTS" -eq 0 ]; then
    echo "🎉 All tests passed! The optimization workflow is ready for production use."
    echo ""
    echo "✅ Command syntax and structure validated"
    echo "✅ End-to-end workflow tested and verified"
    echo "✅ Safety mechanisms and error handling confirmed"
    echo "✅ File integrity and data protection verified"
    exit 0
else
    echo "💥 $FAILED_TESTS test(s) failed. Please review the output above."
    echo ""
    echo "🔧 Troubleshooting:"
    echo "- Check command file syntax in commands/ directory"
    echo "- Ensure all required dependencies are installed"
    echo "- Review test logs in test/integration/ directory"
    echo "- Verify file permissions and directory structure"
    exit 1
fi