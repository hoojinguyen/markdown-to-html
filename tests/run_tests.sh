#!/bin/bash
# Automated regression test runner for md2html.sh
# Author: Antigravity

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONVERTER="$SCRIPT_DIR/../src/md2html.sh"
TESTS_DIR="$SCRIPT_DIR"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${BOLD}Running md2html regression tests...${NC}\n"

test_cases=(
    "headers"
    "lists"
    "formatting"
    "code"
    "links_images"
    "nested"
    "tables"
    "mermaid"
)

failed=0
passed=0

for test_name in "${test_cases[@]}"; do
    md_file="$TESTS_DIR/${test_name}.md"
    expected_file="$TESTS_DIR/${test_name}.html"
    actual_file="$TESTS_DIR/${test_name}_actual.html"
    
    echo -n "Test '${test_name}': "
    
    if [[ ! -f "$md_file" ]]; then
        echo -e "${RED}[ERROR] Test markdown file not found: $md_file${NC}"
        failed=$((failed + 1))
        continue
    fi
    if [[ ! -f "$expected_file" ]]; then
        echo -e "${RED}[ERROR] Expected HTML baseline file not found: $expected_file${NC}"
        failed=$((failed + 1))
        continue
    fi
    
    # Run the converter
    set +e
    "$CONVERTER" --fragment "$md_file" > "$actual_file" 2>&1
    exit_code=$?
    set -e
    
    if [[ $exit_code -ne 0 ]]; then
        echo -e "${RED}[FAIL] (Converter failed with exit code $exit_code)${NC}"
        cat "$actual_file"
        failed=$((failed + 1))
        continue
    fi
    
    # Trim leading/trailing whitespace/newlines for comparison
    clean_actual=$(cat "$actual_file" | tr -d '\r' | awk '{$1=$1;print}' | grep -v '^$')
    clean_expected=$(cat "$expected_file" | tr -d '\r' | awk '{$1=$1;print}' | grep -v '^$')
    
    # Compare
    if diff -Bw "$expected_file" "$actual_file" > /dev/null 2>&1; then
        echo -e "${GREEN}[PASS]${NC}"
        passed=$((passed + 1))
        rm -f "$actual_file"
    else
        echo -e "${RED}[FAIL] (Outputs differ)${NC}"
        echo -e "\n--- Diff expected vs actual ---"
        diff -u "$expected_file" "$actual_file" || true
        echo -e "---------------------------------\n"
        failed=$((failed + 1))
    fi
done

echo -e "\n${BOLD}Test Summary:${NC}"
echo -e "Passed: ${GREEN}${passed}${NC}"
echo -e "Failed: ${RED}${failed}${NC}"

if [[ $failed -gt 0 ]]; then
    exit 1
else
    echo -e "\n${GREEN}${BOLD}All tests passed!${NC}"
    exit 0
fi
