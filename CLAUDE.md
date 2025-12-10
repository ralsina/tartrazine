# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Tartrazine is a Crystal language syntax highlighting library, ported from Pygments. It provides both a CLI tool and library supporting 273+ languages with hundreds of themes. The project uses XML-based lexer definitions ported from Chroma (Go's Pygments port) and focuses on performance optimizations.

## Build Commands

### Core Development
- **Build**: `hace build` (builds with debug flags `-d --error-trace`)
- **Install dependencies**: `hace get-deps` (runs `shards install`)
- **Clean**: `hace clean` (removes shard.lock, bin, lib directories)
- **Install locally**: `hace install` (copies binary to ~/.local/bin/)

### Testing and Quality
- **Run tests**: `hace test` (runs `crystal spec -v --error-trace`)
- **Linting**: `hace lint` (runs `crystal tool format` and `ameba --fix`)
- **Coverage**: `hace coverage` (generates coverage report using kcov)
- **Documentation**: `hace docs` (generates API docs)

### Release and Distribution
- **Release build**: `hace build-release` (builds with `--release` flag)
- **Static binaries**: `hace static` (creates static Linux binaries for AMD64/ARM64)
- **AUR package**: `hace aur` (updates Arch Linux AUR package)

## Project Architecture

### Core Components
- **src/tartrazine.cr**: Main module with VERSION, logging, and XML parsing macros
- **src/main.cr**: CLI entry point using docopt (matches user preference)
- **src/lexer.cr**: Lexer engine with RegexLexer and BaseLexer classes
- **src/actions.cr**: Lexer actions (Token, Push, Pop, Include, Using, etc.)
- **src/rules.cr**: Lexer rule processing and state machine management
- **src/formatter.cr**: Abstract base formatter class
- **src/styles.cr**: Theme and style management

### Formatters Directory
- **formatters/html.cr**: HTML output formatter with standalone mode support
- **formatters/terminal.cr**: ANSI terminal output
- **formatters/json.cr**: JSON token output
- **formatters/svg.cr**: SVG image generation
- **formatters/png.cr**: PNG image generation (requires StumpyPNG)

### Resource Management
- **lexers/*.xml**: Language lexer definitions (compiled into binary via baked_file_system)
- **styles/*.xml**: Theme definitions (also compiled into binary)
- **Selective embedding**: Use `TT_LEXERS` and `TT_THEMES` environment variables with `-Dnolexers`/`-Dnothemes` flags to reduce binary size

## Development Patterns

### Lexer System
- XML-based lexer definitions converted to Crystal at compile time
- State machine with push/pop for complex language parsing
- Byte-level regex processing for performance
- Heuristics for automatic language detection from filenames/mimetypes

### Testing Structure
- **spec/tartrazine_spec.cr**: Main test suite
- **spec/examples/**: Real language code samples for testing
- **spec/tests/**: External test cases from Pygments/Chroma
- **spec/unsupported_lexers/**: Known failing test cases
- Test validation compares output against Pygments/Chroma (96.8% pass rate)

### Code Quality Tools
- **Ameba**: Linter with auto-fix (`ameba --fix`)
- **Crystal formatter**: Enforces consistent code style
- **Pre-commit hooks**: Automatic formatting and linting on commit
- **Git-cliff**: Changelog generation from conventional commits

## Binary Configuration

The project builds a single binary target (`tartrazine`) with the following features:
- Multiple output formats: html, terminal, json, svg, png
- Theme selection and CSS generation
- Line numbering and standalone HTML support
- Custom HTML templates with placeholders (`{{style_defs}}`, `{{code}}`)
- Language auto-detection and manual lexer selection

## Important Development Notes

### User Preferences Met
- **docopt**: CLI uses docopt for argument parsing as requested
- **No not_nil!**: Codebase avoids this pattern as specified
- **shards build**: Uses standard Crystal build system
- **No --release flag**: Development builds avoid this flag per preference

### External Dependencies
- **lib/**: Contains vendored dependencies that cannot be modified
- Built-in alternatives: Some dependencies have custom Crystal implementations
- Specific versions are pinned for compatibility

### Performance Optimizations
- Byte-level processing instead of string operations
- Pre-compiled regex patterns
- Baked resources eliminate runtime file I/O
- Efficient state machine with minimal allocations

### Build Variants
- **Default build**: Includes all lexers and themes (larger binary)
- **Selective build**: Use environment variables to include specific lexers/themes
- **Static binaries**: Cross-platform distribution without runtime dependencies
- we don't commit shard.lock because this is a library
