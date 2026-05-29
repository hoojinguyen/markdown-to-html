#!/bin/bash
# Visual Theme Registry module for md2html.sh
# Encapsulates themes.json parsing and prevents global namespace pollution.

# Find the directory of this script
_THEME_REG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

theme_registry_clear() {
    # Find all private registry variables and unset them
    local existing_vars
    existing_vars=$(set | grep -o '^_THEME_REG_VAL_[a-zA-Z0-9_]*' || true)
    for var in $existing_vars; do
        unset "$var"
    done
}

theme_registry_load() {
    local theme="${1:-modern}"
    local json_file="${2:-$_THEME_REG_DIR/../data/themes.json}"
    
    # First, clear any currently loaded theme properties
    theme_registry_clear
    
    local var_assigns
    if [[ -f "$json_file" ]]; then
        var_assigns=$(awk -v t="$theme" '
            BEGIN { in_theme=0 }
            $0 ~ "\"" t "\"[[:space:]]*:[[:space:]]*{" { in_theme=1; next }
            in_theme && $0 ~ "^[[:space:]]*}" { in_theme=0; next }
            in_theme {
                sub(/^[[:space:]]*/, "")
                sub(/[[:space:]]*$/, "")
                if (match($0, /"[a-zA-Z0-9_]+"/)) {
                    key = substr($0, RSTART+1, RLENGTH-2)
                    val_part = substr($0, RSTART+RLENGTH)
                    if (match(val_part, /"[^"]*"/)) {
                        val = substr(val_part, RSTART+1, RLENGTH-2)
                        print key "=" val
                    }
                }
            }
        ' "$json_file")
    elif command -v _theme_registry_json_content >/dev/null 2>&1; then
        var_assigns=$(_theme_registry_json_content | awk -v t="$theme" '
            BEGIN { in_theme=0 }
            $0 ~ "\"" t "\"[[:space:]]*:[[:space:]]*{" { in_theme=1; next }
            in_theme && $0 ~ "^[[:space:]]*}" { in_theme=0; next }
            in_theme {
                sub(/^[[:space:]]*/, "")
                sub(/[[:space:]]*$/, "")
                if (match($0, /"[a-zA-Z0-9_]+"/)) {
                    key = substr($0, RSTART+1, RLENGTH-2)
                    val_part = substr($0, RSTART+RLENGTH)
                    if (match(val_part, /"[^"]*"/)) {
                        val = substr(val_part, RSTART+1, RLENGTH-2)
                        print key "=" val
                    }
                }
            }
        ')
    else
        echo "Error: themes.json not found and no embedded registry found." >&2
        return 1
    fi

    # Evaluate extracted variables safely with private prefix
    while IFS= read -r assign || [[ -n "$assign" ]]; do
        if [[ -n "$assign" && "$assign" =~ ^[a-zA-Z0-9_]+=.*$ ]]; then
            local k="${assign%%=*}"
            local v="${assign#*=}"
            eval "_THEME_REG_VAL_${k}=\"\$v\""
        fi
    done <<< "$var_assigns"
    
    return 0
}

theme_registry_get() {
    local key="$1"
    local default="$2"
    local var_name="_THEME_REG_VAL_${key}"
    
    # Retrieve variable value dynamically using eval
    local val
    eval "val=\"\$$var_name\""
    
    if [[ -n "$val" ]]; then
        echo -n "$val"
    else
        echo -n "$default"
    fi
}
