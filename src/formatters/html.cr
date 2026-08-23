require "../constants/token_abbrevs.cr"
require "../formatter"
require "html"

module Tartrazine
  def self.to_html(text : String, language : String,
                   theme : String = "default-dark",
                   standalone : Bool = true,
                   line_numbers : Bool = false) : String
    Tartrazine::Html.new(
      theme: Tartrazine.theme(theme),
      standalone: standalone,
      line_numbers: line_numbers
    ).format(text, Tartrazine.lexer(name: language))
  end

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
    property template : String = <<-TEMPLATE
<!DOCTYPE html><html><head><style>
{{style_defs}}
</style></head><body>
{{body}}
</body></html>
TEMPLATE

    property theme : Theme

    @class_cache = {} of String => String

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
                   @weight_of_bold : Int32 = 600,
                   @template : String = @template)
    end

    def format(text : String, lexer : Lexer) : String
      outp = String::Builder.new("")
      format(text, lexer, outp)
      outp.to_s
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
        if @template.includes? "{{style_defs}}"
          outp << @template.split("{{style_defs}}")[0]
          outp << style_defs
          outp << @template.split("{{style_defs}}")[1].split("{{body}}")[0]
        else
          outp << @template.split("{{body}}")[0]
        end
      end
      {output.to_s, @template.split("{{body}}")[1]}
    end

    private def line_label(i : Int32) : String
      line_label = "#{i + 1}".rjust(4).ljust(5)
      line_class = highlighted?(i + 1) ? "class=\"#{get_css_class("LineHighlight")}\"" : ""
      line_id = linkable_line_numbers? ? "id=\"#{line_number_id_prefix}#{i + 1}\"" : ""
      "<span #{line_id} #{line_class} style=\"user-select: none;\">#{line_label} </span>"
    end

    def format_text(text : String, lexer : BaseLexer, outp : IO)
      tokenizer = lexer.tokenizer(text)
      i = 0
      if surrounding_pre?
        pre_style = wrap_long_lines? ? "style=\"white-space: pre-wrap; word-break: break-word;\"" : ""
        outp << "<pre class=\"#{get_css_class("Background")}\" #{pre_style}>"
      end
      outp << "<code class=\"#{get_css_class("Background")}\">"
      outp << line_label(i) if line_numbers?
      tokenizer.each do |token|
        outp << "<span class=\""
        outp << get_css_class(token[:type])
        outp << "\">"
        escape_to_io(token[:value], outp)
        outp << "</span>"
        if token[:value].ends_with? "\n"
          i += 1
          outp << line_label(i) if line_numbers?
        end
      end
      outp << "</code></pre>"
    end

    # Write text escaping HTML special characters without building
    # intermediate strings
    private def escape_to_io(text : String, io : IO) : Nil
      start = 0
      bytes = text.to_slice
      bytes.each_with_index do |byte, index|
        entity = case byte
                 when '&'.ord  then "&amp;"
                 when '<'.ord  then "&lt;"
                 when '>'.ord  then "&gt;"
                 when '"'.ord  then "&quot;"
                 when '\''.ord then "&#39;"
                 else               nil
                 end
        next if entity.nil?
        io.write(bytes[start, index - start]) if index > start
        io << entity
        start = index + 1
      end
      io.write(bytes[start, text.bytesize - start]) if start < text.bytesize
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
          outp << "font-weight: #{@weight_of_bold};" if style.bold
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
      cached = @class_cache[token]?
      return cached if cached

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
      @class_cache[token] = class_prefix + Abbreviations[token]
    end
  end
end
