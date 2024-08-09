require "../formatter"

module Tartrazine
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
              outp << "color: #{style.color.try &.hex};" if style.color
              outp << "background-color: #{style.background.try &.hex};" if style.background
              outp << "border: 1px solid #{style.border.try &.hex};" if style.border
    
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