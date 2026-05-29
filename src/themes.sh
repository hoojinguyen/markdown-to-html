#!/bin/bash
# CSS themes loader library for md2html.sh
# Dynamically loads declarative theme configurations from themes.json

# Find the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source visual theme registry module
if [[ -f "$SCRIPT_DIR/theme_registry.sh" ]]; then
    source "$SCRIPT_DIR/theme_registry.sh"
else
    echo "Error: theme_registry.sh not found in $SCRIPT_DIR" >&2
    exit 1
fi

load_theme_properties() {
    local theme="${1:-modern}"
    theme_registry_load "$theme"
}

render_theme_header() {
    local theme="${1:-modern}"
    local title="${2:-Markdown Document}"

    # Choose Prism.js theme based on visual theme (light vs dark)
    local prism_css="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism.min.css"
    if [[ "$theme" == "dark" || "$theme" == "neon" || "$theme" == "everforest" ]]; then
        prism_css="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism-tomorrow.min.css"
    fi

    # Render base layout header
    cat <<EOF
<!DOCTYPE html>
<html lang="en" data-theme="${theme}">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${title}</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link rel="stylesheet" href="$prism_css">
EOF

    # Output font imports if defined in the loaded theme
    local font_import
    font_import=$(theme_registry_get "font_import" "")
    if [[ -n "$font_import" ]]; then
        echo "    <link href=\"$font_import\" rel=\"stylesheet\">"
    fi

    # Retrieve all visual properties from theme registry
    local font_main font_title font_mono bg_color text_color text_muted primary primary_hover card_bg border_color code_bg code_text quote_bg quote_border heading_color list_marker_color hr_color color_scheme
    
    font_main=$(theme_registry_get "font_main" "'Inter', sans-serif")
    font_title=$(theme_registry_get "font_title" "$font_main")
    font_mono=$(theme_registry_get "font_mono" "monospace")
    bg_color=$(theme_registry_get "bg_color" "#ffffff")
    text_color=$(theme_registry_get "text_color" "#111111")
    text_muted=$(theme_registry_get "text_muted" "#666666")
    primary=$(theme_registry_get "primary" "#0066cc")
    primary_hover=$(theme_registry_get "primary_hover" "#004499")
    card_bg=$(theme_registry_get "card_bg" "#ffffff")
    border_color=$(theme_registry_get "border_color" "#cccccc")
    code_bg=$(theme_registry_get "code_bg" "#f5f5f5")
    code_text=$(theme_registry_get "code_text" "$text_color")
    quote_bg=$(theme_registry_get "quote_bg" "#f9f9f9")
    quote_border=$(theme_registry_get "quote_border" "#0066cc")
    heading_color=$(theme_registry_get "heading_color" "$text_color")
    list_marker_color=$(theme_registry_get "list_marker_color" "$text_color")
    hr_color=$(theme_registry_get "hr_color" "$border_color")
    color_scheme=$(theme_registry_get "color_scheme" "light")

    # Output dynamically loaded CSS properties
    cat <<EOF
    <style>
        :root {
            color-scheme: ${color_scheme};
            --bg-color: ${bg_color};
            --text-color: ${text_color};
            --text-muted: ${text_muted};
            --primary: ${primary};
            --primary-hover: ${primary_hover};
            --card-bg: ${card_bg};
            --border-color: ${border_color};
            --code-bg: ${code_bg};
            --code-text: ${code_text};
            --quote-bg: ${quote_bg};
            --quote-border: ${quote_border};
            --font-main: ${font_main};
            --font-title: ${font_title};
            --font-mono: ${font_mono};
            --heading-color: ${heading_color};
            --list-marker-color: ${list_marker_color};
            --hr-color: ${hr_color};
        }
EOF

    # Common styles utilizing CSS variables
    cat <<EOF
        * {
            box-sizing: border-box;
            transition: background-color 0.3s, border-color 0.3s;
        }
        body {
            font-family: var(--font-main, 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif);
            color: var(--text-color);
            background-color: var(--bg-color);
            line-height: 1.7;
            margin: 0;
            padding: 2rem 1rem;
            display: flex;
            justify-content: center;
        }
        .container {
            max-width: 800px;
            width: 100%;
            background-color: var(--card-bg);
            padding: 3rem;
            border-radius: 16px;
            box-shadow: 0 4px 20px -2px rgba(0, 0, 0, 0.05), 0 2px 10px -1px rgba(0, 0, 0, 0.03);
            border: 1px solid var(--border-color);
        }
        
        /* Neon theme specific overrides */
        :root[data-theme="neon"] .container {
            box-shadow: 0 0 20px rgba(255, 0, 127, 0.15), inset 0 0 10px rgba(0, 240, 255, 0.05);
            border: 2px solid var(--border-color);
        }
        
        /* Everforest theme specific overrides */
        :root[data-theme="everforest"] .container {
            box-shadow: 0 10px 30px -10px rgba(0, 0, 0, 0.3);
            border: 1px solid var(--border-color);
        }
        
        h1, h2, h3, h4, h5, h6 {
            font-family: var(--font-title, var(--font-main, inherit));
            font-weight: 700;
            color: var(--heading-color);
            line-height: 1.3;
            margin-top: 2rem;
            margin-bottom: 1rem;
            display: flex;
            align-items: center;
        }
        
        h1 { font-size: 2.25rem; border-bottom: 2px solid var(--border-color); padding-bottom: 0.5rem; margin-top: 1rem; }
        h2 { font-size: 1.75rem; border-bottom: 1px solid var(--border-color); padding-bottom: 0.3rem; }
        h3 { font-size: 1.4rem; }
        h4 { font-size: 1.15rem; }
        
        a {
            color: var(--primary);
            text-decoration: none;
            font-weight: 500;
            border-bottom: 1px dashed var(--primary);
            padding-bottom: 1px;
            transition: all 0.2s ease;
        }
        a:hover {
            color: var(--primary-hover);
            border-bottom: 1px solid var(--primary-hover);
        }
        
        p {
            margin-top: 0;
            margin-bottom: 1.25rem;
        }
        
        blockquote {
            margin: 1.5rem 0;
            padding: 0.75rem 1.5rem;
            background-color: var(--quote-bg);
            border-left: 4px solid var(--quote-border);
            border-radius: 4px;
            font-style: italic;
            color: var(--text-color);
        }
        blockquote p:last-child {
            margin-bottom: 0;
        }
        
        /* Lists */
        ul, ol {
            margin-top: 0;
            margin-bottom: 1.25rem;
            padding-left: 2rem;
        }
        li {
            margin-bottom: 0.5rem;
        }
        li::marker {
            color: var(--list-marker-color);
        }
        li p {
            margin-bottom: 0.25rem;
        }
        
        /* Code styling */
        code {
            font-family: var(--font-mono, 'Fira Code', 'Courier New', Courier, monospace);
            font-size: 0.9em;
            background-color: var(--code-bg);
            padding: 0.2rem 0.4rem;
            border-radius: 6px;
            border: 1px solid var(--border-color);
            color: var(--primary);
        }
        
        /* Fenced Code Block */
        pre {
            background-color: var(--code-bg);
            border-radius: 12px;
            padding: 1.25rem;
            overflow-x: auto;
            border: 1px solid var(--border-color);
            margin: 1.5rem 0;
        }
        pre code {
            background-color: transparent;
            padding: 0;
            border: none;
            color: var(--code-text);
            font-size: 0.9rem;
            line-height: 1.5;
            display: block;
        }
        
        /* Tables styling */
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 1.5rem 0;
            font-size: 0.95rem;
        }
        th, td {
            padding: 0.75rem 1rem;
            border: 1px solid var(--border-color);
            text-align: left;
        }
        th {
            background-color: var(--code-bg);
            font-weight: 600;
        }
        tr:nth-child(even) {
            background-color: rgba(0, 0, 0, 0.02);
        }
        
        /* Horizontal Rule */
        hr {
            border: 0;
            height: 1px;
            background: var(--hr-color);
            margin: 2rem 0;
        }
        
        /* Images */
        img {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
            display: block;
            margin: 1.5rem auto;
            box-shadow: 0 4px 10px rgba(0,0,0,0.05);
        }
        
        /* Keyboard shortcut input style */
        kbd {
            background: var(--code-bg);
            border: 1px solid var(--border-color);
            border-radius: 4px;
            box-shadow: 0 1px 0 rgba(0,0,0,0.2);
            color: var(--text-color);
            display: inline-block;
            font-family: inherit;
            font-size: 0.85em;
            line-height: 1.4;
            margin: 0 0.1em;
            padding: 0.1em 0.6em;
            text-shadow: 0 1px 0 #fff;
        }
        
        /* Custom scrollbar */
        ::-webkit-scrollbar {
            width: 8px;
            height: 8px;
        }
        ::-webkit-scrollbar-track {
            background: var(--bg-color);
        }
        ::-webkit-scrollbar-thumb {
            background: var(--border-color);
            border-radius: 4px;
        }
        ::-webkit-scrollbar-thumb:hover {
            background: var(--text-muted);
        }
    </style>
</head>
<body data-theme="${theme}">
    <div class="container">
EOF
}

render_theme_footer() {
    cat <<'EOF'
    </div>
    
    <!-- PrismJS for high-quality language syntax highlighting -->
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/prism.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/plugins/autoloader/prism-autoloader.min.js"></script>
    
    <!-- MermaidJS for stunning dynamic diagrams and flowcharts -->
    <script type="module">
        import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
        const theme = document.body.getAttribute('data-theme') || 'modern';
        const mermaidTheme = (theme === 'dark' || theme === 'neon' || theme === 'everforest') ? 'dark' : 'default';
        mermaid.initialize({ 
            startOnLoad: true, 
            theme: mermaidTheme,
            securityLevel: 'loose'
        });
    </script>
</body>
</html>
EOF
}
