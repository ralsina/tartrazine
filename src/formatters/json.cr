require "../formatter"

module Tartrazine
  class Json < Formatter
    property name = "json"

    def format(text : String, lexer : Lexer, _theme : Theme) : String
      lexer.tokenize(text).to_json
    end
  end
end
