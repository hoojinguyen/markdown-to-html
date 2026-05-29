#!/bin/bash
# High-quality Markdown-to-HTML converter in pure Bash
# Author: Antigravity

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source themes library
if [[ -f "$SCRIPT_DIR/themes.sh" ]]; then
    source "$SCRIPT_DIR/themes.sh"
else
    echo "Error: themes.sh not found in $SCRIPT_DIR" >&2
    exit 1
fi

# Source inline transform module (which imports reference registry)
if [[ -f "$SCRIPT_DIR/inline_transform.sh" ]]; then
    source "$SCRIPT_DIR/inline_transform.sh"
else
    echo "Error: inline_transform.sh not found in $SCRIPT_DIR" >&2
    exit 1
fi

# Source keyboard-interactive CLI wizard module
if [[ -f "$SCRIPT_DIR/interactive.sh" ]]; then
    source "$SCRIPT_DIR/interactive.sh"
else
    echo "Error: interactive.sh not found in $SCRIPT_DIR" >&2
    exit 1
fi

# Source block parser module
if [[ -f "$SCRIPT_DIR/block_parser.sh" ]]; then
    source "$SCRIPT_DIR/block_parser.sh"
else
    echo "Error: block_parser.sh not found in $SCRIPT_DIR" >&2
    exit 1
fi

# Define colors and formatting for terminal output (text-only, no emojis/icons)
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

show_help() {
    cat <<EOF
Usage: $(basename "$0") [options] [input-file]

Options:
  -h, --help           Show this help message and exit
  -v, --version        Show version information
  -f, --fragment       Generate a raw HTML fragment (no head or styling)
  -s, --standalone     Generate a full HTML document (with head and styling) [default]
  -t, --theme THEME    Theme to use for standalone mode (everforest, modern, dark, neon, minimal) [default: everforest]
  --title TITLE        Set custom title for standalone HTML document [default: Markdown Document]
  -r, --raw-html       Allow raw HTML tags in Markdown input (otherwise escaped)
  -o, --output FILE    Write output to FILE instead of standard output

Examples:
  $(basename "$0") input.md
  cat input.md | $(basename "$0") --fragment > output.html
EOF
}

# State variables
standalone=1
theme="everforest"
title="Markdown Document"
raw_html=0
output_file=""
input_file=""
fragment=0

# If no arguments are passed and stdin is a terminal, run interactive menu
if [[ $# -eq 0 && -t 0 ]]; then
    run_interactive_cli
else
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "md2html version 1.0.0"
                exit 0
                ;;
            -s|--standalone)
                standalone=1
                fragment=0
                shift
                ;;
            -f|--fragment|--no-standalone)
                standalone=0
                fragment=1
                shift
                ;;
            -t|--theme)
                theme="$2"
                shift 2
                ;;
            --title)
                title="$2"
                shift 2
                ;;
            -r|--raw-html)
                raw_html=1
                shift
                ;;
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            *)
                if [[ -z "$input_file" ]]; then
                    input_file="$1"
                    shift
                else
                    echo "Error: Multiple input files specified." >&2
                    exit 1
                fi
                ;;
        esac
    done
fi

# If we have an input file, but no output file is specified, and stdout is a terminal,
# automatically default output_file to [input_basename].html at the same level.
if [[ -n "$input_file" && -z "$output_file" ]]; then
    if [[ -t 1 ]]; then
        if [[ "$input_file" == *.md ]]; then
            output_file="${input_file%.md}.html"
        elif [[ "$input_file" == *.markdown ]]; then
            output_file="${input_file%.markdown}.html"
        else
            output_file="${input_file}.html"
        fi
    fi
fi

# Setup output redirection if specified
if [[ -n "$output_file" ]]; then
    exec > "$output_file"
fi

# Prepare temporary file for two-pass parsing
temp_input_file=$(mktemp)

# Clean up temporary resources and clear module registries at exit
cleanup() {
    rm -f "$temp_input_file"
    if command -v ref_registry_clear >/dev/null 2>&1; then
        ref_registry_clear
    fi
    if command -v theme_registry_clear >/dev/null 2>&1; then
        theme_registry_clear
    fi
}
trap cleanup EXIT

if [[ -n "$input_file" ]]; then
    if [[ ! -f "$input_file" ]]; then
        echo "Error: Input file '$input_file' not found." >&2
        exit 1
    fi
    cat "$input_file" > "$temp_input_file"
else
    cat > "$temp_input_file"
fi

# -------------------------------------------------------------
# First Pass: Extract reference definitions
# e.g., [ref]: http://example.com "title"
# -------------------------------------------------------------
while IFS= read -r line || [[ -n "$line" ]]; do
    ref_def_regex='^[[:space:]]*\[([^]]+)\]:[[:space:]]*([^"[:space:]]+)([[:space:]]+"([^"]+)")?[[:space:]]*$'
    if [[ "$line" =~ $ref_def_regex ]]; then
        ref_id="${BASH_REMATCH[1]}"
        ref_url="${BASH_REMATCH[2]}"
        ref_title="${BASH_REMATCH[4]}"
        
        ref_registry_add "$ref_id" "$ref_url" "$ref_title"
    fi
done < "$temp_input_file"

# -------------------------------------------------------------
# Standalone Mode Document Headers
# -------------------------------------------------------------
if [[ $standalone -eq 1 ]]; then
    load_theme_properties "$theme"
    render_theme_header "$theme" "$title"
fi

# -------------------------------------------------------------
# Main Streaming Engine with Buffering for Lookahead (GFM Tables & Setext)
# -------------------------------------------------------------
prev_line=""

process_buffer() {
    if [[ -n "$prev_line" ]]; then
        local temp_line="$prev_line"
        prev_line=""
        parse_block_line "$temp_line"
    fi
}

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    # Treat trailing Carriage Returns safely (\r\n handling)
    raw_line="${raw_line%$'\r'}"
    
    # Skip reference definition lines
    ref_def_regex='^[[:space:]]*\[([^]]+)\]:[[:space:]]*([^"[:space:]]+)([[:space:]]+"([^"]+)")?[[:space:]]*$'
    if [[ "$raw_line" =~ $ref_def_regex ]]; then
        process_buffer
        continue
    fi
    
    # 1. Code Block handling (must take priority)
    if [[ "$raw_line" =~ ^[[:space:]]*\`\`\`[[:space:]]*(.*) ]]; then
        captured_lang="${BASH_REMATCH[1]}"
        process_buffer
        close_paragraph
        close_lists
        close_blockquote
        close_table
        
        lang="$captured_lang"
        lang=$(trim "$lang")
        
        if [[ $in_code_block -eq 0 ]]; then
            if [[ "$lang" == "mermaid" ]]; then
                echo "<div class=\"mermaid\">"
                in_code_block=2
            elif [[ -n "$lang" ]]; then
                echo "<pre><code class=\"language-$lang\">"
                in_code_block=1
            else
                echo "<pre><code>"
                in_code_block=1
            fi
        else
            if [[ $in_code_block -eq 2 ]]; then
                echo "</div>"
            else
                echo "</code></pre>"
            fi
            in_code_block=0
        fi
        continue
    fi
    
    if [[ $in_code_block -eq 1 ]]; then
        # Inside standard code blocks, escape HTML and render literally
        echo "$(escape_html "$raw_line")"
        continue
    elif [[ $in_code_block -eq 2 ]]; then
        # Inside mermaid block, output raw lines literally so Mermaid.js parses correctly
        echo "$raw_line"
        continue
    fi

    # 2. GFM Table Separator detection
    # Checks if line looks like: | :--- | :---: | ---: |
    is_sep=0
    if [[ "$raw_line" =~ ^[[:space:]:\|-]+$ ]] && [[ "$raw_line" == *"|"* && "$raw_line" == *"-"* ]]; then
        is_sep=1
    fi
    if [[ $is_sep -eq 1 ]] && [[ -n "$prev_line" ]]; then
        close_paragraph
        close_lists
        close_blockquote
        close_table
        
        # Alignments parser
        align_row="$raw_line"
        align_row="${align_row#|}"
        align_row="${align_row%|}"
        
        old_ifs="$IFS"
        IFS='|' read -ra sep_cells <<< "$align_row"
        IFS="$old_ifs"
        
        alignments=()
        for cell in "${sep_cells[@]}"; do
            cell=$(trim "$cell")
            if [[ "$cell" =~ ^:-+:$ ]]; then
                alignments+=("center")
            elif [[ "$cell" =~ ^:-+$ ]]; then
                alignments+=("left")
            elif [[ "$cell" =~ ^-+:$ ]]; then
                alignments+=("right")
            else
                alignments+=("left")
            fi
        done
        
        # Parse prev_line as headers
        header_row="$prev_line"
        header_row="${header_row#|}"
        header_row="${header_row%|}"
        
        IFS='|' read -ra head_cells <<< "$header_row"
        IFS="$old_ifs"
        
        echo "<table>"
        echo "<thead>"
        echo "<tr>"
        
        idx=0
        for cell in "${head_cells[@]}"; do
            cell=$(trim "$cell")
            align="${alignments[$idx]}"
            style=""
            if [[ -n "$align" ]]; then
                style=" style=\"text-align: $align;\""
            fi
            echo "  <th$style>$(inline_transform "$cell")</th>"
            ((idx++))
        done
        
        echo "</tr>"
        echo "</thead>"
        echo "<tbody>"
        
        in_table=1
        prev_line=""
        continue
    fi

    # 3. Setext Headers (Underlines)
    if [[ "$raw_line" =~ ^==+$ ]] && [[ -n "$prev_line" ]]; then
        close_paragraph
        close_lists
        close_blockquote
        close_table
        
        header_id=$(echo "$prev_line" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9 ' | tr ' ' '-')
        header_id=$(echo "$header_id" | sed -E 's/-+/-/g')
        header_id="${header_id#-}"; header_id="${header_id%-}"
        
        echo "<h1 id=\"$header_id\">$(inline_transform "$prev_line")</h1>"
        prev_line=""
        continue
    elif [[ "$raw_line" =~ ^--+$ ]] && [[ -n "$prev_line" ]]; then
        close_paragraph
        close_lists
        close_blockquote
        close_table
        
        header_id=$(echo "$prev_line" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9 ' | tr ' ' '-')
        header_id=$(echo "$header_id" | sed -E 's/-+/-/g')
        header_id="${header_id#-}"; header_id="${header_id%-}"
        
        echo "<h2 id=\"$header_id\">$(inline_transform "$prev_line")</h2>"
        prev_line=""
        continue
    fi

    # 4. Normal Table Data rows
    if [[ $in_table -eq 1 ]]; then
        # Check if line contains '|'
        if [[ "$raw_line" =~ \| ]]; then
            data_row="$raw_line"
            data_row="${data_row#|}"
            data_row="${data_row%|}"
            
            old_ifs="$IFS"
            IFS='|' read -ra data_cells <<< "$data_row"
            IFS="$old_ifs"
            
            echo "<tr>"
            idx=0
            for cell in "${data_cells[@]}"; do
                cell=$(trim "$cell")
                align="${alignments[$idx]}"
                style=""
                if [[ -n "$align" ]]; then
                    style=" style=\"text-align: $align;\""
                fi
                echo "  <td$style>$(inline_transform "$cell")</td>"
                ((idx++))
            done
            echo "</tr>"
            continue
        else
            # Not a table row, so close the table
            close_table
        fi
    fi

    # 5. Fallback stream processing (Buffering text lines to see if next line underlines/separates)
    # Check if this line is block element or empty. If so, flush buffer first, then process
    is_block=0
    if [[ "$raw_line" =~ ^(#+)[[:space:]] || "$raw_line" =~ ^[[:space:]]*[-*+][[:space:]] || "$raw_line" =~ ^[[:space:]]*[0-9]+\.[[:space:]] || "$raw_line" =~ ^[[:space:]]*\> || -z "$(trim "$raw_line")" ]]; then
        is_block=1
    fi
    # Detect HTML block-level tags as block elements so they bypass the text buffer
    _html_block_tags_main='p|div|section|article|aside|header|footer|nav|main|figure|figcaption|details|summary|h1|h2|h3|h4|h5|h6|table|thead|tbody|tfoot|tr|th|td|ul|ol|li|dl|dt|dd|pre|blockquote|form|fieldset|hr|br|picture|source|img|a|strong|em|b|i|u|span|sub|sup|small|mark|del|ins|abbr|cite|dfn|kbd|samp|var|code|time|data|output|progress|meter|video|audio|canvas|svg|iframe'
    if [[ "$raw_line" =~ ^[[:space:]]*\<(\/)?($_html_block_tags_main)([[:space:]]|\>|\/) ]] || [[ "$raw_line" =~ ^[[:space:]]*\<(\/)?($_html_block_tags_main)\> ]]; then
        is_block=1
    fi
    
    if [[ $is_block -eq 1 ]]; then
        process_buffer
        parse_block_line "$raw_line"
    else
        # Regular text line. Flush any previous non-empty buffer, then buffer current
        process_buffer
        prev_line="$raw_line"
    fi

done < "$temp_input_file"

# Flush final buffer if remaining
process_buffer

# Close open states at EOF
close_all

# -------------------------------------------------------------
# Standalone Mode Footer
# -------------------------------------------------------------
if [[ $standalone -eq 1 ]]; then
    render_theme_footer "$theme"
fi

# Print a beautiful completion card to stderr if we generated a standalone document
if [[ $fragment -eq 0 ]]; then
    display_out=""
    if [[ -n "$output_file" ]]; then
        display_out="$output_file"
    else
        display_out="standard output"
    fi
    
    echo -e "" >&2
    echo -e "${BOLD}${CYAN}======================================================================${NC}" >&2
    echo -e "${BOLD}${GREEN}Compilation Successful!${NC}" >&2
    echo -e "${BOLD}${CYAN}======================================================================${NC}" >&2
    echo -e "  Input:   ${BOLD}${input_file:-standard input}${NC}" >&2
    echo -e "  Theme:   ${BOLD}${theme}${NC}" >&2
    echo -e "  Saved:   ${BOLD}${display_out}${NC}" >&2
    
    if [[ -n "$output_file" ]]; then
        abs_output_file=""
        if [[ "$output_file" = /* ]]; then
            abs_output_file="$output_file"
        else
            abs_output_file="$(pwd)/$output_file"
        fi
        echo -e "  Link:    ${BOLD}${GREEN}file://${abs_output_file}${NC}" >&2
    fi
    echo -e "${BOLD}${CYAN}======================================================================${NC}" >&2
    echo -e "" >&2
fi
