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
      # Stream the collapsed tokens straight into the IO, avoiding
      # the intermediate raw token array and the whole-document
      # JSON string
      io << "["
      first = true
      previous_type = ""
      accumulated = String::Builder.new
      accumulating = false
      tokenizer.each do |token|
        next if token[:value].empty?
        if accumulating && previous_type == token[:type]
          accumulated << token[:value]
          next
        end
        if accumulating
          io << "," unless first
          first = false
          write_token(previous_type, accumulated.to_s, io)
          accumulated = String::Builder.new
        end
        previous_type = token[:type]
        accumulated << token[:value]
        accumulating = true
      end
      if accumulating
        io << "," unless first
        write_token(previous_type, accumulated.to_s, io)
      end
      io << "]"
    end

    # Same bytes as a collapsed token's to_json
    private def write_token(type : String, value : String, io : IO) : Nil
      io << "{\"type\":" << type.to_json << ",\"value\":" << value.to_json << "}"
    end
  end
end
