require "./actions"
require "./formatter"
require "./rules"
require "./styles"
require "./tartrazine"
require "colorize"

module Tartrazine
  # This is the base class for all formatters.
  abstract class Formatter
    property name : String = ""
    property theme : Theme = Tartrazine.theme("default-dark")

    # Format the text using the given lexer.
    def format(text : String, lexer : Lexer, io : IO = nil) : Nil
      raise Exception.new("Not implemented")
    end

    def format(text : String, lexer : Lexer) : String
      outp = String::Builder.new("")
      format(text, lexer, outp)
      outp.to_s
    end

    # Return the styles, if the formatter supports it.
    def style_defs : String
      raise Exception.new("Not implemented")
    end

    # Is this line in the highlighted ranges?
    def highlighted?(line : Int) : Bool
      highlight_lines.any?(&.includes?(line))
    end

    # Included in formatters that render line numbers: the CLI sets
    # these options generically through respond_to?-free typing
    module LineOptions
      property line_number_start : Int32 = 1
      property highlight_lines : Array(Range(Int32, Int32)) = [] of Range(Int32, Int32)
    end

    # Lookup tables for every known token type, built on first use and
    # never modified afterwards: one formatter can then format from
    # several threads at once, and the per-token lookups take no lock.
    # A table is replaced (not updated) when the theme or class prefix
    # it was built for changes. Two threads may both build one; either
    # result is correct.
    @resolved_styles = Atomic(ResolvedStyles?).new(nil)
    @class_names = Atomic(ClassNames?).new(nil)

    # :nodoc:
    class ResolvedStyles
      # The theme's own styles Hash: Theme is a struct, so this
      # reference is what tells whether the formatter's theme changed
      getter source : Hash(String, Style)
      getter styles = {} of String => Style

      def initialize(theme : Theme)
        @source = theme.styles
        Abbreviations.each_key do |token|
          if style = Formatter.resolve_style?(theme, token)
            @styles[token] = style
          end
        end
      end
    end

    # :nodoc:
    class ClassNames
      getter prefix : String
      getter names : Hash(String, String)

      def initialize(@prefix : String)
        @names = Abbreviations.to_h { |token, abbrev| {token, prefix + abbrev} }
      end
    end

    # Themes don't define every specific token type: resolve the
    # nearest parent style that is defined (worst case Background)
    # without mutating the shared theme
    def self.resolve_style?(theme : Theme, token : String) : Style?
      theme.styles[token]? || theme.style_parents(token).reverse.find do |name|
        theme.styles.has_key?(name)
      end.try { |parent| theme.styles[parent] }
    end

    def style_for(token : String) : Style
      table = @resolved_styles.get
      unless table && table.source.same?(theme.styles)
        table = ResolvedStyles.new(theme)
        @resolved_styles.set(table)
      end
      table.styles[token]? || Formatter.resolve_style?(theme, token) ||
        raise KeyError.new("No style for #{token} in theme #{theme.name}")
    end

    # The CSS class (or highlight) name for a token type
    protected def class_name_for(prefix : String, token : String) : String
      table = @class_names.get
      unless table && table.prefix == prefix
        table = ClassNames.new(prefix)
        @class_names.set(table)
      end
      table.names[token]? || (prefix + Abbreviations[token])
    end

    # Write bytes escaping HTML special characters without building
    # intermediate strings
    protected def escape_to_io(bytes : Bytes, io : IO) : Nil
      start = 0
      bytes.each_with_index do |byte, index|
        entity = case byte
                 when '&'.ord  then "&amp;"
                 when '<'.ord  then "&lt;"
                 when '>'.ord  then "&gt;"
                 when '"'.ord  then "&quot;"
                 when '\''.ord then "&#39;"
                 end
        next if entity.nil?
        io.write(bytes[start, index - start]) if index > start
        io << entity
        start = index + 1
      end
      io.write(bytes[start, bytes.size - start]) if start < bytes.size
    end

    protected def escape_to_io(text : String, io : IO) : Nil
      escape_to_io(text.to_slice, io)
    end
  end

  # Streams tokens from a tokenizer, paired with whether any
  # non-empty token follows. This lets formatters handle trailing
  # newlines correctly without materializing the whole token list.
  class TokenStream
    @iterator : Iterator(Token)

    def initialize(tokenizer : Iterator(Token))
      @iterator = tokenizer
      @buffer = Deque(Token).new
      @stopped = false
    end

    def each(&) : Nil
      while token = next_token
        token, more_content = token
        yield token, more_content
      end
    end

    private def next_token : Tuple(Token, Bool)?
      return unless fill_until(0)
      token = @buffer.shift
      {token, more_content?}
    end

    # Make sure at least offset + 1 tokens are buffered.
    # False when the input is exhausted.
    private def fill_until(offset : Int32) : Bool
      while @buffer.size <= offset
        return false if @stopped
        item = @iterator.next
        if item.is_a?(Iterator::Stop)
          @stopped = true
          return false
        end
        @buffer << item
      end
      true
    end

    # Whether a non-empty token remains after the current one,
    # looking past runs of empty tokens without consuming them
    private def more_content? : Bool
      offset = 0
      while fill_until(offset)
        return true unless @buffer[offset][:value].empty?
        offset += 1
      end
      false
    end
  end
end
