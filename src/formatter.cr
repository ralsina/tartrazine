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
    def format(text : String, lexer : Lexer) : String
      raise Exception.new("Not implemented")
    end

    # Return the styles, if the formatter supports it.
    def style_defs : String
      raise Exception.new("Not implemented")
    end
  end
end
