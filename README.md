# 🚀 Pure-Bash Markdown-to-HTML Converter (`md2html`)

[![Shell](https://img.shields.io/badge/Language-Bash-4EAA25?logo=gnu-bash&logoColor=white)](#)
[![OS](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-000000?logo=apple&logoColor=white)](#)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](#)

A high-performance, robust, pure-Bash utility designed to compile complex **Markdown Documents** into beautiful, modern, semantic **HTML Renders** with **zero external dependencies**. 

The repository utilizes a modular Bash setup for core development, which is compiled into a single, unified, ultra-portable standalone script using the bundled build engine.

---

## ✨ Features

- **🚀 Zero Dependencies**: Written entirely in native Bash. No Python, Node.js, or Ruby runtime required.
- **📦 Single-File Bundle**: Combines modular libraries and JSON styling rules into a single executable `md2html` that you can run anywhere.
- **🎨 Premium Visual Themes**: Built-in visual themes (`modern`, `dark`, `neon`, `minimal`, `everforest`) that load elegant Google Fonts, custom CSS typography, gradients, card styling, and custom responsive layouts out of the box.
- **🧩 Block Parser State-Machine**: Correctly processes complex block structures:
  - Deeply **nested lists** (unordered `ul` and ordered `ol` mixed together)
  - Nested blockquotes (e.g. `> > quote`)
  - Setext headers (`===` and `---`) and ATX headers (`#` to `######` with automated slug/anchor IDs)
  - GFM **tables** with syntax alignments (`:---`, `:---:`, `---:`)
  - Horizontal rules (`---`, `***`, `___`)
- **🔗 Link Reference Registry**: A robust two-pass parser that registers custom reference-style links/images (`[my-link]: https://google.com "Google"`) and resolves them across the entire document.
- **⚡ Inline Transform Engine**: Handles bold, italic, strike-through, inline code, direct hyperlinks, and images.
- **🧜 Mermaid.js Support**: Auto-detects ` ```mermaid ` code blocks and wraps them in standard class structures so diagrams render beautifully with Mermaid-enabled renderers.

---

## 🎨 Visual Themes Showcase

When compiling in **Standalone Mode** (`-s` or `--standalone`), the converter wraps your document in a fully styled responsive container using one of five curated visual configurations:

| Theme | Typography (Primary / Headings) | Color Palette / Vibe |
| :--- | :--- | :--- |
| **`modern`** *(Default)* | Plus Jakarta Sans / Outfit | Sleek, clean light-mode with indigo accents and soft slate gradients. |
| **`dark`** | Inter / Inter | Sleek, professional dark-mode with sky-blue accents and deep gray card structures. |
| **`neon`** | Rajdhani / Orbitron | Futuristic cyberpunk theme using JetBrains Mono, vibrant cyan, and hot-pink glow borders. |
| **`minimal`** | Lora / Playfair Display | Elegant, literary serif layout with traditional high contrast and minimalist lines. |
| **`everforest`** | Plus Jakarta Sans / Outfit | Peaceful, soothing dark forest theme with soft green, warm gray, and wood accents. |

---

## 📥 Installation

An automated installer `install.sh` is provided in the repository to compile the modular libraries and place the executable directly in your command line path as the `md2html` command.

### Quick Install

Simply run the installer directly:

```bash
./install.sh
```

### Advanced Installation Settings

By default, the installer automatically detects the most appropriate directory:
1. Installs globally to `/usr/local/bin` if writable or if run via `sudo`.
2. Falls back to a user-local bin (`$HOME/.local/bin` or `$HOME/bin`) if root access is not available.

You can also pass a custom prefix or target path:

```bash
# Install to a specific prefix
PREFIX=$HOME/my-tools ./install.sh

# Or pass the exact destination directory as an argument
./install.sh /usr/bin
```

### PATH Configuration

If the installation folder is not already in your path, add the following line to your shell configuration (e.g., `~/.zshrc`, `~/.bash_profile`, or `~/.config/fish/config.fish`):

**For Zsh / Bash:**
```bash
export PATH="$HOME/.local/bin:$PATH"
```

**For Fish Shell:**
```fish
fish_add_path $HOME/.local/bin
```

---

## 🚀 Usage Guide

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

#### 1. Basic Conversion
Convert a Markdown Document into a clean HTML block snippet (suitable for embedding in other pages):
```bash
md2html document.md > render.html
```

#### 2. Standalone Page with Custom Styling
Compile a complete, self-contained HTML page using the elegant **Dark** theme and a custom title:
```bash
md2html --standalone --theme dark --title "My API Docs" document.md -o index.html
```

#### 3. Pipe & Stream Processing
Seamlessly stream content from standard input:
```bash
cat release_notes.md | md2html --standalone --theme neon > release.html
```

---

## 🛠️ Codebase & Architecture

The project emphasizes highly modular shell development, enabling easier testing and contribution compared to monolithic shell scripts.

```text
.
├── bin/                 # Placeholder for transient binaries
├── data/
│   └── themes.json      # CSS visual theme configurations and style variables
├── dist/
│   └── md2html          # Compiled standalone tool (built from scripts/build.sh)
├── docs/
│   └── CONTEXT.md       # Ubiquitous language & terminology guide
├── scripts/
│   └── build.sh         # Compiler that inlines libraries and JSON into dist/md2html
├── src/                 # Core modular source files
│   ├── inline_transform.sh  # Inline syntax translation engine
│   ├── md2html.sh       # Main command logic and state machine parser
│   ├── ref_registry.sh  # Named link reference storage manager
│   ├── theme_registry.sh# Themes database parser and JSON extractor
│   └── themes.sh        # Header/Footer builder & CSS style injector
├── tests/               # Regression and unit test suites
│   ├── run_tests.sh     # Regression runner (compares outputs against baselines)
│   └── run_unit_tests.sh# Core parser state and regression validator
├── install.sh           # Main compiler and user/global installer script
└── README.md            # You are here!
```

### Compiling Manually

If you make modifications to the modular files in `src/` or edit the visual variables in `data/themes.json`, you can run the compiler manually to regenerate `dist/md2html`:

```bash
./scripts/build.sh
```

---

## 🧪 Testing

The codebase includes an extensive suite of automated tests to ensure structural accuracy.

To run the regression parser comparison tests:
```bash
./tests/run_tests.sh
```

To run the primary unit test and line-parser suites:
```bash
./tests/run_unit_tests.sh
```

---

## 📄 License

This project is licensed under the MIT License. Developed and optimized with premium care by **Antigravity**.
