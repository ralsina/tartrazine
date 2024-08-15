require "../constants/token_abbrevs.cr"
require "../formatter"
require "html"

module Tartrazine
  class Html < Formatter
    # property line_number_in_table : Bool = false
    # property with_classes : Bool = true
    property class_prefix : String = ""
    property highlight_lines : Array(Range(Int32, Int32)) = [] of Range(Int32, Int32)
    property line_number_id_prefix : String = "line-"
    property line_number_start : Int32 = 1
    property tab_width = 8
    property? line_numbers : Bool = false
    property? linkable_line_numbers : Bool = true
    property? standalone : Bool = false
    property? surrounding_pre : Bool = true
    property? wrap_long_lines : Bool = false
    property weight_of_bold : Int32 = 600

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
                   @surrounding_pre : Bool = true,
                   @wrap_long_lines : Bool = false,
                   @weight_of_bold : Int32 = 600)
    end

    def format(text : String, lexer : Lexer) : String
      text = format_text(text, lexer)
      if standalone?
        text = wrap_standalone(text)
      end
      text
    end

    # Wrap text into a full HTML document, including the CSS for the theme
    def wrap_standalone(text) : String
      output = String.build do |outp|
        outp << "<!DOCTYPE html><html><head><style>"
        outp << style_defs
        outp << "</style></head><body>"
        outp << text
        outp << "</body></html>"
      end
      output
    end

    def format_text(text : String, lexer : Lexer) : String
      lines = lexer.group_tokens_in_lines(lexer.tokenize(text))
      output = String.build do |outp|
        if surrounding_pre?
          pre_style = wrap_long_lines? ? "style=\"white-space: pre-wrap; word-break: break-word;\"" : ""
          outp << "<pre class=\"#{get_css_class("Background")}\" #{pre_style}>"
        end
        outp << "<code class=\"#{get_css_class("Background")}\">"
        lines.each_with_index(offset: line_number_start - 1) do |line, i|
          line_label = line_numbers? ? "#{i + 1}".rjust(4).ljust(5) : ""
          line_class = highlighted?(i + 1) ? "class=\"#{get_css_class("LineHighlight")}\"" : ""
          line_id = linkable_line_numbers? ? "id=\"#{line_number_id_prefix}#{i + 1}\"" : ""
          outp << "<span #{line_id} #{line_class} style=\"user-select: none;\">#{line_label} </span>"
          line.each do |token|
            fragment = "<span class=\"#{get_css_class(token[:type])}\">#{HTML.escape(token[:value])}</span>"
            outp << fragment
          end
        end
        outp << "</code></pre>"
      end
      output
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def style_defs : String
      output = String.build do |outp|
        theme.styles.each do |token, style|
          outp << ".#{get_css_class(token)} {"
          # These are set or nil
          outp << "color: ##{style.color.try &.hex};" if style.color
          outp << "background-color: ##{style.background.try &.hex};" if style.background
          outp << "border: 1px solid ##{style.border.try &.hex};" if style.border

          # These are true/false/nil
          outp << "border: none;" if style.border == false
          outp << "font-weight: bold;" if style.bold
          outp << "font-weight: #{@weight_of_bold};" if style.bold == false
          outp << "font-style: italic;" if style.italic
          outp << "font-style: normal;" if style.italic == false
          outp << "text-decoration: underline;" if style.underline
          outp << "text-decoration: none;" if style.underline == false
          outp << "tab-size: #{tab_width};" if token == "Background"

          outp << "}"
        end
      end
      output
    end

    # Given a token type, return the CSS class to use.
    def get_css_class(token : String) : String
      return class_prefix + Abbreviations[token] if theme.styles.has_key?(token)

      # Themes don't contain information for each specific
      # token type. However, they may contain information
      # for a parent style. Worst case, we go to the root
      # (Background) style.
      class_prefix + Abbreviations[theme.style_parents(token).reverse.find { |parent|
        theme.styles.has_key?(parent)
      }]
    end

    # Is this line in the highlighted ranges?
    def highlighted?(line : Int) : Bool
      highlight_lines.any?(&.includes?(line))
    end
  end
end
