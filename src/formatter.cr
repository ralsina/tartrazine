require "./actions"
require "./constants"
require "./formatter"
require "./rules"
require "./styles"
require "./tartrazine"
require "colorize"

module Tartrazine
  # This is the base class for all formatters.
  abstract class Formatter
    property name : String = ""

    def format(text : String, lexer : Lexer, theme : Theme) : String
      raise Exception.new("Not implemented")
    end

    def get_style_defs(theme : Theme) : String
      raise Exception.new("Not implemented")
    end
  end

  class Ansi < Formatter
    def format(text : String, lexer : Lexer, theme : Theme) : String
      output = String.build do |outp|
        lexer.tokenize(text).each do |token|
          outp << self.colorize(token[:value], token[:type], theme)
        end
      end
      output
    end

    def colorize(text : String, token : String, theme : Theme) : String
      style = theme.styles.fetch(token, nil)
      return text if style.nil?
      if theme.styles.has_key?(token)
        s = theme.styles[token]
      else
        # Themes don't contain information for each specific
        # token type. However, they may contain information
        # for a parent style. Worst case, we go to the root
        # (Background) style.
        s = theme.styles[theme.style_parents(token).reverse.find { |parent|
          theme.styles.has_key?(parent)
        }]
      end
      colorized = text.colorize(*rgb(s.color))
      # Intentionally not setting background color
      colorized.mode(:bold) if s.bold
      colorized.mode(:italic) if s.italic
      colorized.mode(:underline) if s.underline
      colorized.to_s
    end

    def rgb(c : String?)
      return {0_u8, 0_u8, 0_u8} unless c
      r = c[0..1].to_u8(16)
      g = c[2..3].to_u8(16)
      b = c[4..5].to_u8(16)
      {r, g, b}
    end
  end

  class Html < Formatter
    def format(text : String, lexer : Lexer, theme : Theme) : String
      output = String.build do |outp|
        outp << "<html><head><style>"
        outp << get_style_defs(theme)
        outp << "</style></head><body>"
        outp << "<pre class=\"#{get_css_class("Background", theme)}\"><code class=\"#{get_css_class("Background", theme)}\">"
        lexer.tokenize(text).each do |token|
          fragment = "<span class=\"#{get_css_class(token[:type], theme)}\">#{token[:value]}</span>"
          outp << fragment
        end
        outp << "</code></pre></body></html>"
      end
      output
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def get_style_defs(theme : Theme) : String
      output = String.build do |outp|
        theme.styles.each do |token, style|
          outp << ".#{get_css_class(token, theme)} {"
          # These are set or nil
          outp << "color: #{style.color};" if style.color
          outp << "background-color: #{style.background};" if style.background
          outp << "border: 1px solid #{style.border};" if style.border

          # These are true/false/nil
          outp << "border: none;" if style.border == false
          outp << "font-weight: bold;" if style.bold
          outp << "font-weight: 400;" if style.bold == false
          outp << "font-style: italic;" if style.italic
          outp << "font-style: normal;" if style.italic == false
          outp << "text-decoration: underline;" if style.underline
          outp << "text-decoration: none;" if style.underline == false

          outp << "}"
        end
      end
      output
    end

    # Given a token type, return the CSS class to use.
    def get_css_class(token, theme)
      return Abbreviations[token] if theme.styles.has_key?(token)

      # Themes don't contain information for each specific
      # token type. However, they may contain information
      # for a parent style. Worst case, we go to the root
      # (Background) style.
      Abbreviations[theme.style_parents(token).reverse.find { |parent|
        theme.styles.has_key?(parent)
      }]
    end
  end
end
