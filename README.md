# TARTRAZINE

Tartrazine is a library to syntax-highlight code. It is
a port of [Pygments](https://pygments.org/) to
[Crystal](https://crystal-lang.org/). Kind of.

It's not currently usable because it's not finished, but:

* The lexers work for the implemented languages
* The provided styles work
* There is a very very simple HTML formatter

# A port of what? Why "kind of"?

Because I did not read the Pygments code. And this is actually
based on [Chroma](https://github.com/alecthomas/chroma) ...
although I did not read that code either.

Chroma has taken most of the Pygments lexers and turned them into
XML descriptions. What I did was take those XML files from Chroma
and a pile of test cases from Pygments, and I slapped them together
until the tests passed and my code produced the same output as
Chroma. Think of it as *extreme TDD*.

Currently the pass rate for tests in the supported languages
is `96.8%`, which is *not bad for a couple days hacking*.

This only covers the RegexLexers, which are the most common ones,
but it means the supported languages are a subset of Chroma's, which
is a subset of Pygments'.

Currently Tartrazine supports ... 241 languages.

It has 331 themes (63 from Chroma, the rest are base16 themes via
[Sixteen](https://github.com/ralsina/sixteen)

## Installation

From prebuilt binaries:

Each release provides statically-linked binaries that should
work on any Linux. Get them from the [releases page](https://github.com/ralsina/tartrazine/releases) and put them in your PATH.

To build from source:

1. Clone this repo
2. Run `make` to build the `tartrazine` binary
3. Copy the binary somewhere in your PATH.

## Usage

This works:

```crystal
require "tartrazine"

lexer = Tartrazine.lexer("crystal")
theme = Tartrazine.theme("catppuccin-macchiato")
puts Tartrazine::Html.new.format(File.read(ARGV[0]), lexer, theme)
```

## Contributing

1. Fork it (<https://github.com/ralsina/tartrazine/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Roberto Alsina](https://github.com/ralsina) - creator and maintainer