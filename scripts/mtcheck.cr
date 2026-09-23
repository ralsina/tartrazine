require "../src/tartrazine"

# Concurrent tokenization of ONE shared lexer: every fiber must
# produce identical, correct tokens.
lexer = Tartrazine.lexer("python")
sample = File.read("/usr/lib/python3.14/typing.py")
expected = lexer.tokenizer(sample).to_a

channel = Channel(Bool).new
10.times do
  spawn do
    tokens = lexer.tokenizer(sample).to_a
    channel.send(tokens == expected)
  end
end
results = Array.new(10) { channel.receive }
puts "concurrent runs identical: #{results.all?}"
puts "first mismatch sample:" unless results.all?
