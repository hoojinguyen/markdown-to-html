# Markdown-to-HTML Converter

A high-performance, robust, pure-Bash utility designed to compile Markdown documents into beautiful, modern, semantic HTML files with zero external dependencies.

## How to Install

```bash
curl -fsSL https://raw.githubusercontent.com/hoojinguyen/markdown-to-html/main/install.sh | bash
```

## How to Use

```text
Usage: md2html [options] [input-file]

Options:
  -h, --help           Show this help message and exit
  -v, --version        Show version information
  -s, --standalone     Generate a full HTML document (with <head> and styling)
  -t, --theme THEME    Theme to use for standalone mode (modern, dark, neon, minimal, everforest) [default: modern]
  --title TITLE        Set custom title for standalone HTML document [default: Markdown Document]
  -r, --raw-html       Allow raw HTML tags in Markdown input (otherwise escaped)
  -o, --output FILE    Write output to FILE instead of standard output
```

### Examples

Convert a Markdown file into a clean HTML block snippet:
```bash
md2html document.md > render.html
```

Compile a complete, self-contained HTML page using the "dark" theme:
```bash
md2html --standalone --theme dark --title "My API Docs" document.md -o index.html
```

Stream markdown content dynamically through standard input:
```bash
cat release_notes.md | md2html --standalone --theme neon > release.html
```
