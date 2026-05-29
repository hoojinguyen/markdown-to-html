#!/bin/bash
# Block-level Markdown parsing engine and state cleaners for md2html
# Encapsulates block cleaners, lists nesting stack, and state updates.

# HTML Helper Functions
trim() {
    local var="$*"
    # Strip leading whitespace
    var="${var#"${var%%[![:space:]]*}"}"
    # Strip trailing whitespace
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

# Parser State Machine Variables
in_code_block=0
in_paragraph=0
in_table=0
in_html_block=0
current_bq_level=0
list_stack="" # Format: "type:indent type:indent ..." (stack of open list elements)

alignments=() # Array storing table alignments

# State Cleaners
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

close_html_block() {
    in_html_block=0
}

close_all() {
    close_paragraph
    close_lists
    close_blockquote
    close_table
    close_html_block
}

# Line-by-Line Block Parser
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
    # Bash 3.2 (macOS) doesn't support backreferences (\1) in [[ =~ ]], so use explicit patterns
    local is_hr=0
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*-[[:space:]]*-[-[:space:]]*$ ]]; then
        is_hr=1
    elif [[ "$line" =~ ^[[:space:]]*\*[[:space:]]*\*[[:space:]]*\*[*[:space:]]*$ ]]; then
        is_hr=1
    elif [[ "$line" =~ ^[[:space:]]*_[[:space:]]*_[[:space:]]*_[_[:space:]]*$ ]]; then
        is_hr=1
    fi
    if [[ $is_hr -eq 1 ]]; then
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

    # 6. HTML Block Detection
    # Detect lines starting with HTML block-level tags and pass them through raw.
    # This handles GitHub-style READMEs that embed raw HTML (e.g. <p align="center">, <img>, <picture>).
    local _html_block_tags='p|div|section|article|aside|header|footer|nav|main|figure|figcaption|details|summary|h1|h2|h3|h4|h5|h6|table|thead|tbody|tfoot|tr|th|td|ul|ol|li|dl|dt|dd|pre|blockquote|form|fieldset|hr|br|picture|source|img|a|strong|em|b|i|u|span|sub|sup|small|mark|del|ins|abbr|cite|dfn|kbd|samp|var|code|time|data|output|progress|meter|video|audio|canvas|svg|iframe'
    if [[ "$line" =~ ^[[:space:]]*\<(\/)?($_html_block_tags)([[:space:]]|\>|\/) ]] || [[ "$line" =~ ^[[:space:]]*\<(\/)?($_html_block_tags)\> ]]; then
        close_paragraph
        close_lists
        close_table
        in_html_block=1
        echo "$line"
        return
    fi

    # 7. Standard Paragraph Wrapper
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
