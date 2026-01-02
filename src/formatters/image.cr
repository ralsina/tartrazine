require "../formatter"
require "crimage"

module Tartrazine
  # Default font: JetBrains Mono (rebranded as "Tiny-Regular.ttf")
  # Licensed under SIL Open Font License 1.1 (OFL-1.1)
  # See: fonts/OFL.txt and fonts/README.md for details
  # Copyright 2020 The JetBrains Mono Project Authors
  #
  # Base class for image formatters (PNG, JPEG, WebP)
  # Handles all common image rendering logic
  abstract class ImageFormatter < Formatter
    property? line_numbers : Bool = false
    property font_path : String? = nil
    property font_size : Int32 = 14
    # Padding properties
    property padding_left : Int32 = 20
    property padding_right : Int32 = 20
    property padding_top : Int32 = 20
    property padding_bottom : Int32 = 20

    @font_face : FreeType::TrueType::Face? = nil

    def initialize(@theme : Theme = Tartrazine.theme("default-dark"),
                   @line_numbers : Bool = false,
                   @font_path : String? = nil,
                   @font_size : Int32 = 14)
      # Font will be loaded when needed
    end

    # For testing - override font size (PNG only for backward compatibility)
    def set_font_size(width : Int32, height : Int32)
      # Old API had width,height, new API has point size
      # For backward compatibility with tests, approximate point size from height
      @font_size = (height.to_f * 0.45).to_i32
    end

    private def load_font_face : FreeType::TrueType::Face
      path = font_path || default_font_path

      @font_face ||= begin
        # Load font file (either user-provided or default bundled font)
        font = FreeType::TrueType.load(path)
        FreeType::TrueType.new_face(font, font_size.to_f64)
      end
    end

    private def default_font_path : String
      # Path to bundled Tiny-Regular.ttf font (JetBrains Mono)
      File.join(__DIR__, "../../fonts/Tiny-Regular.ttf")
    end

    private def line_label(i : Int32) : String
      "#{i + 1}".rjust(4).ljust(5)
    end

    private def hex_to_color(hex : String?) : CrImage::Color::Color
      if hex
        r = hex[0..1].to_i(16)
        g = hex[2..3].to_i(16)
        b = hex[4..5].to_i(16)
        CrImage::Color.rgb(r, g, b)
      else
        CrImage::Color::BLACK
      end
    end

    def format(text : String, lexer : BaseLexer, outp : IO) : Nil
      # Load font
      font_face = load_font_face

      # Create canvas of correct size with padding
      lines = text.split("\n")
      text_width = lines.max_of(&.size)
      text_width += 5 if line_numbers?

      # Estimate character width based on font size
      char_width = (font_size * 0.6).to_i32
      line_height = (font_size * 1.2).to_i32

      canvas_width = text_width * char_width + padding_left + padding_right
      canvas_height = lines.size * line_height + padding_top + padding_bottom

      # Create image with background color
      bg_style = theme.styles["Background"]
      bg_color = hex_to_color(bg_style.background.try &.hex)

      # Create a blank image and fill it with background color
      rect = CrImage::Rectangle.new(
        CrImage::Point.new(0, 0),
        CrImage::Point.new(canvas_width, canvas_height)
      )
      img = CrImage::RGBA.new(rect)
      img.fill(bg_color)

      # Create a default colored source for text (use foreground color from theme)
      default_color = hex_to_color(bg_style.color.try &.hex)
      default_src = CrImage::Uniform.new(default_color)

      tokenizer = lexer.tokenizer(text)
      x = padding_left
      y = padding_top + line_height
      i = 0

      if line_numbers?
        # Use default color for line numbers
        drawer = CrImage::Font::Drawer.new(img, default_src, font_face)
        drawer.draw_text(line_label(i), x, y)
        x += 5 * char_width
      end

      tokenizer.each do |token|
        t = token[:value].rstrip("\n")

        # Get the color for this token
        _, token_color = token_style(token[:type], font_face)
        token_src = CrImage::Uniform.new(token_color)

        # Create a new drawer with the token's color
        drawer = CrImage::Font::Drawer.new(img, token_src, font_face)
        drawer.draw_text(t, x, y)

        if token[:value].includes?("\n")
          x = padding_left
          y += line_height
          i += 1
          if line_numbers?
            drawer = CrImage::Font::Drawer.new(img, default_src, font_face)
            drawer.draw_text(line_label(i), x, y)
            x += 5 * char_width
          end
        end

        x += token[:value].size * char_width
      end

      # Write image to output using the appropriate encoder
      write_image(outp, img)
    end

    # Subclasses must implement this to use their specific encoder
    private abstract def write_image(outp : IO, img : CrImage::RGBA) : Nil

    private def token_style(token : String, font_face : FreeType::TrueType::Face) : {FreeType::TrueType::Face, CrImage::Color::Color}
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

      # Get the default text color
      color = hex_to_color(theme.styles["Background"].color.try &.hex)
      # Override with token-specific color if available
      color = hex_to_color(s.color.try &.hex) if s.color

      # Note: Bold/italic font variants are not currently supported
      # We use the same font face for all tokens
      {font_face, color}
    end
  end
end
