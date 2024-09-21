require "./actions"
require "./formatter"
require "./rules"
require "./styles"
require "./tartrazine"
require "colorize"

module Tartrazine
  # This is the base class for all formatters.
  abstract class Formatter
    property name : String = ""
    property theme : Theme = Tartrazine.theme("default-dark")

    # Format the text using the given lexer.
    def format(text : String, lexer : Lexer, io : IO = nil) : Nil
      raise Exception.new("Not implemented")
    end

    def format(text : String, lexer : Lexer) : String
      outp = String::Builder.new("")
      format(text, lexer, outp)
      outp.to_s
    end

    # Return the styles, if the formatter supports it.
    def style_defs : String
      raise Exception.new("Not implemented")
    end

    # Is this line in the highlighted ranges?
    def highlighted?(line : Int) : Bool
      highlight_lines.any?(&.includes?(line))
    end
  end
end
