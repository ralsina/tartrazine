require "../constants/token_abbrevs.cr"
require "../formatter"
require "html"

module Tartrazine
  def self.to_highlights(text : String, language : String,
                         theme : String = "default-dark",
                         standalone : Bool = true,
                         line_numbers : Bool = false) : String
    Tartrazine::Highlights.new(
      theme: Tartrazine.theme(theme),
      standalone: standalone,
      line_numbers: line_numbers
    ).format(text, Tartrazine.lexer(name: language))
  end

  class Highlights < Formatter
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
    property template : String = <<-TEMPLATE
<!DOCTYPE html><html><head><style>
{{style_defs}}
</style></head><body>
{{body}}
</body></html>
TEMPLATE

    property theme : Theme

    def initialize(@theme : Theme = Tartrazine.theme("default-dark"), *,
                   @highlight_lines = [] of Range(Int32, Int32),
                   @class_prefix : String = "",
                   @line_number_id_prefix : String = "line-",
                   @line_number_start : Int32 = 1,
                   @tab_width = 8,
                   @line_numbers : Bool = false,
                   @linkable_line_numbers : Bool = true,
                   @standalone : Bool = false,
                   @surrounding_pre : Bool = true,
                   @wrap_long_lines : Bool = false,
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

    # Wrap text into a full HTML document, including the CSS
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
      "#{line_label} "
    end

    def format_text(text : String, lexer : BaseLexer, outp : IO)
      tokenizer = lexer.tokenizer(text)
      i = 0
      if surrounding_pre?
        pre_style = wrap_long_lines? ? "style=\"white-space: pre-wrap; word-break: break-word;\"" : ""
        outp << "<pre id=\"code\" #{pre_style}>"
      else
        outp << "<pre id=\"code\">"
      end

      # First collect and collapse tokens like JSON formatter does
      all_raw_tokens = Tartrazine::RegexLexer.collapse_tokens(tokenizer.to_a)
      current_pos = 0
      text_content = String::Builder.new
      all_tokens = [] of {type: String, text: String, start_pos: Int32, end_pos: Int32}

      if line_numbers?
        line_label_text = line_label(i)
        text_content << line_label_text
        current_pos += line_label_text.size
      end

      all_raw_tokens.each do |token|
        start_pos = current_pos
        token_text = HTML.escape(token[:value])
        end_pos = start_pos + token[:value].size


        text_content << token_text
        current_pos = end_pos

        all_tokens << {type: token[:type], text: token_text, start_pos: start_pos, end_pos: end_pos}

        if token[:value].ends_with? "\n"
          i += 1
          if line_numbers?
            line_label_text = line_label(i)
            text_content << line_label_text
            current_pos += line_label_text.size
          end
        end
      end

      final_text = text_content.to_s
      outp << final_text
      outp << "</pre>"

      # Generate ranges using the actual text length
      token_ranges_by_type = Hash(String, Array(String)).new
      text_length = final_text.size

      all_tokens.each do |token|
        # Ensure positions are within bounds
        start_pos = [token[:start_pos], text_length].min
        end_pos = [token[:end_pos], text_length].min

        range_name = get_highlight_name(token[:type])
        token_ranges_by_type[range_name] ||= [] of String
        token_ranges_by_type[range_name] << "range.setStart(textNode, #{start_pos}); range.setEnd(textNode, #{end_pos});"
      end

      # Add JavaScript for highlights registration
      outp << "<script>"
      outp << generate_simple_highlight_script(token_ranges_by_type)
      outp << "</script>"
    end

    # Generate compact JavaScript to register CSS highlights with known positions
    private def generate_simple_highlight_script(token_ranges_by_type : Hash(String, Array(String))) : String
      script = String::Builder.new

      script << "(function(){"
      script << "if(!window.CSS||!CSS.highlights){return;}"
      script << "const textNode=document.getElementById('code').firstChild;"

      # Generate compact ranges for each token type
      token_ranges_by_type.each do |type, ranges|
        next if ranges.empty?
        script << "const #{type}Ranges=["
        ranges.each_with_index do |range_code, i|
          script << "," if i > 0
          # Parse the range code to extract start and end positions
          if match = range_code.match(/range\.setStart\(textNode, (\d+)\);.*range\.setEnd\(textNode, (\d+)\)/)
            start_pos = match[1]
            end_pos = match[2]
            script << "[#{start_pos},#{end_pos}]"
          end
        end
        script << "];"
        script << "CSS.highlights.set('#{type}',new Highlight(...#{type}Ranges.map(([s,e])=>{const r=new Range();r.setStart(textNode,Math.min(s,textNode.length));r.setEnd(textNode,Math.min(e,textNode.length));return r;})));"
      end

      script << "})();"

      script.to_s
    end

    # Generate CSS for ::highlight() pseudo-elements
    # Note: Only supports limited CSS properties allowed by the CSS Highlights API
    def style_defs : String
      output = String.build do |outp|
        outp << "/* CSS Highlights API - Limited property support */\n"
        outp << "/* Supported: color, background-color, text-decoration, text-shadow */\n"
        outp << "/* Unsupported: font-weight, font-style, border, tab-size */\n\n"

        theme.styles.each do |token, style|
          outp << "::highlight(#{get_highlight_name(token)}) {"

          # Only include properties supported by ::highlight()
          outp << "color: ##{style.color.try &.hex};" if style.color
          outp << "background-color: ##{style.background.try &.hex};" if style.background
          outp << "text-decoration: underline;" if style.underline
          outp << "text-decoration: none;" if style.underline == false

          # Note: text-shadow could be added if theme supports it

          outp << "}\n"
        end
      end
      output
    end

    # Given a token type, return the highlight name to use.
    # This needs to be a valid CSS custom highlight name
    def get_highlight_name(token : String) : String
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
      class_prefix + Abbreviations[token]
    end
  end
end
