# tartrazine

Tartrazine is a library to syntax-highlight code. It is 
a port of [Pygments](https://pygments.org/) to
[Crystal](https://crystal-lang.org/). Kind of.

It's not currently usable unless what you need is a way
to turn your files into a pile of json describing its
constituent tokens, because I have not implemented any
formatters, yet, only the part that parses the code (the lexers).

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

## Installation

If you need to ask how to install this, it's not ready for you yet.

## Usage

If you need to ask how to use this, it's not ready for you yet.

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/ralsina/tartrazine/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Roberto Alsina](https://github.com/ralsina) - creator and maintainer
