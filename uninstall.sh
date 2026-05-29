#!/bin/bash
# Interactive/Automated Uninstaller for md2html
# Author: Antigravity
# Description: Removes the md2html CLI executable from the system.

set -eo pipefail

# Define colors and formatting for a premium terminal UI
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Print header
echo -e "${BOLD}${CYAN}======================================================================${NC}"
echo -e "${BOLD}${MAGENTA}       Markdown-to-HTML Converter (md2html) Uninstaller${NC}"
echo -e "${BOLD}${CYAN}======================================================================${NC}"
echo ""

# Get script root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || pwd)"

# Parse arguments
FORCE=false
CUSTOM_PATH=""

show_help() {
    echo -e "Usage: ./uninstall.sh [options] [custom_installation_path]"
    echo ""
    echo -e "Options:"
    echo -e "  -h, --help     Show this help message and exit"
    echo -e "  -y, --yes      Non-interactive mode (automatically confirm removal)"
    echo -e "  -f, --force    Alias for --yes"
    echo ""
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        -y|--yes|-f|--force)
            FORCE=true
            shift
            ;;
        *)
            if [[ -z "$CUSTOM_PATH" ]]; then
                CUSTOM_PATH="$1"
            else
                echo -e "${RED}Error: Unknown argument '$1'${NC}" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# Expand custom path if provided
if [[ -n "$CUSTOM_PATH" ]]; then
    CUSTOM_PATH=$(eval echo "$CUSTOM_PATH")
fi

# Detect installed binaries
echo -e "${BOLD}${BLUE}Scanning system for md2html installations...${NC}"

declare -a FOUND_BINS=()

# 1. Custom path if provided
if [[ -n "$CUSTOM_PATH" ]]; then
    CUSTOM_BIN="$CUSTOM_PATH/md2html"
    if [[ -f "$CUSTOM_BIN" ]]; then
        FOUND_BINS+=("$CUSTOM_BIN")
    fi
fi

# 2. Standard paths
STANDARD_PATHS=(
    "/usr/local/bin/md2html"
    "$HOME/.local/bin/md2html"
)
for p in "${STANDARD_PATHS[@]}"; do
    p_expanded=$(eval echo "$p")
    if [[ -f "$p_expanded" ]]; then
        FOUND_BINS+=("$p_expanded")
    fi
done

# 3. PATH resolution
if command -v which >/dev/null 2>&1; then
    while IFS= read -r line; do
        if [[ -n "$line" && -f "$line" ]]; then
            FOUND_BINS+=("$line")
        fi
    done < <(which -a md2html 2>/dev/null || true)
fi

# Deduplicate
if [[ ${#FOUND_BINS[@]} -gt 0 ]]; then
    # Sort and unique
    IFS=$'\n' sorted_bins=($(sort -u <<<"${FOUND_BINS[*]}"))
    unset IFS
    FOUND_BINS=("${sorted_bins[@]}")
fi

# Remove the script itself or build source from global list
CLEAN_FOUND_BINS=()
for b in "${FOUND_BINS[@]}"; do
    # Do not include the local repo builds in the global list, we will handle that separately
    if [[ "$b" != "$SCRIPT_DIR/dist/md2html" && "$b" != "$SCRIPT_DIR/uninstall.sh" ]]; then
        CLEAN_FOUND_BINS+=("$b")
    fi
done
FOUND_BINS=("${CLEAN_FOUND_BINS[@]}")

# Count of installations
INST_COUNT=${#FOUND_BINS[@]}

if [[ $INST_COUNT -eq 0 ]]; then
    echo -e "${YELLOW}No installed instances of 'md2html' were found in your standard folders or PATH.${NC}"
else
    echo -e "${GREEN}Found $INST_COUNT installation(s) of md2html:${NC}"
    for b in "${FOUND_BINS[@]}"; do
        echo -e "  - ${CYAN}$b${NC}"
    done
fi
echo ""

# Confirm uninstall
CONFIRMED=$FORCE
if ! $CONFIRMED; then
    if [[ $INST_COUNT -gt 0 ]]; then
        echo -n -e "${BOLD}${YELLOW}Are you sure you want to uninstall md2html and remove all detected installations? (y/N): ${NC}"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            CONFIRMED=true
        else
            echo -e "${BLUE}Uninstall cancelled by user.${NC}"
            exit 0
        fi
    else
        echo -n -e "${BOLD}${YELLOW}Would you like to scan and clean the local repository build artifacts? (y/N): ${NC}"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            CONFIRMED=true
        else
            echo -e "${BLUE}No operations performed.${NC}"
            exit 0
        fi
    fi
fi

# Perform deletion of global binaries
DELETED_COUNT=0
if [[ $INST_COUNT -gt 0 ]]; then
    echo -e "${BOLD}${BLUE}Removing installations...${NC}"
    for b in "${FOUND_BINS[@]}"; do
        echo -e "Removing ${CYAN}$b${NC}..."
        
        # Determine if we have write access or need sudo
        PARENT_DIR=$(dirname "$b")
        if [[ -w "$b" ]] || { [[ ! -e "$b" ]] && [[ -w "$PARENT_DIR" ]]; }; then
            if rm -f "$b"; then
                echo -e "  ${GREEN}✓ Successfully removed.${NC}"
                ((DELETED_COUNT++))
            else
                echo -e "  ${RED}✗ Failed to remove.${NC}" >&2
            fi
        else
            echo -e "  ${YELLOW}Write permission denied. Attempting removal with sudo...${NC}"
            if sudo rm -f "$b"; then
                echo -e "  ${GREEN}✓ Successfully removed using sudo.${NC}"
                ((DELETED_COUNT++))
            else
                echo -e "  ${RED}✗ Failed to remove using sudo.${NC}" >&2
            fi
        fi
    done
    echo ""
fi

# Offer / perform local repo cleanup
LOCAL_CLEANED=false
LOCAL_BUILD="$SCRIPT_DIR/dist"
if [[ -d "$LOCAL_BUILD" ]]; then
    CLEAN_LOCAL=$FORCE
    if ! $CLEAN_LOCAL; then
        echo -n -e "${BOLD}${YELLOW}Would you like to remove the local build directory inside the repository ('dist/')? (y/N): ${NC}"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            CLEAN_LOCAL=true
        fi
    fi
    
    if $CLEAN_LOCAL; then
        echo -e "${BLUE}Cleaning local build artifacts...${NC}"
        if rm -rf "$LOCAL_BUILD"; then
            echo -e "  ${GREEN}✓ Successfully removed local '$LOCAL_BUILD' directory.${NC}"
            LOCAL_CLEANED=true
        else
            echo -e "  ${RED}✗ Failed to remove local build artifacts.${NC}" >&2
        fi
        echo ""
    fi
fi

# Success Banner
echo -e "${BOLD}${GREEN}======================================================================${NC}"
echo -e "${BOLD}${GREEN}Uninstall complete!${NC}"
echo -e "${BOLD}${GREEN}======================================================================${NC}"
echo ""
if [[ $DELETED_COUNT -gt 0 ]]; then
    echo -e "${GREEN}Removed $DELETED_COUNT globally installed executable(s).${NC}"
fi
if $LOCAL_CLEANED; then
    echo -e "${GREEN}Cleaned up repository build artifacts.${NC}"
fi

# PATH check & cleaning recommendation
USER_SHELL=$(basename "$SHELL")
SHELL_CONFIG=""
case "$USER_SHELL" in
    zsh)   SHELL_CONFIG="~/.zshrc" ;;
    bash)  SHELL_CONFIG="~/.bash_profile (or ~/.bashrc)" ;;
    fish)  SHELL_CONFIG="~/.config/fish/config.fish" ;;
    *)     SHELL_CONFIG="your shell configuration file" ;;
esac

echo -e "\n${BOLD}${YELLOW}Note on Shell Configuration:${NC}"
echo -e "If you previously added md2html to your system PATH in your shell configuration, you can safely remove it now."
echo -e "Open ${CYAN}$SHELL_CONFIG${NC} and look for any line containing:"
case "$USER_SHELL" in
    fish)
        echo -e "  ${BOLD}${MAGENTA}fish_add_path .../bin${NC}"
        ;;
    *)
        echo -e "  ${BOLD}${MAGENTA}export PATH=\".../bin:\$PATH\"${NC}"
        ;;
esac
echo -e "\n${BOLD}${CYAN}======================================================================${NC}"
