#!/bin/bash
# Link Reference Registry module for md2html.sh
# Safely encapsulates Markdown link/image reference mapping and protects global shell state.

# Global tracking variable for active reference IDs
_REF_REG_LIST=""

ref_registry_clear() {
    local clean_id
    for clean_id in $_REF_REG_LIST; do
        unset "_REF_REG_URL_${clean_id}"
        unset "_REF_REG_TITLE_${clean_id}"
        unset "_REF_REG_ORIG_${clean_id}"
    done
    _REF_REG_LIST=""
}

ref_registry_add() {
    local ref_id="$1"
    local ref_url="$2"
    local ref_title="$3"

    # Convert ref_id to a safe key (alphanumeric only, lowercase)
    local clean_id
    clean_id=$(echo "$ref_id" | tr -cd 'a-zA-Z0-9_')
    clean_id=$(echo "$clean_id" | tr 'A-Z' 'a-z')

    if [[ -n "$clean_id" ]]; then
        eval "_REF_REG_URL_${clean_id}=\"\$ref_url\""
        eval "_REF_REG_TITLE_${clean_id}=\"\$ref_title\""
        eval "_REF_REG_ORIG_${clean_id}=\"\$ref_id\""
        
        # Add to tracking list if not already present
        if [[ ! " $_REF_REG_LIST " == *" ${clean_id} "* ]]; then
            _REF_REG_LIST="${_REF_REG_LIST:+$_REF_REG_LIST }${clean_id}"
        fi
    fi
}

ref_registry_list() {
    echo -n "$_REF_REG_LIST"
}

ref_registry_get_url() {
    local clean_id="$1"
    local val
    eval "val=\"\$_REF_REG_URL_${clean_id}\""
    echo -n "$val"
}

ref_registry_get_title() {
    local clean_id="$1"
    local val
    eval "val=\"\$_REF_REG_TITLE_${clean_id}\""
    echo -n "$val"
}

ref_registry_get_orig() {
    local clean_id="$1"
    local val
    eval "val=\"\$_REF_REG_ORIG_${clean_id}\""
    echo -n "$val"
}
