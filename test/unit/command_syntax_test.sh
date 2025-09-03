#!/bin/bash
# Unit Test: Command Syntax and Structure Validation
# Tests individual command files for bash syntax and required structure

set -e
set -u

echo "🔍 Command Syntax Validation Test"
echo "================================="

COMMANDS_DIR="commands"
PASS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0

# Function to test command syntax
test_command_syntax() {
    local cmd_file="$1"
    local cmd_name=$(basename "$cmd_file" .md)
    
    echo "Testing $cmd_name..."
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    # Check if file exists and is readable
    if [ ! -f "$cmd_file" ] || [ ! -r "$cmd_file" ]; then
        echo "  ❌ File not found or not readable: $cmd_file"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
    
    # Check for YAML frontmatter
    if ! head -5 "$cmd_file" | grep -q "^---"; then
        echo "  ❌ Missing YAML frontmatter"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
    
    # Extract bash code blocks and test syntax
    local bash_blocks_file="/tmp/${cmd_name}_bash_blocks.sh"
    
    # Extract bash code blocks (between ```bash and ```)
    awk '/```bash/,/```/' "$cmd_file" | grep -v '```' > "$bash_blocks_file" 2>/dev/null || true
    
    if [ -s "$bash_blocks_file" ]; then
        # Test bash syntax
        if bash -n "$bash_blocks_file" 2>/dev/null; then
            echo "  ✓ Bash syntax valid"
        else
            echo "  ❌ Bash syntax errors found:"
            bash -n "$bash_blocks_file" 2>&1 | head -3
            FAIL_COUNT=$((FAIL_COUNT + 1))
            rm -f "$bash_blocks_file"
            return 1
        fi
    else
        echo "  ⚠️  No bash code blocks found"
    fi
    
    # Check for required structure elements
    local structure_valid=true
    
    if ! grep -q "description:" "$cmd_file"; then
        echo "  ❌ Missing description in frontmatter"
        structure_valid=false
    fi
    
    if ! grep -q "allowed-tools:" "$cmd_file"; then
        echo "  ⚠️  No allowed-tools specified"
    fi
    
    if [ "$structure_valid" = true ]; then
        echo "  ✓ Command structure valid"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Cleanup
    rm -f "$bash_blocks_file"
    
    return $([ "$structure_valid" = true ] && echo 0 || echo 1)
}

echo "Testing optimization commands in $COMMANDS_DIR/..."
echo ""

# Test all optimize commands
for cmd_file in "$COMMANDS_DIR"/optimize*.md; do
    if [ -f "$cmd_file" ]; then
        test_command_syntax "$cmd_file"
        echo ""
    fi
done

# Test protect-optimize-data command
if [ -f "$COMMANDS_DIR/protect-optimize-data.md" ]; then
    test_command_syntax "$COMMANDS_DIR/protect-optimize-data.md"
    echo ""
fi

# Results summary
echo "📊 Test Summary:"
echo "================"
echo "Total commands tested: $TOTAL_COUNT"
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"
echo ""

if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "✅ All command syntax tests passed!"
    exit 0
else
    echo "❌ $FAIL_COUNT command(s) failed syntax validation"
    exit 1
fi