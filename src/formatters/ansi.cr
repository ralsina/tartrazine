require "../formatter"

module Tartrazine
  class Ansi < Formatter
    property? line_numbers : Bool = false

    def initialize(@theme : Theme = Tartrazine.theme("default-dark"), @line_numbers : Bool = false)
    end

    private def line_label(i : Int32) : String
      "#{i + 1}".rjust(4).ljust(5)
    end

    def format(text : String, lexer : Lexer) : String
      tokenizer = Tokenizer.new(lexer, text)
      i = 0
      output = String.build do |outp|
        outp << line_label(i) if line_numbers?
        tokenizer.each do |token|
          outp << colorize(token[:value], token[:type])
          if token[:value].includes?("\n")
            i += 1
            outp << line_label(i) if line_numbers?
          end
        end
      end
      output
    end

    # def format(text : String, lexer : Lexer) : String
    #   output = String.build do |outp|
    #     lexer.group_tokens_in_lines(lexer.tokenize(text)).each_with_index do |line, i|
    #       label = line_numbers? ? "#{i + 1}".rjust(4).ljust(5) : ""
    #       outp << label
    #       line.each do |token|
    #         outp << colorize(token[:value], token[:type])
    #       end
    #     end
    #   end
    #   output
    # end

    def colorize(text : String, token : String) : String
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
      s.color.try { |col| colorized = colorized.fore(col.colorize) }
      # Intentionally not setting background color
      colorized.mode(:bold) if s.bold
      colorized.mode(:italic) if s.italic
      colorized.mode(:underline) if s.underline
      colorized.to_s
    end
  end
end