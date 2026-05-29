#!/bin/bash
# Interactive/Automated Installer for md2html
# Author: Antigravity
# Description: Compiles and installs the pure-Bash Markdown-to-HTML converter.

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
echo -e "${BOLD}${MAGENTA}       🚀 Markdown-to-HTML Converter (md2html) Installer 🚀${NC}"
echo -e "${BOLD}${CYAN}======================================================================${NC}"
echo ""

# Get script root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || pwd)"
BUILD_SCRIPT="$SCRIPT_DIR/scripts/build.sh"

# Remote installer wrapper:
# If build.sh is not found locally, we assume the script was executed via curl pipe
# or downloaded standalone. We clone the repository into a temp directory and run it from there.
if [[ ! -f "$BUILD_SCRIPT" ]]; then
    echo -e "${BOLD}${BLUE}🌐 Running remote installation wrapper...${NC}"
    
    if ! command -v git >/dev/null 2>&1; then
        echo -e "${RED}❌ Error: 'git' command not found. Git is required to fetch dependencies for remote installation.${NC}" >&2
        echo -e "Please clone the repository manually instead:" >&2
        echo -e "  ${CYAN}git clone https://github.com/hoojinguyen/markdown-to-html.git${NC}" >&2
        exit 1
    fi
    
    TEMP_DIR=$(mktemp -d -t md2html-install-XXXXXX)
    echo -e "Fetching latest source code from GitHub..."
    if git clone --depth 1 https://github.com/hoojinguyen/markdown-to-html.git "$TEMP_DIR" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Source code fetched successfully.${NC}"
        # Execute the installer inside the temporary repository clone, passing along all args
        cd "$TEMP_DIR"
        ./install.sh "$@"
        cd - >/dev/null 2>&1
        rm -rf "$TEMP_DIR"
        exit 0
    else
        echo -e "${RED}❌ Error: Failed to clone the repository from GitHub.${NC}" >&2
        rm -rf "$TEMP_DIR"
        exit 1
    fi
fi

COMPILED_FILE="$SCRIPT_DIR/dist/md2html"

# Step 1: Run the compilation process
echo -e "${BOLD}${BLUE}[1/3] Compiling standalone executable...${NC}"
if [[ ! -f "$BUILD_SCRIPT" ]]; then
    echo -e "${RED}❌ Error: Build script not found at $BUILD_SCRIPT${NC}" >&2
    exit 1
fi

if [[ ! -x "$BUILD_SCRIPT" ]]; then
    chmod +x "$BUILD_SCRIPT"
fi

# Run the build script
if ! "$BUILD_SCRIPT"; then
    echo -e "${RED}❌ Error: Compilation failed!${NC}" >&2
    exit 1
fi

if [[ ! -f "$COMPILED_FILE" ]]; then
    echo -e "${RED}❌ Error: Compiled executable not found at $COMPILED_FILE after build.${NC}" >&2
    exit 1
fi
echo -e "${GREEN}✓ Compilation completed successfully!${NC}\n"

# Step 2: Determine installation target directory
echo -e "${BOLD}${BLUE}[2/3] Determining installation path...${NC}"

# Allow custom installation directory via first argument or PREFIX env var
INSTALL_DIR=""
USE_SUDO=false

if [[ -n "$1" ]]; then
    INSTALL_DIR="$1"
elif [[ -n "$PREFIX" ]]; then
    INSTALL_DIR="$PREFIX/bin"
else
    # Auto-detect target path
    if [[ -w "/usr/local/bin" ]]; then
        INSTALL_DIR="/usr/local/bin"
    elif [[ -d "/usr/local/bin" ]] && command -v sudo >/dev/null 2>&1; then
        INSTALL_DIR="/usr/local/bin"
        USE_SUDO=true
    else
        INSTALL_DIR="$HOME/.local/bin"
    fi
fi

# Clean up path representation (expand tilde if any, resolve relative)
INSTALL_DIR=$(eval echo "$INSTALL_DIR")
mkdir -p "$(dirname "$INSTALL_DIR")" 2>/dev/null || true

echo -e "Target Directory: ${CYAN}${INSTALL_DIR}${NC}"

# Step 3: Copy binary to destination
echo -e "${BOLD}${BLUE}[3/3] Copying executable to target...${NC}"
SUCCESS=false

if $USE_SUDO; then
    echo -e "${YELLOW}🔑 Installing to $INSTALL_DIR/md2html requires administrator privileges...${NC}"
    if sudo cp "$COMPILED_FILE" "$INSTALL_DIR/md2html" && sudo chmod +x "$INSTALL_DIR/md2html"; then
        SUCCESS=true
    else
        echo -e "${RED}⚠️  Failed to install to $INSTALL_DIR/md2html using sudo.${NC}"
        echo -e "${BLUE}🔄 Falling back to user-local directory ($HOME/.local/bin)...${NC}"
        INSTALL_DIR="$HOME/.local/bin"
        USE_SUDO=false
    fi
fi

if ! $SUCCESS; then
    mkdir -p "$INSTALL_DIR"
    if cp "$COMPILED_FILE" "$INSTALL_DIR/md2html" && chmod +x "$INSTALL_DIR/md2html"; then
        SUCCESS=true
    else
        echo -e "${RED}❌ Error: Failed to write to $INSTALL_DIR/md2html.${NC}" >&2
        exit 1
    fi
fi

echo -e "${GREEN}✓ Successfully installed 'md2html' executable to $INSTALL_DIR!${NC}\n"

# Verify installation
echo -e "${BOLD}${BLUE}Verifying installation...${NC}"
INSTALLED_BIN="$INSTALL_DIR/md2html"
if [[ -x "$INSTALLED_BIN" ]]; then
    VERSION_OUT=$("$INSTALLED_BIN" --version 2>&1 || true)
    echo -e "Executable check: ${GREEN}OK${NC}"
    echo -e "Version info:     ${GREEN}${VERSION_OUT}${NC}\n"
else
    echo -e "${RED}❌ Verification failed: Installed binary is not executable.${NC}" >&2
    exit 1
fi

# Check if the installation directory is in the user's PATH
PATH_INCLUDED=false
# Resolve absolute path of INSTALL_DIR for safe path check
ABS_INSTALL_DIR=$(cd "$INSTALL_DIR" && pwd)

if [[ ":$PATH:" == *":$ABS_INSTALL_DIR:"* ]] || [[ ":$PATH:" == *":$INSTALL_DIR:"* ]]; then
    PATH_INCLUDED=true
fi

# Detect user shell to give tailored instructions
USER_SHELL=$(basename "$SHELL")
SHELL_CONFIG=""
EXPORT_CMD="export PATH=\"$INSTALL_DIR:\$PATH\""

case "$USER_SHELL" in
    zsh)
        SHELL_CONFIG="~/.zshrc"
        ;;
    bash)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            SHELL_CONFIG="~/.bash_profile"
        else
            SHELL_CONFIG="~/.bashrc"
        fi
        ;;
    fish)
        SHELL_CONFIG="~/.config/fish/config.fish"
        EXPORT_CMD="fish_add_path $INSTALL_DIR"
        ;;
    *)
        SHELL_CONFIG="your shell configuration file"
        ;;
esac

# Success Output
echo -e "${BOLD}${GREEN}======================================================================${NC}"
echo -e "${BOLD}${GREEN}🎉 Congratulations! md2html has been successfully installed. 🎉${NC}"
echo -e "${BOLD}${GREEN}======================================================================${NC}"
echo ""

if ! $PATH_INCLUDED; then
    echo -e "${BOLD}${YELLOW}⚠️  Important Path Configuration Required:${NC}"
    echo -e "The installation directory ${CYAN}$INSTALL_DIR${NC} is not currently in your system ${BOLD}PATH${NC}."
    echo -e "To run ${BOLD}md2html${NC} directly from any terminal window, run this command or add it to your configuration:"
    echo ""
    echo -e "  ${BOLD}${CYAN}echo '${EXPORT_CMD}' >> ${SHELL_CONFIG}${NC}"
    echo -e "  ${BOLD}${CYAN}source ${SHELL_CONFIG}${NC}"
    echo ""
else
    echo -e "${GREEN}✓ Great news! $INSTALL_DIR is already in your PATH!${NC}"
    echo -e "You can run the tool from anywhere using the command: ${BOLD}${CYAN}md2html${NC}"
    echo ""
fi

echo -e "${BOLD}Quick Usage Examples:${NC}"
echo -e "  📄 Convert Markdown to raw HTML:"
echo -e "     ${CYAN}md2html document.md > render.html${NC}"
echo ""
echo -e "  🎨 Convert to beautiful standalone HTML with 'dark' theme:"
echo -e "     ${CYAN}md2html --standalone --theme dark document.md -o render.html${NC}"
echo ""
echo -e "  🚀 Stream Markdown through standard input (stdin):"
echo -e "     ${CYAN}cat document.md | md2html --standalone --theme neon > render.html${NC}"
echo ""
echo -e "Run ${BOLD}${CYAN}md2html --help${NC} to see all available options."
echo -e "${BOLD}${CYAN}======================================================================${NC}"
echo ""
