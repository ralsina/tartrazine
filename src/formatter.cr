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

    # Cache of token type → resolved Style. Themes don't define every
    # specific token type: resolve the nearest parent style that is
    # defined (worst case Background) without mutating the shared theme
    @style_cache = {} of String => Style

    def style_for(token : String) : Style
      cached = @style_cache[token]?
      return cached if cached

      resolved = theme.styles[token]?
      if resolved.nil?
        parent = theme.style_parents(token).reverse.find do |name|
          theme.styles.has_key?(name)
        end
        resolved = theme.styles[parent]
      end
      @style_cache[token] = resolved
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
