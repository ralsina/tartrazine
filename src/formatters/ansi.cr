require "../formatter"

module Tartrazine
  def self.to_ansi(text : String, language : String,
                   theme : String = "default-dark",
                   line_numbers : Bool = false) : String
    Tartrazine::Ansi.new(
      theme: Tartrazine.theme(theme),
      line_numbers: line_numbers
    ).format(text, Tartrazine.lexer(name: language))
  end

  class Ansi < Formatter
    property? line_numbers : Bool = false

    # Cache of token type → (escape prefix, reset suffix), built
    # once per type instead of a Colorize::Object per token
    @escape_cache = {} of String => Tuple(String, String)

    def initialize(@theme : Theme = Tartrazine.theme("default-dark"), @line_numbers : Bool = false)
    end

    private def line_label(i : Int32) : String
      "#{i + 1}".rjust(4).ljust(5)
    end

    def format(text : String, lexer : BaseLexer, outp : IO) : Nil
      tokenizer = lexer.tokenizer(text)
      i = 0
      outp << line_label(i) if line_numbers?
      # Stream tokens; a newline only emits a line number when more
      # content follows, so a trailing newline doesn't produce a
      # phantom line number for a nonexistent last line
      TokenStream.new(tokenizer).each do |token, more_content|
        prefix, reset = escape_pair(token[:type])
        outp << prefix << token[:value] << reset
        if token[:value].includes?("\n") && more_content
          i += 1
          outp << line_label(i) if line_numbers?
        end
      end
    end

    # Resolve the ANSI escape pair for a token type, caching the
    # result. The pair is derived from a Colorize sample on an empty
    # string, so the emitted bytes match a per-token colorize call.
    private def escape_pair(token : String) : Tuple(String, String)
      cached = @escape_cache[token]?
      return cached if cached

      style = style_for(token)

      colorized = "".colorize
      # Always emit ANSI codes: this is an explicit request for ANSI
      # output, so the caller's stdout being a pipe must not disable it
      colorized.toggle(true)
      style.color.try { |col| colorized = colorized.fore(col.colorize) }
      # Intentionally not setting background color
      colorized.mode(:bold) if style.bold
      colorized.mode(:italic) if style.italic
      colorized.mode(:underline) if style.underline
      sample = colorized.to_s

      # With no color or modes the sample is empty: no escapes at all
      boundary = sample.index('m')
      result = if boundary
                 {sample[0..boundary], sample[(boundary + 1)..]}
               else
                 {"", ""}
               end
      @escape_cache[token] = result
      result
    end
  end
end
