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
    property highlight_lines : Array(Range(Int32, Int32)) = [] of Range(Int32, Int32)
    property line_number_id_prefix : String = "line-"
    property line_number_start : Int32 = 1
    property tab_width = 8
    property? line_numbers : Bool = false
    property? linkable_line_numbers : Bool = true
    property? standalone : Bool = false
    property weight_of_bold : Int32 = 600
    property fs : Int32
    property ystep : Int32

    property theme : Theme

    def initialize(@theme : Theme = Tartrazine.theme("default-dark"), *,
                   @highlight_lines = [] of Range(Int32, Int32),
                   @class_prefix : String = "",
                   @line_number_id_prefix = "line-",
                   @line_number_start = 1,
                   @tab_width = 8,
                   @line_numbers : Bool = false,
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
    end

    def format(text : String, lexer : BaseLexer, io : IO) : Nil
      pre, post = wrap_standalone
      io << pre if standalone?
      format_text(text, lexer, io)
      io << post if standalone?
    end

    # Wrap text into a full HTML document, including the CSS for the theme
    def wrap_standalone
      output = String.build do |outp|
        outp << %(<?xml version="1.0" encoding="utf-8"?>
        <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.0//EN" "http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd">
        <svg xmlns="http://www.w3.org/2000/svg">
        <g font-family="#{self.@font_family}" font-size="#{self.@font_size}">)
      end
      {output.to_s, "</g></svg>"}
    end

    private def line_label(i : Int32, x : Int32, y : Int32) : String
      line_label = "#{i + 1}".rjust(4).ljust(5)
      line_style = highlighted?(i + 1) ? "font-weight=\"#{@weight_of_bold}\"" : ""
      line_id = linkable_line_numbers? ? "id=\"#{line_number_id_prefix}#{i + 1}\"" : ""
      %(<text #{line_style} #{line_id}  x="#{4*ystep}" y="#{y}" text-anchor="end">#{line_label}</text>)
    end

    def format_text(text : String, lexer : BaseLexer, outp : IO)
      x = 0
      y = ystep
      i = 0
      line_x = x
      line_x += 5 * ystep if line_numbers?
      tokenizer = lexer.tokenizer(text)
      outp << line_label(i, x, y) if line_numbers?
      outp << %(<text x="#{line_x}" y="#{y}" xml:space="preserve">)
      tokenizer.each do |token|
        if token[:value].ends_with? "\n"
          outp << "<tspan #{get_style(token[:type])}>#{HTML.escape(token[:value][0...-1])}</tspan>"
          outp << "</text>"
          x = 0
          y += ystep
          i += 1
          outp << line_label(i, x, y) if line_numbers?
          outp << %(<text x="#{line_x}" y="#{y}" xml:space="preserve">)
        else
          outp << "<tspan#{get_style(token[:type])}>#{HTML.escape(token[:value])}</tspan>"
          x += token[:value].size * ystep
        end
      end
      outp << "</text>"
    end

    # Given a token type, return the style.
    def get_style(token : String) : String
      if !theme.styles.has_key? token
        # Themes don't contain information for each specific
        # token type. However, they may contain information
        # for a parent style. Worst case, we go to the root
        # (Background) style.
        parent = theme.style_parents(token).reverse.find { |dad|
          theme.styles.has_key?(dad)
        }
        theme.styles[token] = theme.styles[parent]
      end
      output = String.build do |outp|
        style = theme.styles[token]
        outp << " fill=\"##{style.color.try &.hex}\"" if style.color
        # No support for background color or border in SVG

        outp << " font-weight=\"#{@weight_of_bold}\"" if style.bold
        outp << " font-weight=\"normal\"" if style.bold == false
        outp << " font-style=\"italic\"" if style.italic
        outp << " font-style=\"normal\"" if style.italic == false
        outp << " text-decoration=\"underline\"" if style.underline
        outp << " text-decoration=\"none" if style.underline == false
      end
      output
    end
  end
end
