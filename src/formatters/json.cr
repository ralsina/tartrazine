require "../formatter"

module Tartrazine
  class Json < Formatter
    property name = "json"

    def format(text : String, lexer : Lexer, io : IO?) : String?
      outp = io.nil? ? String::Builder.new("") : io
      tokenizer = Tokenizer.new(lexer, text)
      outp << Tartrazine::Lexer.collapse_tokens(tokenizer.to_a).to_json
      return outp.to_s if io.nil?
    end
  end
end
