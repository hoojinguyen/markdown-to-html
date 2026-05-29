# How to Build a Markdown-to-HTML Converter in Pure Bash

## Executive Summary

Building a markdown-to-HTML converter in pure bash is feasible and has been accomplished by several projects. The key approach is **line-by-line or chunk-by-chunk processing combined with string transformations**, using either bash parameter expansion or sed for pattern matching and replacement.

Two proven strategies exist:

1. **Sed-heavy approach** (e.g., markdown.bash): Uses sed's hold/pattern space for multi-line matching. Covers ~95% of Markdown. 368 lines, highly portable, requires GNU sed.[^1]

2. **Line-by-line state machine** (e.g., shockrah's translate.sh): Simple case-based parsing. 62 lines, very fast, handles common elements well.[^2]

For a minimal tool supporting core markdown elements (headings, emphasis, lists, links, code, paragraphs, blockquotes), a line-by-line state machine approach is recommended. For near-complete Markdown support, the sed-based approach is more robust.

---

## What You Need to Know

### Markdown Syntax to Support

**Core Elements (Essential):**
- ATX-style headers: `# H1`, `## H2`, etc.
- Emphasis: `*italic*`, `**bold**`
- Paragraphs: Text separated by blank lines
- Links (inline): `[text](url)`
- Images (inline): `![alt](url)`
- Inline code: `` `code` ``
- Code blocks: Triple backticks or indented 4+ spaces
- Unordered lists: Lines starting with `*` or `-`
- Blockquotes: Lines starting with `>`

**Extended Elements (Optional):**
- Setext-style headers: Underlined with `=` or `-`
- Reference-style links: `[text][ref]` with `[ref]: url` definitions
- Ordered lists: `1. item`, `2. item`
- Nested blockquotes
- Special character escaping: `\*`, `\_`, etc.

---

## Implementation Approach 1: Minimal Line-by-Line Parser

### Overview

Read the markdown file line by line, use case statements to identify block-level elements (headers, lists, blockquotes, code blocks), and track state for multi-line constructs. This approach is recommended by shockrah's implementation.[^2]

### Pseudocode

```bash
#!/bin/bash

# Initialize state variables
in_code_block=0
in_list=0
in_blockquote=0

while IFS= read -r line; do
    case "$line" in
        ^\#\#*) 
            # Header: extract level and convert to <h#>
            ;;
        ^\*|^\-) 
            # List item: wrap in <li>, track list state
            ;;
        ^\>) 
            # Blockquote: wrap in <blockquote>
            ;;
        ^\`\`\`) 
            # Code block toggle
            ;;
        ^$) 
            # Empty line: close open tags if needed
            ;;
        *) 
            # Paragraph or continuation: apply inline transformations
            # - Replace *text* with <em>text</em>
            # - Replace **text** with <strong>text</strong>
            # - Replace [text](url) with <a href="url">text</a>
            # - Replace `code` with <code>code</code>
            ;;
    esac
done < input.md
```

### Key Bash Techniques

#### 1. **Header Conversion**

```bash
header() {
    local line="$1"
    # Count leading # characters
    local depth=$(echo "$line" | grep -o '^#\+' | wc -m)
    # Extract text after the hashes
    local text="${line:$depth}"
    echo "<h$depth>$text</h$depth>"
}

# Usage: header "## My Heading"
# Output: <h2> My Heading</h2>
```

#### 2. **Inline Transformations Using Parameter Expansion or sed**

**Option A: Bash Parameter Expansion (pure bash, no sed)**

```bash
# Replace **bold** with <strong>bold</strong>
text="${text//\*\*/<strong>}"
text="${text//\*\*/<\/strong>}"
# Note: This naive approach has issues with overlapping patterns
```

**Option B: sed (more reliable)**

```bash
line=$(echo "$line" | sed -E 's/\*\*([^*]+)\*\*/<strong>\1<\/strong>/g')
line=$(echo "$line" | sed -E 's/\*([^*]+)\*/<em>\1<\/em>/g')
line=$(echo "$line" | sed -E 's/\[([^\]]+)\]\(([^)]+)\)/<a href="\2">\1<\/a>/g')
line=$(echo "$line" | sed -E 's/`([^`]+)`/<code>\1<\/code>/g')
```

#### 3. **List Tracking with State Variables**

```bash
list_open=0
blockquote_open=0

process_line() {
    local line="$1"
    
    # Close lists if line doesn't start with * or -
    if [[ ! "$line" =~ ^[\*\-] ]] && [[ $list_open -eq 1 ]]; then
        echo "</ul>"
        list_open=0
    fi
    
    # Open or continue list
    if [[ "$line" =~ ^[\*\-] ]]; then
        if [[ $list_open -eq 0 ]]; then
            echo "<ul>"
            list_open=1
        fi
        item_text="${line#[\*\-] }"  # Remove leading * or -
        echo "<li>$item_text</li>"
    fi
}
```

#### 4. **Multi-line Code Blocks**

```bash
code_block=0

while IFS= read -r line; do
    if [[ "$line" =~ ^\`\`\` ]]; then
        if [[ $code_block -eq 0 ]]; then
            echo "<pre><code>"
            code_block=1
        else
            echo "</code></pre>"
            code_block=0
        fi
    elif [[ $code_block -eq 1 ]]; then
        echo "$line"  # Preserve line as-is in code block
    fi
done
```

---

## Implementation Approach 2: Sed-Based Full Markdown Parser

### Overview

Use sed with multi-line pattern space manipulation (hold and pattern space) to handle complex transformations. This is the approach pioneered by markdown.bash, which handles reference-style links, setext headers, and nested blockquotes.[^1]

### Key sed Techniques

#### 1. **Multi-line Pattern Matching**

```bash
# Use the hold space to accumulate lines
sed -nri '
# If empty line, branch to process accumulated text
/^$/ b process

# Else append to hold space
H
$ b process
b

:process
x
# Apply transformations on multi-line text
s/\n\n/<\/p>\n<p>/g
p
'
```

#### 2. **Blockquote Processing** (markdown.bash approach)

```bash
# Loop while blockquotes exist
while grep '^> ' file.md >/dev/null
do
    sed -nri '
/^$/b blockquote

H
$ b blockquote
b

:blockquote
x
s/(\n+)(> .*)/\1<blockquote>\n\2\n<\/blockquote>/
p
' "$temp_file"

    sed -i '1 d' "$temp_file"
    sed -ri '/^> /s/^> (.*)/\1/' "$temp_file"
done
```

#### 3. **Header Detection (Setext and ATX)**

```bash
# Setext-style (underlined) via markdown.bash
sed -nri '
/^$/ b print
H
$ b print
b

:print
x
/=+$/{
    s/\n(.*)\n=+$/\n<h1>\1<\/h1>/
    p
}
'

# ATX-style (hashes)
sed -E 's/^# (.*)/&lt;h1&gt;\1&lt;\/h1&gt;/;
        s/^## (.*)/&lt;h2&gt;\1&lt;\/h2&gt;/'
```

### Advantages

- Handles complex multi-line constructs naturally
- One-pass or few-pass operation possible
- Highly efficient for large files

### Disadvantages

- GNU sed required (BSD sed has different syntax); markdown.bash recommends aliasing gsed on macOS where both are installed[^1]
- Complex sed scripts are hard to debug and maintain
- Steep learning curve for hold/pattern space manipulation

---

## Practical Comparison: Two Reference Implementations

### markdown.bash (Full Coverage)

According to its documentation,[^1] markdown.bash implements approximately 95% of Markdown language with the following characteristics:

| Aspect | Details |
|--------|---------|
| Lines of code | 368 |
| Coverage | ~95% of Markdown spec |
| Dependencies | Bash, GNU sed, grep, cut |
| Performance | Fast; handles medium to large files |
| Debuggability | Moderate (complex sed scripts) |
| Extension | Medium difficulty |

**Key features (from markdown.bash):[^1]**
- Setext-style headers (underlined with `=` or `-`)
- ATX-style headers (`# Heading`)
- Emphasis (*italic*, **bold**)
- Blockquotes
- Unordered and ordered lists
- Code blocks (indented and fenced)
- Inline code (backticks)
- Links (inline and reference-style)
- Images (inline and reference-style)
- Automatic links (`<http://...>`)
- Email links
- Special character escaping

**Key weaknesses per documentation:[^1]**
- Does not convert email addresses to entity-encoding
- Processes Markdown inside block-level HTML (spec says not to)
- Requires hard breaks between block-level elements due to line-by-line sed nature

### shockrah's translate.sh (Minimal, Fast)

As documented on the shockrah blog,[^2] this approach uses a simple bash script with strategic use of sed:

| Aspect | Details |
|--------|---------|
| Lines of code | 62 |
| Coverage | Core markdown + inline transformations |
| Dependencies | Bash, sed, grep, perl (cleanup) |
| Performance | Very fast; minimal overhead |
| Debuggability | Excellent (simple case statements) |
| Extension | Easy; add new case branches |

**Key strengths:[^2]**
- Extremely concise and readable
- Case-based logic easy to understand and modify
- Fast, even on large files

**Key features (from code example):[^2]**
- Headers (ATX-style: `#`, `##`, etc.)
- Blockquotes
- Code chunks (triple backticks toggle)
- Unordered lists (lines starting with `*`)
- Inline code (backticks)
- Links (inline)
- Images (inline with alt text)
- Paragraph wrapping
- Fluff trim to remove consecutive `</p><p>` tags

---

## Step-by-Step: Building a Minimal Pure-Bash Converter

### Complete Minimal Example

```bash
#!/bin/bash

# Simple Markdown to HTML converter (pure bash, no external tools except sed)
# Supports: headers, emphasis, lists, code, blockquotes, links, images, paragraphs

input_file="${1:--}"
output=""
in_list=0
in_code=0

while IFS= read -r line; do
    
    # Empty line: end list/blockquote if open
    if [[ -z "$line" ]]; then
        if [[ $in_list -eq 1 ]]; then
            output+="</ul>\n"
            in_list=0
        fi
        output+="\n"
        continue
    fi
    
    # Code block (triple backticks)
    if [[ "$line" =~ ^\`\`\` ]]; then
        if [[ $in_code -eq 0 ]]; then
            output+="<pre><code>\n"
            in_code=1
        else
            output+="</code></pre>\n"
            in_code=0
        fi
        continue
    fi
    
    # Inside code block: preserve literally
    if [[ $in_code -eq 1 ]]; then
        output+="$line\n"
        continue
    fi
    
    # Headers (ATX-style)
    if [[ "$line" =~ ^(#+)[[:space:]]+(.*) ]]; then
        depth=${#BASH_REMATCH[1]}
        text="${BASH_REMATCH[2]}"
        output+="<h$depth>$text</h$depth>\n"
        continue
    fi
    
    # Lists (unordered, * or -)
    if [[ "$line" =~ ^[\*\-][[:space:]]+(.*) ]]; then
        if [[ $in_list -eq 0 ]]; then
            output+="<ul>\n"
            in_list=1
        fi
        item="${BASH_REMATCH[1]}"
        output+="<li>$item</li>\n"
        continue
    fi
    
    # Blockquotes
    if [[ "$line" =~ ^\>[[:space:]]+(.*) ]]; then
        text="${BASH_REMATCH[1]}"
        output+="<blockquote>$text</blockquote>\n"
        continue
    fi
    
    # Regular paragraph: apply inline transformations
    if [[ $in_list -eq 1 ]]; then
        output+="</ul>\n"
        in_list=0
    fi
    
    # Inline transformations
    line=$(echo "$line" | sed -E 's/\*\*([^*]+)\*\*/<strong>\1<\/strong>/g')
    line=$(echo "$line" | sed -E 's/\*([^*]+)\*/<em>\1<\/em>/g')
    line=$(echo "$line" | sed -E 's/\[([^\]]+)\]\(([^)]+)\)/<a href="\2">\1<\/a>/g')
    line=$(echo "$line" | sed -E 's/!\[([^\]]*)\]\(([^)]+)\)/<img alt="\1" src="\2" \/>/g')
    line=$(echo "$line" | sed -E 's/`([^`]+)`/<code>\1<\/code>/g')
    
    output+="<p>$line</p>\n"
    
done < "$input_file"

# Close any open tags
if [[ $in_list -eq 1 ]]; then
    output+="</ul>"
fi
if [[ $in_code -eq 1 ]]; then
    output+="</code></pre>"
fi

# Output result
echo -e "$output"
```

### How to Use

```bash
# Save as md2html.sh
chmod +x md2html.sh

# Convert a file
./md2html.sh input.md > output.html

# Or pipe input
echo "# Hello\n\nThis is **bold**." | ./md2html.sh

# Or use as stdin
cat my_file.md | ./md2html.sh > my_file.html
```

---

## Advanced Techniques for Production Quality

### 1. **HTML Entity Escaping**

```bash
escape_html() {
    local string="$1"
    string="${string//&/&amp;}"
    string="${string//</&lt;}"
    string="${string//>/&gt;}"
    string="${string//\"/&quot;}"
    string="${string//\'/&#39;}"
    echo "$string"
}

# Use before output:
line=$(escape_html "$line")
```

### 2. **Reference-Style Links** (from markdown.bash approach)

```bash
# Extract reference definitions
declare -A links
while IFS= read -r ref_line; do
    if [[ "$ref_line" =~ ^\[([^\]]+)\]:[[:space:]]*(.+) ]]; then
        ref_id="${BASH_REMATCH[1]}"
        ref_url="${BASH_REMATCH[2]}"
        links["$ref_id"]="$ref_url"
    fi
done < <(grep '^\[.*\]:' "$input_file")

# Replace reference links in text
for ref_id in "${!links[@]}"; do
    url="${links[$ref_id]}"
    line=$(echo "$line" | sed -E "s/\[([^\]]+)\]\[$ref_id\]/<a href=\"$url\">\1<\/a>/g")
done
```

### 3. **Preserving Line Breaks Within Paragraphs**

```bash
# Two spaces at end of line = <br/>
line=$(echo "$line" | sed 's/  $/  <br\/>/g')
```

### 4. **Nested Lists (Simple)**

```bash
# Track indentation level
get_indent() {
    local line="$1"
    local indent=0
    while [[ "${line:0:1}" == " " ]]; do
        ((indent++))
        line="${line:1}"
    done
    echo $indent
}
```

---

## Known Pitfalls and Solutions

| Pitfall | Problem | Solution |
|---------|---------|----------|
| Greedy regex matching | `*text*other*text*` matches all as one | Use non-greedy patterns: `([^*]+)` instead of `(.*?)` |
| Special char escaping | Backslash escapes not handled | Pre-process: `\\*` → `\001*ESCAPED_ASTERISK\001*` → restore |
| Multi-line emphasis | `**text\nmore**` broken | Accumulate lines in buffer before processing |
| Nested structures | Lists inside blockquotes | Use state machine or multi-pass approach |
| Sed line limit | Hold space can overflow on huge files | Process in chunks or use sed streaming |
| BSD vs GNU sed | Syntax differs (`-E` vs `-r`, different regex) | Detect OS, alias sed if needed; markdown.bash documents this[^1] |
| Windows line endings | `\r\n` breaks pattern matching | Normalize: `dos2unix` or `sed 's/\r$//'` |

---

## Recommended Implementation Strategy

### For a Minimal Tool (< 150 lines)
Use **line-by-line state machine** (shockrah's approach):[^2]
- Easy to read and maintain
- Covers 80% of common markdown
- Excellent performance
- Simple to extend

### For a Comprehensive Tool (< 400 lines)
Use **sed-based approach** (markdown.bash):[^1]
- Covers ~95% of markdown spec
- Handles edge cases well
- Requires GNU sed
- More complex but proven

### For a Learning Project
Start with **minimal example above**, then:
1. Add reference-style links (inspired by markdown.bash)
2. Add setext-style headers
3. Add ordered lists
4. Add special character escaping
5. Optimize with sed if performance needed

---

## Open Questions

1. **CommonMark vs GitHub Flavored Markdown**: Which spec to target? (CommonMark = stricter; GFM = more permissive, adds features like tables and strikethrough)
2. **HTML5 vs XHTML**: Output format preference? (Most tools default to HTML5)
3. **Nested structures**: How deeply to support? (Full nesting adds significant complexity)
4. **Performance requirements**: Max file size? (Affects whether sed or pure bash is appropriate)

---

## Verification Checklist

Before deploying a bash markdown-to-html converter:

- [ ] All common markdown elements convert correctly
- [ ] Special characters are HTML-escaped
- [ ] Nested structures (lists in blockquotes, etc.) handled
- [ ] Empty lines preserve paragraph breaks
- [ ] Code blocks preserve whitespace and special chars
- [ ] Links and images have correct href/src attributes
- [ ] Edge cases: multiple emphasis markers, consecutive lists, etc.
- [ ] Performance acceptable for target file sizes
- [ ] Script works with both piped and file input
- [ ] Help text and usage examples included

---

## Next Steps for Implementation

1. **Choose an approach** based on coverage needs (minimal vs. comprehensive)
2. **Copy a reference implementation** (markdown.bash or shockrah's script) as a starting point
3. **Test on sample markdown** files to identify gaps
4. **Extend for your specific use case** (tables, strikethrough, etc.)
5. **Document assumptions** about markdown subset supported
6. **Add error handling** for edge cases
7. **Optimize performance** if processing large files
8. **Package as a single shell script** for easy distribution

---

## Sources

[^1]: **markdown.bash GitHub & Documentation**  
    - Repository: https://github.com/chadbraunduin/markdown.bash/  
    - Design blog: https://fullstackdeveloper.novkovic.net/blog/markdown-bash/  
    - Contains 368-line implementation with ~95% Markdown coverage using GNU sed and bash. Includes reference-style links, setext headers, blockquote nesting, and detailed coverage notes. Documents GNU sed requirement and BSD sed compatibility workaround.

[^2]: **shockrah's Markdown Translator**  
    - Blog post: https://shockrah.xyz/posts/markdown-translator/  
    - Repository: https://gitlab.com/shockrah/site-generator  
    - Contains 62-line working implementation using bash case statements with sed and grep for inline transformations. Demonstrates minimal but effective approach for core markdown features. Code example included in blog post.
