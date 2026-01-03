require "../formatter"
require "./image"

module Tartrazine
  def self.to_jpeg(text : String, language : String,
                   theme : String = "default-dark",
                   line_numbers : Bool = false,
                   padding_left : Int32 = 20,
                   padding_right : Int32 = 20,
                   padding_top : Int32 = 20,
                   padding_bottom : Int32 = 20,
                   font_path : String? = nil,
                   font_size : Int32 = 14,
                   quality : Int32 = 90,
                   max_width : Int32 = 0,
                   max_height : Int32 = 0) : String
    buf = IO::Memory.new

    formatter = Tartrazine::Jpeg.new(
      theme: Tartrazine.theme(theme),
      line_numbers: line_numbers,
      font_path: font_path,
      font_size: font_size,
      quality: quality,
      max_width: max_width,
      max_height: max_height
    )
    formatter.padding_left = padding_left
    formatter.padding_right = padding_right
    formatter.padding_top = padding_top
    formatter.padding_bottom = padding_bottom

    formatter.format(text, Tartrazine.lexer(name: language), buf)
    buf.to_s
  end

  class Jpeg < ImageFormatter
    property quality : Int32 = 90

    def initialize(@theme : Theme = Tartrazine.theme("default-dark"),
                   @line_numbers : Bool = false,
                   @font_path : String? = nil,
                   @font_size : Int32 = 14,
                   @quality : Int32 = 90,
                   @max_width : Int32 = 0,
                   @max_height : Int32 = 0)
      # Font will be loaded when needed
    end

    private def write_image(outp : IO, img : CrImage::RGBA) : Nil
      # Note: Quality setting not currently supported in Crimage's JPEG encoder
      CrImage::JPEG.write(outp, img)
    end
  end
end
