#!/bin/bash
# Inline Transform Engine module for md2html.sh
# Centralizes inline syntax formatting (bold, italics, code, links, images) and HTML escaping.

# Find the directory of this script
_INLINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source reference registry module
if [[ -f "$_INLINE_DIR/ref_registry.sh" ]]; then
    source "$_INLINE_DIR/ref_registry.sh"
else
    echo "Error: ref_registry.sh not found in $_INLINE_DIR" >&2
    exit 1
fi

escape_html() {
    local str="$1"
    str="${str//&/&amp;}"
    str="${str//</&lt;}"
    str="${str//>/&gt;}"
    str="${str//\"/&quot;}"
    str="${str//\'/&#39;}"
    echo -n "$str"
}

inline_transform() {
    local line="$1"
    
    # 1. Escape backslash characters temporarily to prevent them from matching Markdown syntax
    line="${line//\\\*/ESCAPEDASTERISK}"
    line="${line//\\_/ESCAPEDUNDERSCORE}"
    line="${line//\\\`/ESCAPEDBACKTICK}"
    line="${line//\\~/ESCAPEDTILDE}"
    line="${line//\\!/ESCAPEDEXCLAMATION}"
    line="${line//\\\[/ESCAPEDLBRACKET}"
    line="${line//\\\]/ESCAPEDRBRACKET}"
    line="${line//\\\(/ESCAPEDLPAREN}"
    line="${line//\\\)/ESCAPEDRPAREN}"
    line="${line//\\\\/ESCAPEDBACKSLASH}"

    # 2. Escape raw HTML if --raw-html is NOT specified (raw_html is read globally)
    local raw_html_val="${raw_html:-0}"
    if [[ $raw_html_val -eq 0 ]]; then
        line=$(escape_html "$line")
    fi

    # 3. Inline Code Blocks (backticks)
    line=$(echo "$line" | sed -E 's/`([^`]+)`/<code>\1<\/code>/g')

    # 4. Images (inline)
    # With title (handles both literal quote and escaped quote)
    line=$(echo "$line" | sed -E 's/!\[([^]]*)\]\(([^"& )]+)[[:space:]]+(\"|&quot;)([^"&]+)(\"|&quot;)\)/<img src="\2" alt="\1" title="\4" \/>/g')
    # Without title
    line=$(echo "$line" | sed -E 's/!\[([^]]*)\]\(([^) ]+)\)/<img src="\2" alt="\1" \/>/g')

    # 5. Links (inline)
    # With title
    line=$(echo "$line" | sed -E 's/\[([^]]+)\]\(([^"& )]+)[[:space:]]+(\"|&quot;)([^"&]+)(\"|&quot;)\)/<a href="\2" title="\4">\1<\/a>/g')
    # Without title
    line=$(echo "$line" | sed -E 's/\[([^]]+)\]\(([^) ]+)\)/<a href="\2">\1<\/a>/g')

    # 6. Reference Links and Images (from Link Reference Registry)
    local ref_vars
    ref_vars=$(ref_registry_list)
    for clean_id in $ref_vars; do
        local url
        url=$(ref_registry_get_url "$clean_id")
        local ref_title
        ref_title=$(ref_registry_get_title "$clean_id")
        local orig_id
        orig_id=$(ref_registry_get_orig "$clean_id")
        
        # Escape special characters in orig_id for regex matching
        local esc_orig_id
        esc_orig_id=$(echo "$orig_id" | sed 's/[]\/$*.^|[]/\\&/g')
        
        # Escape variables for safe HTML output
        local esc_url
        esc_url=$(escape_html "$url")
        local esc_title
        esc_title=$(escape_html "$ref_title")
        
        # Replace reference image: ![alt][orig_id]
        if [[ -n "$ref_title" ]]; then
            line=$(echo "$line" | sed -E "s|!\[([^]]*)\]\[$esc_orig_id\]|<img src=\"$esc_url\" alt=\"\1\" title=\"$esc_title\" \/>|g")
            line=$(echo "$line" | sed -E "s|\[([^]]+)\]\[$esc_orig_id\]|<a href=\"$esc_url\" title=\"$esc_title\">\1<\/a>|g")
        else
            line=$(echo "$line" | sed -E "s|!\[([^]]*)\]\[$esc_orig_id\]|<img src=\"$esc_url\" alt=\"\1\" \/>|g")
            line=$(echo "$line" | sed -E "s|\[([^]]+)\]\[$esc_orig_id\]|<a href=\"$esc_url\">\1<\/a>|g")
        fi
        
        # Shortcut reference links: [orig_id][] or [orig_id]
        if [[ -n "$ref_title" ]]; then
            line=$(echo "$line" | sed -E "s|\[$esc_orig_id\]\[\]|<a href=\"$esc_url\" title=\"$esc_title\">$orig_id<\/a>|g")
            line=$(echo "$line" | sed -E "s|\[$esc_orig_id\]|<a href=\"$esc_url\" title=\"$esc_title\">$orig_id<\/a>|g")
        else
            line=$(echo "$line" | sed -E "s|\[$esc_orig_id\]\[\]|<a href=\"$esc_url\">$orig_id<\/a>|g")
            line=$(echo "$line" | sed -E "s|\[$esc_orig_id\]|<a href=\"$esc_url\">$orig_id<\/a>|g")
        fi
    done

    # 7. Automatic Links: <http://...> or <email@...>
    line=$(echo "$line" | sed -E 's/<(https?:\/\/[^>]+)>/<a href="\1">\1<\/a>/g')
    line=$(echo "$line" | sed -E 's/&lt;(https?:\/\/[^&]+)&gt;/<a href="\1">\1<\/a>/g')
    line=$(echo "$line" | sed -E 's/<([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})>/<a href="mailto:\1">\1<\/a>/g')
    line=$(echo "$line" | sed -E 's/&lt;([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})&gt;/<a href="mailto:\1">\1<\/a>/g')

    # 8. Strong & Emphasis (Bold & Italic)
    # Bold-Italic: ***text*** or ___text___
    line=$(echo "$line" | sed -E 's/\*\*\*([^*]+)\*\*\*/<strong><em>\1<\/em><\/strong>/g')
    line=$(echo "$line" | sed -E 's/___([^_]+)___/<strong><em>\1<\/em><\/strong>/g')
    # Bold: **text** or __text__
    line=$(echo "$line" | sed -E 's/\*\*([^*]+)\*\*/<strong>\1<\/strong>/g')
    line=$(echo "$line" | sed -E 's/__([^_]+)__/<strong>\1<\/strong>/g')
    # Italic: *text* or _text_
    line=$(echo "$line" | sed -E 's/\*([^*]+)\*/<em>\1<\/em>/g')
    line=$(echo "$line" | sed -E 's/_([^_]+)_/<em>\1<\/em>/g')

    # 9. Strikethrough: ~~text~~
    line=$(echo "$line" | sed -E 's/~~([^~]+)~~/<del>\1<\/del>/g')

    # 10. Line breaks: two spaces at end of line -> <br/>
    line=$(echo "$line" | sed -E 's/[[:space:]]{2,}$/<br\/>/')

    # 11. Restore backslash escaped characters
    line="${line//ESCAPEDASTERISK/*}"
    line="${line//ESCAPEDUNDERSCORE/_}"
    line="${line//ESCAPEDBACKTICK/\`}"
    line="${line//ESCAPEDTILDE/~~}"
    line="${line//ESCAPEDEXCLAMATION/!}"
    line="${line//ESCAPEDLBRACKET/\[}"
    line="${line//ESCAPEDRBRACKET/\]}"
    line="${line//ESCAPEDLPAREN/\(}"
    line="${line//ESCAPEDRPAREN/\)}"
    line="${line//ESCAPEDBACKSLASH/\\}"

    echo -n "$line"
}
