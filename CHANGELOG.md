# Changelog

All notable changes to this project will be documented in this file.

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
