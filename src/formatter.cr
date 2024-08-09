require "./actions"
require "./constants"
require "./formatter"
require "./rules"
require "./styles"
require "./tartrazine"
require "colorize"

module Tartrazine
  # This is the base class for all formatters.
  abstract class Formatter
    property name : String = ""

    def format(text : String, lexer : Lexer, theme : Theme) : String
      raise Exception.new("Not implemented")
    end

    def get_style_defs(theme : Theme) : String
      raise Exception.new("Not implemented")
    end
  end
end
