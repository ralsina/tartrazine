# TARTRAZINE

[![Tests](https://github.com/ralsina/tartrazine/actions/workflows/ci.yml/badge.svg)](https://github.com/ralsina/tartrazine/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/ralsina/tartrazine/branch/main/graph/badge.svg?token=52XBPNL99F)](https://codecov.io/gh/ralsina/tartrazine)

Tartrazine is a library to syntax-highlight code. It is
a port of [Pygments](https://pygments.org/) to
[Crystal](https://crystal-lang.org/).

It also provides a CLI tool which can be used to highlight many things in many styles.

Currently Tartrazine supports 247 languages and has 331 themes (63 from Chroma,
the rest are base16 themes via [Sixteen](https://github.com/ralsina/sixteen)

## Installation

If you are using Arch: Use yay or your favourite AUR helper, package name is `tartrazine`.

From prebuilt binaries:

Each release provides statically-linked binaries that should
work on any Linux. Get them from the [releases page](https://github.com/ralsina/tartrazine/releases)
and put them in your PATH.

To build from source:

1. Clone this repo
2. Run `make` to build the `tartrazine` binary
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

## Choosing what Lexers you want

By default Tartrazine will support all its lexers by embedding
them in the binary. This makes the binary large. If you are
using it as a library, you may want to just include a selection of lexers. To do that:

* Pass the `-Dnolexers` flag to the compiler
* Set the `TT_LEXERS` environment variable to a
  comma-separated list of lexers you want to include.


This builds a binary with only the python, markdown, bash and yaml lexers (enough to highlight this `README.md`):

```bash
> TT_LEXERS=python,markdown,bash,yaml shards build -Dnolexers -d --error-trace
Dependencies are satisfied
Building: tartrazine
```

## Choosing what themes you want

Themes come from two places, tartrazine itself and [Sixteen](https://github.com/ralsina/sixteen).

To only embed selected themes, build your project with the `-Dnothemes` option, and
you can set two environment variables to control which themes are included:

* `TT_THEMES` is a comma-separated list of themes to include from tartrazine (see the styles directory in the source)
* `SIXTEEN_THEMES` is a comma-separated list of themes to include from Sixteen (see the base16 directory in the sixteen source)

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

If you are using the HTML formatter, you can pass a template to use for the output. The template is a string where the following placeholders will be replaced:

* `{{style_defs}}` will be replaced by the CSS styles needed for the theme
* `{{code}}` will be replaced by the highlighted code

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

Currently the pass rate for tests in the supported languages
is `96.8%`, which is *not bad for a couple days hacking*.

This only covers the RegexLexers, which are the most common ones,
but it means the supported languages are a subset of Chroma's, which
is a subset of Pygments' and DelegatingLexers (useful for things like template languages)

Then performance was bad, so I hacked and hacked and made it significantly
[faster than chroma](https://ralsina.me/weblog/posts/a-tale-of-optimization.html)
which is fun.
