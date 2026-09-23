# Changelog

All notable changes to this project will be documented in this file.

## [0.26.1] - 2026-09-23

### 🚀 Features

- Implement chroma's `sublexer_name_group` and `mutators` actions,
  recovering six bundled lexers (arturo, cassandra_cql,
  materialize_sql_dialect, org_mode, postgresql_sql_dialect,
  fortranfixed)

### 🐛 Bug Fixes

- Concurrent tokenization of a shared lexer is now safe
  (thread-local match data, JIT stack and match context, as in
  Crystal's stdlib); a too-small JIT stack could also silently
  fail long docstring matches
- `\uXXXX` escapes in chroma patterns are translated to PCRE2's
  `\x{XXXX}`, recovering three lexers (agda, objectpascal,
  webgpu_shading_language)
- Document the seven known-broken lexers; 282 of 288 bundled
  lexers now load

## [0.26.0] - 2026-09-23

### 🚀 Features

- Optional content-based language detection via hansa: builds with
  `-Dhansa` classify unknown or ambiguous files by content instead of
  falling through to plaintext (lazy-loaded, ~85ms once per process,
  +1.6MB binary; default builds unchanged)
- New CLI options `--line-number-start` and `--highlight-lines` for
  the html, svg and highlights formatters

### 🐛 Bug Fixes

- Crash (signal 11) on non-UTF-8 input: the tokenizer now scrubs
  invalid bytes instead of hitting PCRE2 undefined behavior
- Quadratic tokenization on repetitive input: disabling PCRE2's
  start-of-match optimization (useless for anchored rules) takes a
  600KB repetitive file from 24.7s to 1.5s
- `--list-lexers` now lists all 288 lexers (was 260) and every
  listed name is accepted, including file stems like `common_lisp`
- CLI errors (unknown lexer/theme, missing file) print a one-line
  message instead of a stack trace

### ♻️ Refactorings

- Rule matching scratch moved into the Tokenizer so lexer templates
  are immutable and safely shareable; dead code removed
  (lexer_loader.cr, duplicate XML parser); theme style resolution
  centralized without mutating the shared theme; Tartrazine.theme
  simplified; docs refreshed

## [0.25.1] - 2026-09-23

### 🐛 Bug Fixes

- Fix `TT_LEXERS=crystal,bash -Dnolexers` builds: the crystal lexer is
  native code with no XML to bake, plaintext.xml and heuristics.yml are
  always baked so nolexer builds keep a working fallback and
  autodetection, and unknown names in TT_LEXERS fail with a clear
  message

## [0.25.0] - 2026-09-22

### ⚡ Performance

- Use PCRE2 JIT for lexer rule matching (with interpreter fallback):
  C header tokenization -34%, python -21%, html -19%, jinja+python
  -14%, markdown -10%; end-to-end HTML formatting about 15% faster

## [0.24.0] - 2026-09-21

### ⚡ Performance

- Second round of lexer/tokenizer optimizations: include rules resolve
  their state once, Combined states are memoized per tokenization,
  split_tokens slices bytes directly, lexer instances are cached
  process-wide, snapshot_ovector reuses a scratch buffer, and
  delegating tokenizers iterate instead of recursing (html 1.14x,
  terminal 1.74x, json 1.21x on a 690 KB C header)
- Streaming formatters and hot-path allocation removal: formatters
  stream tokens instead of materializing the whole list, per-type
  style caches in ansi/svg/image/highlights, incremental token
  collapsing, and byte-level HTML escaping shared across formatters.
  Peak memory roughly halved on large inputs
- Cache heuristics.yml parsing and lexer extensions parsing
- Add a multi-lexer tokenize benchmark (scripts/multibench.cr)

### 🐛 Bug Fixes

- Include the lexer files missing from the previous commit, which
  broke the build at that revision

## [0.23.0] - 2026-09-21

### 🚀 Features

- Add perf regression tests for formatter scaling

### 🐛 Bug Fixes

- Resolve all ameba lint issues
- Always emit ANSI codes in the ANSI formatter
- Address issues #24, #25, #26, #27, #28
- Followups on issues #26, #27, #28

### ⚙️ Miscellaneous Tasks

- Remove unused WASM port leftovers
- Exclude aur-tartrazine and lib from ameba linting
- Run perf regression tests on every push
- Require Crystal 1.20 and use Time.instant

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
