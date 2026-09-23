# TARTRAZINE

[![Tests](https://github.com/ralsina/tartrazine/actions/workflows/ci.yml/badge.svg)](https://github.com/ralsina/tartrazine/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/ralsina/tartrazine/branch/main/graph/badge.svg?token=52XBPNL99F)](https://codecov.io/gh/ralsina/tartrazine)

Tartrazine is a library to syntax-highlight code. It is
a port of [Pygments](https://pygments.org/) to
[Crystal](https://crystal-lang.org/).

It also provides a CLI tool which can be used to highlight many things in many styles.

Currently Tartrazine supports 282 languages and has hundreds of themes
(69 from Chroma,
the rest are base16 themes via [Sixteen](https://github.com/ralsina/sixteen)

## Installation

If you are using Arch: Use yay or your favourite AUR helper, package name is `tartrazine`.

From prebuilt binaries:

Each release provides statically-linked binaries that should
work on any Linux. Get them from the [releases page](https://github.com/ralsina/tartrazine/releases)
and put them in your PATH.

To build from source:

1. Clone this repo
2. Run `shards build` to build the `tartrazine` binary
3. Copy the binary somewhere in your PATH.

## Usage as a CLI tool

Show a syntax highlighted version of a C source file in your terminal:

```shell
tartrazine whatever.c -l c -t catppuccin-macchiato --line-numbers -f terminal
```

Generate a standalone HTML file from a C source file with the syntax highlighted:

```shell
$ tartrazine whatever.c -t catppuccin-macchiato --line-numbers \
  --standalone -f html -o whatever.html
```

## Usage as a Library

Add to your `shard.yml`:

```yaml
dependencies:
  tartrazine:
    github: ralsina/tartrazine
```

This is the high level API:

```crystal
require "tartrazine"

html = Tartrazine.to_html(
  "puts \"Hello, world!\"",
  language: "crystal",
  theme: "catppuccin-macchiato",
  standalone: true,
  line_numbers: true
)
```

This does more or less the same thing, but more manually:

```crystal
lexer = Tartrazine.lexer("crystal")
formatter = Tartrazine::Html.new(
  theme: Tartrazine.theme("catppuccin-macchiato"),
  line_numbers: true,
  standalone: true,
)
puts formatter.format("puts \"Hello, world!\"", lexer)
```

The reason you may want to use the manual version is to reuse
the lexer and formatter objects for performance reasons.

## A note about performance of static binaries

Statically-linked binaries built with Crystal 1.21 for Linux (musl) suffer
a fixed wall-clock penalty of roughly 40ms per run: the parallel garbage
collector spawns one thread per core, and every GC cycle pays a futex
wake/park cost that is much higher under musl than glibc. The extra time
is spent off-CPU, so it does not show up as increased CPU usage.

Since tartrazine is usually a short-lived CLI process, the penalty is
noticeable. You can avoid it by starting the collector with a large enough
initial heap (about 16MB covers lexer setup, which triggers most GC cycles)
so the heap-growth phase doesn't trigger collections:

```bash
GC_INITIAL_HEAP_SIZE=16M tartrazine file.py -f html
```

That is a runtime setting, no rebuild needed. It makes affected binaries
about 2x faster on startup-dominated workloads.

## Experimental CSS Highlights API Formatter

Tartrazine also includes an experimental `highlights` formatter that uses the
[CSS Custom Highlights API](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Custom_Highlights_API)
instead of traditional DOM manipulation with `<span>` elements.

**Note**: This is experimental and shows little to no performance benefit
in modern browsers even for large files. The traditional HTML formatter
is recommended for production use.

```bash
# Generate syntax highlighting with CSS Highlights API
tartrazine code.cr -f highlights -t github --standalone
```

**Browser Support**: Chrome/Edge 105+, Firefox 114+ (requires flag in Firefox)

**Limitations**: The CSS Highlights API only supports a limited subset of CSS properties:

- ✅ Supported: `color`, `background-color`, `text-decoration`, `text-shadow`
- ❌ Not supported: `font-weight`, `font-style`, `border`, `tab-size`

This means the highlights formatter cannot apply bold, italic, or
border styling that the traditional HTML formatter supports.

## Content-based language detection (optional)

When compiled with `-Dhansa`, tartrazine gains a content-based fallback
using [hansa](https://github.com/ralsina/hansa) (a port of go-enry's
naive-Bayes classifier). It fires only when no filename pattern matches,
or when filename ambiguity survives the Linguist heuristics — paths that
would otherwise use the plaintext lexer or fail:

```bash
shards build -Dhansa
./bin/tartrazine mystery_file.xyz -f html -l autodetect
```

The classifier data is loaded lazily on first fallback, costing ~85ms
once per process, and adds ~1.6MB to the binary. Default builds are
unchanged. Note the classifier works best on whole files; short
snippets are often misclassified.

## Known-broken lexers

Seven bundled lexers fail to load because their Chroma XML contains regexes
PCRE2 rejects (variable-length lookbehind assertions in `fish`, `scss` and
`v_shell`; patterns over PCRE2's compiled-size limit in `racket` and
`openedge_abl`; invalid syntax in `al` and `lilypond`). They are excluded
from `--list-lexers` and the language count; selecting them by name reports
an error. The list is guarded by `spec/load_spec.cr`.

## Choosing what Lexers you want

By default Tartrazine will support all its lexers by embedding
them in the binary. This makes the binary large. If you are
using it as a library, you may want to just include a selection of
lexers. To do that:

- Pass the `-Dnolexers` flag to the compiler
- Set the `TT_LEXERS` environment variable to a
  comma-separated list of lexers you want to include.

This builds a binary with only the python, markdown, bash and yaml
lexers (enough to highlight this `README.md`):

```bash
> TT_LEXERS=python,markdown,bash,yaml shards build -Dnolexers -d --error-trace
Dependencies are satisfied
Building: tartrazine
```

## Choosing what themes you want

Themes come from two places, tartrazine itself and [Sixteen](https://github.com/ralsina/sixteen).

To only embed selected themes, build your project with the
`-Dnothemes` option, and you can set two environment variables to
control which themes are included:

- `TT_THEMES` is a comma-separated list of themes to include from tartrazine (see
  [the styles directory in the source](https://github.com/ralsina/tartrazine/tree/main/styles))
- `SIXTEEN_THEMES` is a comma-separated list of themes to include from Sixteen (see
  [the base16 directory in the sixteen source](https://github.com/ralsina/sixteen/tree/main/base16))

For example (using the tartrazine CLI as the project):

```bash
$ TT_THEMES=colorful,autumn SIXTEEN_THEMES=pasque,pico shards build -Dnothemes
Dependencies are satisfied
Building: tartrazine

$ ./bin/tartrazine  --list-themes
autumn
colorful
pasque
pico
```

Be careful not to build without any themes at all, nothing will work.

## Templates for standalone HTML output

If you are using the HTML formatter, you can pass a template to use
for the output. The template is a string where the following
placeholders will be replaced:

- `{{style_defs}}` will be replaced by the CSS styles needed for the theme
- `{{code}}` will be replaced by the highlighted code

This is an example template that changes the padding around the code:

```jinja2
<!DOCTYPE html>
<html>
  <head>
    <style>
      {{style_defs}}
      pre {
      padding: 1em;
      }
    </style>
  </head>
  <body>
    {{body}}
  </body>
</html>
```

## Contributing

1. Fork it (<https://github.com/ralsina/tartrazine/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Roberto Alsina](https://github.com/ralsina) - creator and maintainer

## A port of what, and why "kind of"

Pygments is a staple of the Python ecosystem, and it's great.
It lets you highlight code in many languages, and it has many
themes. Chroma is "Pygments for Go", it's actually a port of
Pygments to Go, and it's great too.

I wanted that in Crystal, so I started this project. But I did
not read much of the Pygments code. Or much of Chroma's.

Chroma has taken most of the Pygments lexers and turned them into
XML descriptions. What I did was take those XML files from Chroma
and a pile of test cases from Pygments, and I slapped them together
until the tests passed and my code produced the same output as
Chroma. Think of it as [*extreme TDD*](https://ralsina.me/weblog/posts/tartrazine-reimplementing-pygments.html)

The test suite tokenizes the same inputs and compares against
Chroma's output for every supported language; a few known-bad
cases are excluded with reasons in the spec.

This only covers the RegexLexers, which are the most common ones,
but it means the supported languages are a subset of Chroma's, which
is a subset of Pygments' and DelegatingLexers (useful for things like template languages)

Then performance was bad, so I hacked and hacked and made it significantly
[faster than chroma](https://ralsina.me/weblog/posts/a-tale-of-optimization.html)
which is fun.
