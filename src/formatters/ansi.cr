require "../formatter"

module Tartrazine
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
      colorized = text.colorize
      s.color.try { |c| colorized = colorized.fore(c.colorize) }
      # Intentionally not setting background color
      colorized.mode(:bold) if s.bold
      colorized.mode(:italic) if s.italic
      colorized.mode(:underline) if s.underline
      colorized.to_s
    end
  end
end
