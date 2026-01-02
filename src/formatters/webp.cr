require "../formatter"
require "./image"

module Tartrazine
  def self.to_webp(text : String, language : String,
                   theme : String = "default-dark",
                   line_numbers : Bool = false,
                   padding_left : Int32 = 20,
                   padding_right : Int32 = 20,
                   padding_top : Int32 = 20,
                   padding_bottom : Int32 = 20,
                   font_path : String? = nil,
                   font_size : Int32 = 14,
                   quality : Int32 = 90) : String
    buf = IO::Memory.new

    formatter = Tartrazine::Webp.new(
      theme: Tartrazine.theme(theme),
      line_numbers: line_numbers,
      font_path: font_path,
      font_size: font_size,
      quality: quality
    )
    formatter.padding_left = padding_left
    formatter.padding_right = padding_right
    formatter.padding_top = padding_top
    formatter.padding_bottom = padding_bottom

    formatter.format(text, Tartrazine.lexer(name: language), buf)
    buf.to_s
  end

  class Webp < ImageFormatter
    property quality : Int32 = 90

    def initialize(@theme : Theme = Tartrazine.theme("default-dark"),
                   @line_numbers : Bool = false,
                   @font_path : String? = nil,
                   @font_size : Int32 = 14,
                   @quality : Int32 = 90)
      # Font will be loaded when needed
    end

    private def write_image(outp : IO, img : CrImage::RGBA) : Nil
      # Note: Crimage's WEBP encoder doesn't support quality setting in Options
      CrImage::WEBP.write(outp, img)
    end
  end
end
