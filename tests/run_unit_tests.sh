#!/bin/bash
# Isolated unit test runner for md2html deep modules
# Author: Antigravity

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

failed_tests=0
total_tests=0

assert_equals() {
    local expected="$1"
    local actual="$2"
    local msg="$3"
    
    ((total_tests++))
    if [[ "$expected" == "$actual" ]]; then
        echo -e "  ${GREEN}[PASS]${NC} $msg"
    else
        echo -e "  ${RED}[FAIL]${NC} $msg"
        echo -e "    Expected: '$expected'"
        echo -e "    Actual:   '$actual'"
        failed_tests=$((failed_tests + 1))
    fi
}

echo -e "${BOLD}Running md2html Isolated Unit Tests...${NC}\n"

# ==============================================================================
# 1. Test theme_registry.sh
# ==============================================================================
echo -e "${BOLD}1. Testing Visual Theme Registry (theme_registry.sh)...${NC}"
if [[ -f "$SCRIPT_DIR/../src/theme_registry.sh" ]]; then
    source "$SCRIPT_DIR/../src/theme_registry.sh"
    
    # Test load and get defaults
    theme_registry_load "modern"
    assert_equals "#f8fafc" "$(theme_registry_get 'bg_color')" "Modern bg_color is #f8fafc"
    assert_equals "#4f46e5" "$(theme_registry_get 'primary')" "Modern primary is #4f46e5"
    assert_equals "light" "$(theme_registry_get 'color_scheme')" "Modern color_scheme defaults to light"
    
    # Test fallback
    assert_equals "FallbackVal" "$(theme_registry_get 'nonexistent_key' 'FallbackVal')" "Querying nonexistent key returns the fallback default"
    
    # Test load of another theme
    theme_registry_load "dark"
    assert_equals "#090d16" "$(theme_registry_get 'bg_color')" "Dark bg_color is loaded correctly from themes.json"
    assert_equals "#38bdf8" "$(theme_registry_get 'primary')" "Dark primary color is loaded correctly from themes.json"
    assert_equals "dark" "$(theme_registry_get 'color_scheme')" "Dark color_scheme is loaded correctly"
    
    # Test load of neon theme
    theme_registry_load "neon"
    assert_equals "#05050e" "$(theme_registry_get 'bg_color')" "Neon bg_color is loaded correctly"
    assert_equals "#00f0ff" "$(theme_registry_get 'primary')" "Neon primary color is loaded correctly"
    
    # Test clear
    theme_registry_clear
    assert_equals "Cleared" "$(theme_registry_get 'bg_color' 'Cleared')" "After clear, retrieving properties returns fallback"
else
    echo -e "  ${RED}[ERROR] theme_registry.sh not found!${NC}"
    ((failed_tests++))
fi
echo ""

# ==============================================================================
# 2. Test ref_registry.sh
# ==============================================================================
echo -e "${BOLD}2. Testing Link Reference Registry (ref_registry.sh)...${NC}"
if [[ -f "$SCRIPT_DIR/../src/ref_registry.sh" ]]; then
    source "$SCRIPT_DIR/../src/ref_registry.sh"
    
    ref_registry_clear
    assert_equals "" "$(ref_registry_list)" "Registry is initially empty"
    
    # Add references
    ref_registry_add "Google" "https://google.com" "Google Search Engine"
    ref_registry_add "github" "https://github.com" ""
    
    assert_equals "google github" "$(ref_registry_list)" "Registered IDs are properly cleaned and listed"
    assert_equals "https://google.com" "$(ref_registry_get_url 'google')" "Resolves registered URL"
    assert_equals "Google Search Engine" "$(ref_registry_get_title 'google')" "Resolves registered Title"
    assert_equals "Google" "$(ref_registry_get_orig 'google')" "Resolves registered original ID"
    
    assert_equals "https://github.com" "$(ref_registry_get_url 'github')" "Resolves second URL"
    assert_equals "" "$(ref_registry_get_title 'github')" "Resolves second Title (empty)"
    assert_equals "github" "$(ref_registry_get_orig 'github')" "Resolves second original ID"
    
    # Clear registry
    ref_registry_clear
    assert_equals "" "$(ref_registry_list)" "After clear, registry list is empty"
    assert_equals "" "$(ref_registry_get_url 'google')" "After clear, resolving URL returns empty string"
else
    echo -e "  ${RED}[ERROR] ref_registry.sh not found!${NC}"
    ((failed_tests++))
fi
echo ""

# ==============================================================================
# 3. Test inline_transform.sh
# ==============================================================================
echo -e "${BOLD}3. Testing Inline Transform Engine (inline_transform.sh)...${NC}"
if [[ -f "$SCRIPT_DIR/../src/inline_transform.sh" ]]; then
    source "$SCRIPT_DIR/../src/inline_transform.sh"
    
    # Test HTML escaping
    assert_equals "Hello &amp; World &lt;tag&gt;" "$(escape_html 'Hello & World <tag>')" "escape_html encodes HTML special characters"
    
    # Test basic bold and italics formatting
    raw_html=0
    assert_equals "<strong>Bold Text</strong>" "$(inline_transform '**Bold Text**')" "Formats double asterisk bold"
    assert_equals "<strong>Bold Text</strong>" "$(inline_transform '__Bold Text__')" "Formats double underscore bold"
    assert_equals "<em>Italic Text</em>" "$(inline_transform '*Italic Text*')" "Formats single asterisk italic"
    assert_equals "<em>Italic Text</em>" "$(inline_transform '_Italic Text_')" "Formats single underscore italic"
    assert_equals "<strong><em>Bold Italic</em></strong>" "$(inline_transform '***Bold Italic***')" "Formats triple asterisk bold-italic"
    
    # Test strikethrough
    assert_equals "<del>deleted</del>" "$(inline_transform '~~deleted~~')" "Formats strikethrough"
    
    # Test code spans
    assert_equals "<code>some code</code>" "$(inline_transform '`some code`')" "Formats inline backtick code"
    
    # Test inline links and images
    assert_equals "<a href=\"https://example.com\">Example</a>" "$(inline_transform '[Example](https://example.com)')" "Formats inline link without title"
    assert_equals '<a href="https://example.com" title="My Title">Example</a>' "$(inline_transform '[Example](https://example.com "My Title")')" "Formats inline link with title"
    assert_equals "<img src=\"/img.png\" alt=\"Image\" />" "$(inline_transform '![Image](/img.png)')" "Formats inline image without title"
    
    # Test automatic links
    assert_equals "<a href=\"https://example.org\">https://example.org</a>" "$(inline_transform '<https://example.org>')" "Formats bracket automatic HTTP link"
    
    # Test reference links integration
    ref_registry_clear
    ref_registry_add "doc-ref" "https://docs.org" "Documentation"
    
    assert_equals '<a href="https://docs.org" title="Documentation">doc-ref</a>' "$(inline_transform '[doc-ref]')" "Formats shortcut reference link"
    assert_equals "<a href=\"https://docs.org\" title=\"Documentation\">My Doc</a>" "$(inline_transform '[My Doc][doc-ref]')" "Formats full reference link"
    assert_equals '<img src="https://docs.org" alt="My Logo" title="Documentation" />' "$(inline_transform '![My Logo][doc-ref]')" "Formats reference image"
    
    # Cleanup reference registry
    ref_registry_clear
else
    echo -e "  ${RED}[ERROR] inline_transform.sh not found!${NC}"
    ((failed_tests++))
fi
echo ""

# ==============================================================================
# Summary
# ==============================================================================
echo -e "${BOLD}Unit Test Summary:${NC}"
echo -e "Passed: ${GREEN}$((total_tests - failed_tests))${NC}"
echo -e "Failed: ${RED}${failed_tests}${NC}"

if [[ $failed_tests -gt 0 ]]; then
    exit 1
else
    echo -e "\n${GREEN}${BOLD}All isolated unit tests passed!${NC}"
    exit 0
fi
