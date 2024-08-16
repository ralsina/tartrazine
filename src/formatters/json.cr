require "../formatter"

module Tartrazine
  class Json < Formatter
    property name = "json"

    def format(text : String, lexer : Lexer, outp : IO) : Nil
      tokenizer = Tokenizer.new(lexer, text)
      outp << Tartrazine::Lexer.collapse_tokens(tokenizer.to_a).to_json
    end
  end
end
