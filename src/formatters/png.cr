require "../formatter"
require "stumpy_png"
require "stumpy_utils"
require "compress/gzip"

module Tartrazine
  def self.to_png(text : String, language : String,
                  theme : String = "default-dark",
                  line_numbers : Bool = false) : String
    Tartrazine::Png.new(
      theme: Tartrazine.theme(theme),
      line_numbers: line_numbers
    ).format(text, Tartrazine.lexer(name: language))
  end

  class FontFiles
    extend BakedFileSystem
    bake_folder "../../fonts", __DIR__
  end

  class Png < Formatter
    include StumpyPNG
    property? line_numbers : Bool = false
    @font_regular : PCFParser::Font
    @font_bold : PCFParser::Font
    @font_oblique : PCFParser::Font
    @font_bold_oblique : PCFParser::Font
    @font_width = 15
    @font_height = 24

    def initialize(@theme : Theme = Tartrazine.theme("default-dark"), @line_numbers : Bool = false)
      @font_regular = load_font("/courier-regular.pcf.gz")
      @font_bold = load_font("/courier-bold.pcf.gz")
      @font_oblique = load_font("/courier-oblique.pcf.gz")
      @font_bold_oblique = load_font("/courier-bold-oblique.pcf.gz")
    end

    private def load_font(name : String) : PCFParser::Font
      compressed = FontFiles.get(name)
      uncompressed = Compress::Gzip::Reader.open(compressed) do |gzip|
        gzip.gets_to_end
      end
      PCFParser::Font.new(IO::Memory.new uncompressed)
    end

    private def line_label(i : Int32) : String
      "#{i + 1}".rjust(4).ljust(5)
    end

    def format(text : String, lexer : BaseLexer, outp : IO) : Nil
      # Create canvas of correct size
      lines = text.split("\n")
      canvas_height = lines.size * @font_height
      canvas_width = lines.max_of(&.size)
      canvas_width += 5 if line_numbers?
      canvas_width *= @font_width

      bg_color = RGBA.from_hex("##{theme.styles["Background"].background.try &.hex}")
      canvas = Canvas.new(canvas_width, canvas_height, bg_color)

      tokenizer = lexer.tokenizer(text)
      x = 0
      y = @font_height
      i = 0
      if line_numbers?
        canvas.text(x, y, line_label(i), @font_regular, RGBA.from_hex("##{theme.styles["Background"].color.try &.hex}"))
        x += 5 * @font_width
      end

      tokenizer.each do |token|
        font, color = token_style(token[:type])
        # These fonts are very limited
        t = token[:value].gsub(/[^[:ascii:]]/, "?")
        canvas.text(x, y, t.rstrip("\n"), font, color)
        if token[:value].includes?("\n")
          x = 0
          y += @font_height
          i += 1
          if line_numbers?
            canvas.text(x, y, line_label(i), @font_regular, RGBA.from_hex("##{theme.styles["Background"].color.try &.hex}"))
            x += 4 * @font_width
          end
        end

        x += token[:value].size * @font_width
      end

      StumpyPNG.write(canvas, outp)
    end

    def token_style(token : String) : {PCFParser::Font, RGBA}
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

      color = RGBA.from_hex("##{theme.styles["Background"].color.try &.hex}")
      color = RGBA.from_hex("##{s.color.try &.hex}") if s.color

      return {@font_bold_oblique, color} if s.bold && s.italic
      return {@font_bold, color} if s.bold
      return {@font_oblique, color} if s.italic
      return {@font_regular, color}
    end
  end
end
