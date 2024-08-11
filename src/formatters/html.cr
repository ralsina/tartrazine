require "../constants/token_abbrevs.cr"
require "../formatter"

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

    def format(text : String, lexer : Lexer, theme : Theme) : String
      text = format_text(text, lexer, theme)
      if standalone?
        text = wrap_standalone(text, theme)
      end
      text
    end

    # Wrap text into a full HTML document, including the CSS for the theme
    def wrap_standalone(text, theme) : String
      output = String.build do |outp|
        outp << "<!DOCTYPE html><html><head><style>"
        outp << get_style_defs(theme)
        outp << "</style></head><body>"
        outp << text
        outp << "</body></html>"
      end
      output
    end

    def format_text(text : String, lexer : Lexer, theme : Theme) : String
      lines = lexer.group_tokens_in_lines(lexer.tokenize(text))
      output = String.build do |outp|
        if surrounding_pre?
          pre_style = wrap_long_lines? ? "style=\"white-space: pre-wrap; word-break: break-word;\"" : ""
          outp << "<pre class=\"#{get_css_class("Background", theme)}\" #{pre_style}>"
        end
        "<code class=\"#{get_css_class("Background", theme)}\">"
        lines.each_with_index(offset: line_number_start - 1) do |line, i|
          line_label = line_numbers? ? "#{i + 1}".rjust(4).ljust(5) : ""
          line_class = highlighted?(i + 1) ? "class=\"#{get_css_class("LineHighlight", theme)}\"" : ""
          line_id = linkable_line_numbers? ? "id=\"#{line_number_id_prefix}#{i + 1}\"" : ""
          outp << "<span #{line_id} #{line_class} style=\"user-select: none;\">#{line_label} </span>"
          line.each do |token|
            fragment = "<span class=\"#{get_css_class(token[:type], theme)}\">#{token[:value]}</span>"
            outp << fragment
          end
        end
        outp << "</code></pre>"
      end
      output
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def get_style_defs(theme : Theme) : String
      output = String.build do |outp|
        theme.styles.each do |token, style|
          outp << ".#{get_css_class(token, theme)} {"
          # These are set or nil
          outp << "color: ##{style.color.try &.hex};" if style.color
          outp << "background-color: ##{style.background.try &.hex};" if style.background
          outp << "border: 1px solid ##{style.border.try &.hex};" if style.border

          # These are true/false/nil
          outp << "border: none;" if style.border == false
          outp << "font-weight: bold;" if style.bold
          outp << "font-weight: 400;" if style.bold == false
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
    def get_css_class(token, theme)
      return class_prefix + Abbreviations[token] if theme.styles.has_key?(token)

      # Themes don't contain information for each specific
      # token type. However, they may contain information
      # for a parent style. Worst case, we go to the root
      # (Background) style.
      class_prefix + Abbreviations[theme.style_parents(token).reverse.find { |parent|
        theme.styles.has_key?(parent)
      }]
    end

    def highlighted?(line : Int) : Bool
      highlight_lines.any?(&.includes?(line))
    end
  end
end
