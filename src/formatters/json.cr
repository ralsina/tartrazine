require "../formatter"

module Tartrazine
  class Json < Formatter
    property name = "json"

    def format(text : String, lexer : Lexer) : String
      outp = String::Builder.new("")
      format(text, lexer, outp)
      return outp.to_s
    end


    def format(text : String, lexer : Lexer, io : IO) : Nil
      tokenizer = Tokenizer.new(lexer, text)
      io << Tartrazine::Lexer.collapse_tokens(tokenizer.to_a).to_json
    end
  end
end
