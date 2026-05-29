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

show_help() {
    cat <<EOF
Usage: $(basename "$0") [options] [input-file]

Options:
  -h, --help           Show this help message and exit
  -v, --version        Show version information
  -s, --standalone     Generate a full HTML document (with <head> and styling)
  -t, --theme THEME    Theme to use for standalone mode (modern, dark, neon, minimal) [default: modern]
  --title TITLE        Set custom title for standalone HTML document [default: Markdown Document]
  -r, --raw-html       Allow raw HTML tags in Markdown input (otherwise escaped)
  -o, --output FILE    Write output to FILE instead of standard output

Examples:
  $(basename "$0") input.md > output.html
  cat input.md | $(basename "$0") --standalone --theme dark > output.html
EOF
}

# State variables
standalone=0
theme="modern"
title="Markdown Document"
raw_html=0
output_file=""
input_file=""

# Parse arguments
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
# HTML Helper Functions
# -------------------------------------------------------------
trim() {
    local var="$*"
    # Strip leading whitespace
    var="${var#"${var%%[![:space:]]*}"}"
    # Strip trailing whitespace
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

# -------------------------------------------------------------
# Parser State Machine Variables
# -------------------------------------------------------------
in_code_block=0
in_paragraph=0
in_table=0
current_bq_level=0
list_stack="" # Format: "type:indent type:indent ..." (stack of open list elements)

alignments=() # Array storing table alignments

# -------------------------------------------------------------
# State Cleaners
# -------------------------------------------------------------
close_paragraph() {
    if [[ $in_paragraph -eq 1 ]]; then
        echo "</p>"
        in_paragraph=0
    fi
}

close_blockquote() {
    while [[ $current_bq_level -gt 0 ]]; do
        echo "</blockquote>"
        ((current_bq_level--))
    done
}

pop_list() {
    if [[ -n "$list_stack" ]]; then
        local top_item="${list_stack##* }"
        local top_type="${top_item%:*}"
        echo "</li>"
        echo "</$top_type>"
        if [[ "$list_stack" == *" "* ]]; then
            list_stack="${list_stack% *}"
        else
            list_stack=""
        fi
    fi
}

close_lists() {
    while [[ -n "$list_stack" ]]; do
        pop_list
    done
}

close_table() {
    if [[ $in_table -eq 1 ]]; then
        echo "</tbody>"
        echo "</table>"
        in_table=0
    fi
}

close_all() {
    close_paragraph
    close_lists
    close_blockquote
    close_table
}

# -------------------------------------------------------------
# Line-by-Line Block Parser
# -------------------------------------------------------------
parse_block_line() {
    local raw_line="$1"
    local line="$raw_line"
    
    # 1. Blockquote Detection
    local bq_level=0
    local temp="$line"
    while [[ "$temp" =~ ^[[:space:]]*\>[[:space:]]*(.*) ]]; do
        ((bq_level++))
        temp="${BASH_REMATCH[1]}"
    done
    
    # Update blockquote tags based on change in nesting depth
    if [[ $bq_level -gt $current_bq_level ]]; then
        close_paragraph
        close_lists
        close_table
        while [[ $current_bq_level -lt $bq_level ]]; do
            echo "<blockquote>"
            ((current_bq_level++))
        done
    elif [[ $bq_level -lt $current_bq_level ]]; then
        close_paragraph
        close_lists
        close_table
        while [[ $current_bq_level -gt $bq_level ]]; do
            echo "</blockquote>"
            ((current_bq_level--))
        done
    fi
    
    # If we are inside blockquotes, strip them off and continue parsing the inside content
    if [[ $bq_level -gt 0 ]]; then
        line="$temp"
    fi

    # 2. Empty Line Handling
    if [[ -z "$(trim "$line")" ]]; then
        close_paragraph
        close_lists
        close_table
        # Output empty line for structure spacing
        echo ""
        return
    fi
    
    # 3. Horizontal Rules
    if [[ "$line" =~ ^[[:space:]]*(\*|\-|_)[[:space:]]*\1[[:space:]]*\1[[:space:]]*(\1|[[:space:]])*$ ]]; then
        close_paragraph
        close_lists
        close_table
        echo "<hr />"
        return
    fi

    # 4. ATX-style Headers
    if [[ "$line" =~ ^(#+)[[:space:]]+(.*) ]]; then
        local hashes="${BASH_REMATCH[1]}"
        local header_text="${BASH_REMATCH[2]}"
        local depth=${#hashes}
        if [[ $depth -le 6 ]]; then
            close_paragraph
            close_lists
            close_table
            
            local transformed_text
            transformed_text=$(inline_transform "$header_text")
            
            # Generate ID for link anchor
            local header_id
            header_id=$(echo "$header_text" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9 ' | tr ' ' '-')
            header_id=$(echo "$header_id" | sed -E 's/-+/-/g')
            header_id="${header_id#-}"
            header_id="${header_id%-}"
            
            echo "<h$depth id=\"$header_id\">$transformed_text</h$depth>"
            return
        fi
    fi

    # 5. Lists (Nested list processor)
    # Unordered list: starting with * or - or +
    # Ordered list: starting with 1. or 2. etc
    local is_list=0
    local list_type=""
    local item_content=""
    local indent=0
    
    # Get indentation count
    local temp_indent="$line"
    while [[ "${temp_indent:0:1}" == " " ]]; do
        ((indent++))
        temp_indent="${temp_indent:1}"
    done
    
    if [[ "$line" =~ ^[[:space:]]*[-*+][[:space:]]+(.*) ]]; then
        is_list=1
        list_type="ul"
        item_content="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]*[0-9]+\.[[:space:]]+(.*) ]]; then
        is_list=1
        list_type="ol"
        item_content="${BASH_REMATCH[1]}"
    fi
    
    if [[ $is_list -eq 1 ]]; then
        close_paragraph
        close_table
        
        # Calculate list stack changes
        if [[ -z "$list_stack" ]]; then
            # Brand new list structure
            list_stack="${list_type}:${indent}"
            echo "<${list_type}>"
            echo "<li>$(inline_transform "$item_content")"
        else
            local top_item="${list_stack##* }"
            local top_type="${top_item%:*}"
            local top_indent="${top_item#*:}"
            
            if [[ $indent -gt $top_indent ]]; then
                # Nested list starts
                list_stack="${list_stack} ${list_type}:${indent}"
                echo "<${list_type}>"
                echo "<li>$(inline_transform "$item_content")"
            elif [[ $indent -lt $top_indent ]]; then
                # Nested list closes down to current indent
                while [[ -n "$list_stack" ]]; do
                    local cur_top="${list_stack##* }"
                    local cur_indent="${cur_top#*:}"
                    if [[ $cur_indent -gt $indent ]]; then
                        pop_list
                    else
                        break
                    fi
                done
                
                # Check top of stack now
                if [[ -z "$list_stack" ]]; then
                    list_stack="${list_type}:${indent}"
                    echo "<${list_type}>"
                    echo "<li>$(inline_transform "$item_content")"
                else
                    local cur_top="${list_stack##* }"
                    local cur_type="${cur_top%:*}"
                    local cur_indent="${cur_top#*:}"
                    
                    if [[ $cur_indent -eq $indent && $cur_type == "$list_type" ]]; then
                        echo "</li>"
                        echo "<li>$(inline_transform "$item_content")"
                    else
                        # Mismatched type or indent
                        pop_list
                        list_stack="${list_stack:+$list_stack }${list_type}:${indent}"
                        echo "<${list_type}>"
                        echo "<li>$(inline_transform "$item_content")"
                    fi
                fi
            else # indent -eq top_indent
                if [[ $top_type == "$list_type" ]]; then
                    echo "</li>"
                    echo "<li>$(inline_transform "$item_content")"
                else
                    pop_list
                    list_stack="${list_stack:+$list_stack }${list_type}:${indent}"
                    echo "<${list_type}>"
                    echo "<li>$(inline_transform "$item_content")"
                fi
            fi
        fi
        return
    else
        # If line doesn't match list structure, but list stack is not empty:
        # Check if this line is indented continuation of the active list item
        # If not, close all lists!
        if [[ -n "$list_stack" ]]; then
            local top_item="${list_stack##* }"
            local top_indent="${top_item#*:}"
            if [[ $indent -lt $((top_indent + 2)) ]]; then
                close_lists
            fi
        fi
    fi

    # 6. Standard Paragraph Wrapper
    if [[ $in_paragraph -eq 0 ]]; then
        close_lists
        if [[ $bq_level -eq 0 ]]; then
            close_blockquote
        fi
        close_table
        echo "<p>"
        in_paragraph=1
    fi
    echo "$(inline_transform "$line")"
}

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
