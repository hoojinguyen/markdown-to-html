#!/bin/bash
# Standalone compiler/bundler for md2html
# Packages the modular codebase and themes database into a single file with zero external dependencies.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DIST_DIR="$ROOT_DIR/dist"
SRC_DIR="$ROOT_DIR/src"
DATA_DIR="$ROOT_DIR/data"

mkdir -p "$DIST_DIR"
OUTPUT_FILE="$DIST_DIR/md2html"

echo "Compiling standalone md2html tool..."

# Create a temporary workspace directory inside SCRIPT_DIR
TEMP_BUILD_DIR=$(mktemp -d "$SCRIPT_DIR/temp_build_XXXXXX")
trap 'rm -rf "$TEMP_BUILD_DIR"' EXIT

# 1. Read themes.json and format it inside the embedded function
JSON_CONTENT=$(cat "$DATA_DIR/themes.json")
cat <<EOF > "$TEMP_BUILD_DIR/embedded_themes.sh"
_theme_registry_json_content() {
    cat <<'INNER_EOF'
$JSON_CONTENT
INNER_EOF
}
EOF

# 2. Extract and prepare theme_registry.sh (stripping shebang)
grep -v '^#!' "$SRC_DIR/theme_registry.sh" > "$TEMP_BUILD_DIR/theme_registry.sh"

# 3. Extract and prepare themes.sh (stripping shebang & sourcing)
awk '
  BEGIN { skip=0 }
  /if \[\[ -f "\$SCRIPT_DIR\/theme_registry.sh" \]\]; then/ { skip=1; next }
  skip && /^fi$/ { skip=0; next }
  skip { next }
  /^#!/ { next }
  { print }
' "$SRC_DIR/themes.sh" > "$TEMP_BUILD_DIR/themes.sh"

# 4. Extract and prepare ref_registry.sh (stripping shebang)
grep -v '^#!' "$SRC_DIR/ref_registry.sh" > "$TEMP_BUILD_DIR/ref_registry.sh"

# 5. Extract and prepare inline_transform.sh (stripping shebang & sourcing)
awk '
  BEGIN { skip=0 }
  /if \[\[ -f "\$_INLINE_DIR\/ref_registry.sh" \]\]; then/ { skip=1; next }
  skip && /^fi$/ { skip=0; next }
  skip { next }
  /^#!/ { next }
  { print }
' "$SRC_DIR/inline_transform.sh" > "$TEMP_BUILD_DIR/inline_transform.sh"

# 5b. Extract and prepare interactive.sh (stripping shebang)
grep -v '^#!' "$SRC_DIR/interactive.sh" > "$TEMP_BUILD_DIR/interactive.sh"

# 5c. Extract and prepare block_parser.sh (stripping shebang)
grep -v '^#!' "$SRC_DIR/block_parser.sh" > "$TEMP_BUILD_DIR/block_parser.sh"

# 6. Inline registries and libraries into the main script using safe temp files
awk -v build_dir="$TEMP_BUILD_DIR" '
  BEGIN { themes_replaced=0; inline_replaced=0; interactive_replaced=0; block_parser_replaced=0; skip_themes=0; skip_inline=0; skip_interactive=0; skip_block=0 }
  
  /if \[\[ -f "\$SCRIPT_DIR\/themes.sh" \]\]; then/ {
      skip_themes=1
      if (!themes_replaced) {
          print ""
          print "# =============================================================================="
          print "# EMBEDDED VISUAL THEME REGISTRY"
          print "# =============================================================================="
          system("cat " build_dir "/theme_registry.sh")
          print ""
          print "# =============================================================================="
          print "# EMBEDDED THEMES LIBRARY"
          print "# =============================================================================="
          system("cat " build_dir "/themes.sh")
          print ""
          themes_replaced=1
      }
      next
  }
  skip_themes && /^fi$/ { skip_themes=0; next }
  skip_themes { next }
  
  /if \[\[ -f "\$SCRIPT_DIR\/inline_transform.sh" \]\]; then/ {
      skip_inline=1
      if (!inline_replaced) {
          print ""
          print "# =============================================================================="
          print "# EMBEDDED LINK REFERENCE REGISTRY"
          print "# =============================================================================="
          system("cat " build_dir "/ref_registry.sh")
          print ""
          print "# =============================================================================="
          print "# EMBEDDED INLINE TRANSFORM ENGINE"
          print "# =============================================================================="
          system("cat " build_dir "/inline_transform.sh")
          print ""
          inline_replaced=1
      }
      next
  }
  skip_inline && /^fi$/ { skip_inline=0; next }
  skip_inline { next }

  /if \[\[ -f "\$SCRIPT_DIR\/interactive.sh" \]\]; then/ {
      skip_interactive=1
      if (!interactive_replaced) {
          print ""
          print "# =============================================================================="
          print "# EMBEDDED KEYBOARD INTERACTIVE CLI WIZARD"
          print "# =============================================================================="
          system("cat " build_dir "/interactive.sh")
          print ""
          interactive_replaced=1
      }
      next
  }
  skip_interactive && /^fi$/ { skip_interactive=0; next }
  skip_interactive { next }

  /if \[\[ -f "\$SCRIPT_DIR\/block_parser.sh" \]\]; then/ {
      skip_block=1
      if (!block_parser_replaced) {
          print ""
          print "# =============================================================================="
          print "# EMBEDDED BLOCK PARSER MODULE"
          print "# =============================================================================="
          system("cat " build_dir "/block_parser.sh")
          print ""
          block_parser_replaced=1
      }
      next
  }
  skip_block && /^fi$/ { skip_block=0; next }
  skip_block { next }
  
  { print }
' "$SRC_DIR/md2html.sh" > "$TEMP_BUILD_DIR/unified.sh"

# 7. Package everything into the final standalone tool, putting declarations at the top
SHEBANG=$(head -n 1 "$TEMP_BUILD_DIR/unified.sh")
MAIN_BODY=$(tail -n +2 "$TEMP_BUILD_DIR/unified.sh")

cat <<EOF > "$OUTPUT_FILE"
$SHEBANG

# ==============================================================================
# EMBEDDED THEMES DATABASE
# ==============================================================================
$(cat "$TEMP_BUILD_DIR/embedded_themes.sh")

$MAIN_BODY
EOF

chmod +x "$OUTPUT_FILE"
echo "Successfully built standalone tool at: $OUTPUT_FILE"
