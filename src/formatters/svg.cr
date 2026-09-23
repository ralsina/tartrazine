require "../constants/token_abbrevs.cr"
require "../formatter"
require "html"

module Tartrazine
  def self.to_svg(text : String, language : String,
                  theme : String = "default-dark",
                  standalone : Bool = true,
                  line_numbers : Bool = false) : String
    Tartrazine::Svg.new(
      theme: Tartrazine.theme(theme),
      standalone: standalone,
      line_numbers: line_numbers
    ).format(text, Tartrazine.lexer(name: language))
  end

  class Svg < Formatter
    include LineOptions
    property line_number_id_prefix : String = "line-"
    property tab_width = 8
    property? line_numbers : Bool = false
    property? linkable_line_numbers : Bool = true
    property? standalone : Bool = false
    property weight_of_bold : Int32 = 600
    property fs : Int32
    property ystep : Int32

    property theme : Theme

    # Cache of token type → tspan style attributes, built once
    # per type instead of a String.build per token
    @attr_cache = {} of String => String

    def initialize(@theme : Theme = Tartrazine.theme("default-dark"), *,
                   @class_prefix : String = "",
                   @line_number_id_prefix = "line-",
                   @tab_width = 8,
                   @line_numbers : Bool = false,
                   line_number_start : Int32 = 1,
                   highlight_lines : Array(Range(Int32, Int32)) = [] of Range(Int32, Int32),
                   @linkable_line_numbers : Bool = true,
                   @standalone : Bool = false,
                   @weight_of_bold : Int32 = 600,
                   @font_family : String = "monospace",
                   @font_size : String = "14px")
      if font_size.ends_with? "px"
        @fs = font_size[0...-2].to_i
      else
        @fs = font_size.to_i
      end
      @ystep = @fs + 5
      @line_number_start = line_number_start
      @highlight_lines = highlight_lines
    end

    def format(text : String, lexer : BaseLexer, io : IO) : Nil
      unless standalone?
        format_text(text, lexer, io)
        return
      end
      # Render the content first so the document dimensions
      # can be derived from it
      content = String.build { |outp| format_text(text, lexer, outp) }
      # chomp: a single trailing newline terminates the last line
      # rather than starting a nonexistent extra one
      lines = text.chomp.split("\n")
      # Rough monospace advance width, good enough for the viewport
      char_width = (fs * 0.6).ceil.to_i
      padding = fs
      width = padding * 2 + (line_numbers? ? 5 * ystep : 0) +
              {lines.max_of(&.size), 1}.max * char_width
      height = padding + lines.size * ystep + padding // 2
      background = theme.styles["Background"]?.try &.background.try &.hex
      io << %(<?xml version="1.0" encoding="utf-8"?>\n)
      io << %(<svg xmlns="http://www.w3.org/2000/svg" width="#{width}" height="#{height}" viewBox="0 0 #{width} #{height}">\n)
      io << %(<rect width="100%" height="100%" fill="##{background}"/>\n) if background
      io << %(<g font-family="#{@font_family}" font-size="#{@font_size}">)
      io << content
      io << "</g></svg>"
    end

    private def line_label(i : Int32, x : Int32, y : Int32) : String
      line_number = @line_number_start + i
      line_label = "#{line_number}".rjust(4).ljust(5)
      line_style = highlighted?(i + 1) ? "font-weight=\"#{@weight_of_bold}\"" : ""
      line_id = linkable_line_numbers? ? "id=\"#{line_number_id_prefix}#{line_number}\"" : ""
      %(<text #{line_style} #{line_id}  x="#{4*ystep}" y="#{y}" text-anchor="end">#{line_label}</text>)
    end

    def format_text(text : String, lexer : BaseLexer, outp : IO)
      x = 0
      y = ystep
      i = 0
      line_x = x
      line_x += 5 * ystep if line_numbers?
      tokenizer = lexer.tokenizer(text)
      line_open = true
      outp << line_label(i, x, y) if line_numbers?
      outp << %(<text x="#{line_x}" y="#{y}" xml:space="preserve">)
      # Stream tokens; a trailing newline terminates the last line
      # rather than opening a phantom extra one
      TokenStream.new(tokenizer).each do |token, more_content|
        if token[:value].ends_with? "\n"
          # The leading space here is intentional: it matches the
          # original interpolation "<tspan #{style}>"
          outp << "<tspan "
          outp << get_style(token[:type])
          outp << ">"
          escape_to_io(token[:value].to_slice[0, token[:value].bytesize - 1], outp)
          outp << "</tspan>"
          outp << "</text>"
          line_open = false
          next unless more_content
          x = 0
          y += ystep
          i += 1
          outp << line_label(i, x, y) if line_numbers?
          outp << %(<text x="#{line_x}" y="#{y}" xml:space="preserve">)
          line_open = true
        else
          next if token[:value].empty?
          outp << "<tspan"
          outp << get_style(token[:type])
          outp << ">"
          escape_to_io(token[:value], outp)
          outp << "</tspan>"
          x += token[:value].size * ystep
        end
      end
      outp << "</text>" if line_open
    end

    # Given a token type, return the style.
    def get_style(token : String) : String
      cached = @attr_cache[token]?
      return cached if cached

      output = String.build do |outp|
        style = style_for(token)
        outp << " fill=\"##{style.color.try &.hex}\"" if style.color
        # No support for background color or border in SVG

        outp << " font-weight=\"#{@weight_of_bold}\"" if style.bold
        outp << " font-weight=\"normal\"" if style.bold == false
        outp << " font-style=\"italic\"" if style.italic
        outp << " font-style=\"normal\"" if style.italic == false
        outp << " text-decoration=\"underline\"" if style.underline
        outp << " text-decoration=\"none\"" if style.underline == false
      end
      @attr_cache[token] = output
    end
  end
end
