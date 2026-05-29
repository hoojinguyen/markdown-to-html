# Markdown-to-HTML Converter

A high-performance, robust, pure-Bash utility designed to compile Markdown documents into beautiful, modern, semantic HTML files with zero external dependencies.

## How to Install

```bash
curl -fsSL https://raw.githubusercontent.com/hoojinguyen/markdown-to-html/main/install.sh | bash
```

## How to Use
```bash
md2html
```

You can also run it with options and input files:

```text
Usage: md2html [options] [input-file]

Options:
  -h, --help           Show this help message and exit
  -v, --version        Show version information
  -f, --fragment       Generate a raw HTML fragment (no <head> or styling)
  -s, --standalone     Generate a full HTML document (with <head> and styling) [default]
  -t, --theme THEME    Theme to use for standalone mode (everforest, modern, dark, neon, minimal) [default: everforest]
  --title TITLE        Set custom title for standalone HTML document [default: Markdown Document]
  -r, --raw-html       Allow raw HTML tags in Markdown input (otherwise escaped)
  -o, --output FILE    Write output to FILE instead of standard output
```

### Examples

Compile a Markdown file instantly into a styled HTML document (using `everforest` by default, saved to `document.html` at the same level):
```bash
md2html document.md
```

Compile a Markdown file into a styled HTML document with custom theme and title:
```bash
md2html --theme neon --title "My API Docs" document.md -o index.html
```

Stream markdown content as an HTML fragment:
```bash
cat release_notes.md | md2html --fragment > release.html
```
