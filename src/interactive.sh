#!/bin/bash
# Keyboard-interactive CLI UI Wizard for md2html
# Encapsulates terminal menus and interactive configuration prompts.

# Helper function to render a keyboard interactive option selector
select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    local selected=0
    local num_options=${#options[@]}
    
    # Hide cursor
    echo -ne "\033[?25l" >&2
    
    # Print prompt
    echo -e "${BOLD}${CYAN}${prompt}${NC}" >&2
    
    while true; do
        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                echo -e "\033[K  ${BOLD}${GREEN}-> ${options[$i]}${NC}" >&2
            else
                echo -e "\033[K     ${options[$i]}" >&2
            fi
        done
        
        # Read a single key press, handling arrow key escape sequences
        local key=""
        read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.05 key2
            if [[ "$key2" == "[A" ]]; then
                ((selected--))
                if [[ $selected -lt 0 ]]; then
                    selected=$((num_options - 1))
                fi
            elif [[ "$key2" == "[B" ]]; then
                ((selected++))
                if [[ $selected -ge $num_options ]]; then
                    selected=0
                fi
            fi
        elif [[ "$key" == "" ]]; then
            break
        fi
        
        # Move cursor back up to redraw the options
        echo -ne "\033[${num_options}A" >&2
    done
    
    # Show cursor again
    echo -ne "\033[?25h" >&2
    
    # Clear the options and prompt lines from the terminal screen
    echo -ne "\033[${num_options}A" >&2
    echo -ne "\033[1A" >&2
    for ((i=0; i<=num_options; i++)); do
        echo -ne "\033[K\n" >&2
    done
    echo -ne "\033[$((num_options + 1))A" >&2
    
    return $selected
}

# Interactive CLI UI Wizard
run_interactive_cli() {
    echo -e "${BOLD}${CYAN}======================================================================${NC}" >&2
    echo -e "${BOLD}${MAGENTA}       Markdown-to-HTML (md2html) Interactive Compiler${NC}" >&2
    echo -e "${BOLD}${CYAN}======================================================================${NC}" >&2
    echo "" >&2

    local md_files=()
    while IFS= read -r file; do
        [[ -n "$file" ]] && md_files+=("$file")
    done < <(find . -maxdepth 1 \( -name "*.md" -o -name "*.markdown" \) -not -name ".*" | sed 's|^\./||' | sort)

    if [[ ${#md_files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}Warning: No Markdown files (.md or .markdown) found in the current directory ($(pwd)).${NC}" >&2
        echo "" >&2
        select_option "What would you like to do?" \
            "Enter path to a Markdown file manually" \
            "Exit"
        local choice=$?
        if [[ $choice -eq 0 ]]; then
            echo -ne "${BOLD}${CYAN}Enter path to Markdown file: ${NC}" >&2
            read -r input_file
            if [[ ! -f "$input_file" ]]; then
                echo -e "${RED}Error: File '$input_file' not found.${NC}" >&2
                exit 1
            fi
        else
            echo -e "${BLUE}Exiting. Have a nice day!${NC}" >&2
            exit 0
        fi
    else
        select_option "Select a Markdown file to convert:" "${md_files[@]}"
        input_file="${md_files[$?]}"
    fi

    echo -e "Selected File: ${GREEN}${BOLD}${input_file}${NC}" >&2
    echo "" >&2

    local themes=("everforest" "modern" "dark" "neon" "minimal")
    select_option "Select a visual theme:" \
        "everforest (default)" \
        "modern" \
        "dark" \
        "neon" \
        "minimal"
    local theme_idx=$?
    theme="${themes[$theme_idx]}"
    echo -e "Selected Theme: ${GREEN}${BOLD}${theme}${NC}" >&2
    echo "" >&2

    echo -ne "${BOLD}${CYAN}Enter document title [Markdown Document]: ${NC}" >&2
    read -r custom_title
    if [[ -z "$custom_title" ]]; then
        title="Markdown Document"
    else
        title="$custom_title"
    fi
    echo -e "Document Title: ${GREEN}${BOLD}${title}${NC}" >&2
    echo "" >&2

    # Calculate default output name
    local default_output=""
    if [[ "$input_file" == *.md ]]; then
        default_output="${input_file%.md}.html"
    elif [[ "$input_file" == *.markdown ]]; then
        default_output="${input_file%.markdown}.html"
    else
        default_output="${input_file}.html"
    fi

    echo -ne "${BOLD}${CYAN}Enter output file name [${default_output}]: ${NC}" >&2
    read -r custom_output
    if [[ -z "$custom_output" ]]; then
        output_file="$default_output"
    else
        output_file="$custom_output"
    fi
    echo -e "Output File: ${GREEN}${BOLD}${output_file}${NC}" >&2
    echo "" >&2

    # Set parameters
    standalone=1
    fragment=0
}
