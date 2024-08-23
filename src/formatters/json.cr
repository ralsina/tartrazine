require "../formatter"

module Tartrazine
  class Json < Formatter
    property name = "json"

    def format(text : String, lexer : BaseLexer) : String
      outp = String::Builder.new("")
      format(text, lexer, outp)
      outp.to_s
    end

    def format(text : String, lexer : BaseLexer, io : IO) : Nil
      tokenizer = lexer.tokenizer(text)
      io << Tartrazine::Lexer.collapse_tokens(tokenizer.to_a).to_json
    end
  end
end
