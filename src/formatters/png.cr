require "../formatter"
require "compress/gzip"
require "digest/sha1"
require "stumpy_png"
require "stumpy_utils"

module Tartrazine
  def self.to_png(text : String, language : String,
                  theme : String = "default-dark",
                  line_numbers : Bool = false,
                  padding_left : Int32 = 20,
                  padding_right : Int32 = 20,
                  padding_top : Int32 = 20,
                  padding_bottom : Int32 = 20,
                  font_path : String? = nil) : String
    buf = IO::Memory.new

    formatter = Tartrazine::Png.new(
      theme: Tartrazine.theme(theme),
      line_numbers: line_numbers,
      font_path: font_path
    )
    formatter.padding_left = padding_left
    formatter.padding_right = padding_right
    formatter.padding_top = padding_top
    formatter.padding_bottom = padding_bottom

    formatter.format(text, Tartrazine.lexer(name: language), buf)
    buf.to_s
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
    @font_width = 18
    @font_height = 32
    # Padding properties
    property padding_left : Int32 = 20
    property padding_right : Int32 = 20
    property padding_top : Int32 = 20
    property padding_bottom : Int32 = 20
    # Font configuration
    property font_path : String? = nil

    # For testing - override font size
    def set_font_size(width : Int32, height : Int32)
      @font_width = width
      @font_height = height
    end

    def initialize(@theme : Theme = Tartrazine.theme("default-dark"), @line_numbers : Bool = false, @font_path : String? = nil, font_width : Int32 = 18, font_height : Int32 = 32)
      @font_width = font_width
      @font_height = font_height
      if font_path
        if File.directory?(font_path)
          # Font directory - try to load variants
          @font_regular = load_font("#{font_path}/regular.pcf.gz")
          @font_bold = load_font_with_fallback("#{font_path}/bold.pcf.gz", @font_regular)
          @font_oblique = load_font_with_fallback("#{font_path}/oblique.pcf.gz", @font_regular)
          @font_bold_oblique = load_font_with_fallback("#{font_path}/bold-oblique.pcf.gz", @font_regular)
        else
          # Single font file - use for all variants
          @font_regular = load_font(font_path)
          @font_bold = @font_regular
          @font_oblique = @font_regular
          @font_bold_oblique = @font_regular
        end
      else
        # Default baked fonts (without leading slash)
        @font_regular = load_font("regular.pcf.gz")
        @font_bold = load_font("bold.pcf.gz")
        @font_oblique = load_font("oblique.pcf.gz")
        @font_bold_oblique = load_font("bold-oblique.pcf.gz")
      end
    end

    private def load_font(name : String) : PCFParser::Font
      if font_path
        # Load from custom font path (handle both compressed and uncompressed)
        if name.ends_with?(".gz")
          File.open(name) do |file|
            uncompressed = Compress::Gzip::Reader.open(file) do |gzip|
              gzip.gets_to_end
            end
            PCFParser::Font.new(IO::Memory.new uncompressed)
          end
        else
          File.open(name) do |file|
            PCFParser::Font.new(file)
          end
        end
      else
        # Load from baked fonts (compressed)
        compressed = FontFiles.get(name)
        uncompressed = Compress::Gzip::Reader.open(compressed) do |gzip|
          gzip.gets_to_end
        end
        PCFParser::Font.new(IO::Memory.new uncompressed)
      end
    end

    private def load_font_with_fallback(name : String, fallback : PCFParser::Font) : PCFParser::Font
      load_font(name)
    rescue ex
      # Fallback to regular font if variant is not available
      fallback
    end

    private def line_label(i : Int32) : String
      "#{i + 1}".rjust(4).ljust(5)
    end

    def format(text : String, lexer : BaseLexer, outp : IO) : Nil
      # Create canvas of correct size with padding
      lines = text.split("\n")
      text_width = lines.max_of(&.size)
      text_width += 5 if line_numbers?
      text_width *= @font_width

      canvas_height = lines.size * @font_height + padding_top + padding_bottom
      canvas_width = text_width + padding_left + padding_right

      bg_color = RGBA.from_hex("##{theme.styles["Background"].background.try &.hex}")
      canvas = Canvas.new(canvas_width, canvas_height, bg_color)

      tokenizer = lexer.tokenizer(text)
      x = padding_left
      y = @font_height + padding_top
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
          x = padding_left
          y += @font_height
          i += 1
          if line_numbers?
            canvas.text(x, y, line_label(i), @font_regular, RGBA.from_hex("##{theme.styles["Background"].color.try &.hex}"))
            x += 5 * @font_width
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
