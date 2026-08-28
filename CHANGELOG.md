# Changelog

All notable changes to this project will be documented in this file.

## [0.21.3] - 2026-08-28

### 🐛 Bug Fixes

- Keep multi-byte UTF-8 characters intact in Error tokens

## [0.21.2] - 2026-08-28

### 🐛 Bug Fixes

- Add missing token type abbreviations

## [0.21.1] - 2026-08-23

### 🐛 Bug Fixes

- *(build)* Make hace aur work under persistent shell
- Unpin crimage, expect new png hash

## [0.21.0] - 2026-08-23

### 🚀 Features

- Sync lexers with chroma v2.27.0

### 🐛 Bug Fixes

- Pin crimage to known-good revision

### ⚡ Performance

- *(build)* Cross-compile static binaries, link in minimal containers
- Eliminate hot-path allocations in lexer and html formatter

## [0.20.1] - 2026-01-17

### ⚙️ Miscellaneous Tasks

- Unpin sixteen version

## [0.20.0] - 2026-01-03

### 🚀 Features

- Add image size options and fix first-line positioning bug

## [0.19.3] - 2026-01-02

### 🚜 Refactor

- Add ImageFormatter base class and Crimage-based formatters

## [0.19.2] - 2025-12-27

### 🐛 Bug Fixes

- Remove duplicate CSS class abbreviations

### 🧪 Testing

- Fix tests

## [0.19.1] - 2025-12-19

### 🐛 Bug Fixes

- Improve lexer creation performance

## [0.19.0] - 2025-12-17

### 🚀 Features

- Add complete Go lexer with Chroma compatibility

### 📚 Documentation

- Update CLAUDE.md and regenerate lexer constants

### ⚙️ Miscellaneous Tasks

- Remove local file

## [0.18.0] - 2025-12-11

### 🚀 Features

- Add light? and dark? methods to Theme and fix theme family detection
- Add base16 property and optimize theme type detection

### ⚙️ Miscellaneous Tasks

- Lint

## [0.17.0] - 2025-12-11

### 🚀 Features

- Dramatically improve base16 theme token coverage and styling

## [0.16.0] - 2025-12-10

### 🚀 Features

- Sync lexers and themes from Chroma main branch
- Update sixteen dependency to v0.6.0
- Add dark/light theme variant support and fix formatter error handling
- Add dark/light theme variant support with proper base16 integration

### ⚙️ Miscellaneous Tasks

- Cleanup
- Cleanup
- Cleanup
- Cleanup

## [0.15.0] - 2025-12-05

### 🚀 Features

- Add configurable font support for PNG formatter

## [0.14.3] - 2025-12-04

### 🐛 Bug Fixes

- Remove non-theme files (LICENSE, README) from --list-themes output

## [0.14.2] - 2025-12-03

### ⚙️ Miscellaneous Tasks

- Release script

### 🚀 Features

- New `Lexer.extensions()` method

### 🐛 Bug Fixes

- Add crystal to the list of lexers given by --list-lexers

### Bump

- Release v0.14.2

## [0.14.0] - 2025-11-05

### 🚀 Features

- Add experimental CSS Highlights API formatter

### 📚 Documentation

- Link to where themes are

### 🧪 Testing

- Fix broken test

### ⚙️ Miscellaneous Tasks

- Ignore
- AUR build

## [0.13.0] - 2025-03-10

### 🚀 Features

- Support custom template for HTML standalone output

### 🐛 Bug Fixes

- Better error message when loading a XML theme
- When the internal crystal highlighter fails, fallback to ruby. Fixes #13
- Don't log when falling back to ruby, it breaks stuff

### ⚙️ Miscellaneous Tasks

- Upgrade ci image
- Typo

## [0.12.0] - 2025-01-21

### 🚀 Features

- Bumped to latest chroma release

### ⚙️ Miscellaneous Tasks

- Pin ubuntu version in CI
- Mark more mcfunction tests as bad

### Build

- Automate AUR release

## [0.11.1] - 2024-10-14

### 🐛 Bug Fixes

- Support choosing lexers when used as a library

## [0.11.0] - 2024-10-14

### 🚀 Features

- Support selecting only some themes

## [0.10.0] - 2024-09-26

### 🚀 Features

- Optional conditional baking of lexers

### 🐛 Bug Fixes

- Strip binaries for release artifacts
- Fix metadata to show crystal

## [0.9.1] - 2024-09-22

### 🐛 Bug Fixes

- Terminal formatter was skipping things that it could highlight
- Bug in high-level API for png formatter

### 🧪 Testing

- Added minimal tests for svg and png formatters

## [0.9.0] - 2024-09-21

### 🚀 Features

- PNG writer based on Stumpy libs

### ⚙️ Miscellaneous Tasks

- Clean
- Detect version bump in release script
- Improve changelog handling

## [0.8.0] - 2024-09-21

### 🚀 Features

- SVG formatter

### 🐛 Bug Fixes

- HTML formatter was setting bold wrong

### 📚 Documentation

- Added instructions to add as a dependency

### 🧪 Testing

- Add basic tests for crystal and delegating lexers
- Added tests for CSS generation

### ⚙ Miscellaneous Tasks

- Fix example code in README

## [0.7.0] - 2024-09-10

### 🚀 Features

- Higher level API (`to_html` and `to_ansi`)
- Use the native crystal highlighter

### 🐛 Bug Fixes

- Ameba
- Variable bame in Hacefile
- Make it easier to import the Ansi formatter
- Renamed BaseLexer to Lexer and Lexer to RegexLexer to make API nicer
- Make install work

### 📚 Documentation

- Mention AUR package

### 🧪 Testing

- Add CI workflows

### ⚙️ Miscellaneous Tasks

- Pre-commit hooks
- Git-cliff config
- Started changelog
- Force conventional commit messages
- Force conventional commit messages
- Updated pre-commit
- *(ignore)* Fix tests
- Added badges
- Added badges
- *(ignore)* Removed random file

### Build

- Switch from Makefile to Hacefile
- Added do_release script
- Fix markdown check

### Bump

- Release v0.6.4
- Release v0.6.4

## [0.6.1] - 2024-08-25

### 📚 Documentation

- Improve readme and help message

<!-- generated by git-cliff -->
