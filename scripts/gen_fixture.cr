require "../src/tartrazine"

path = ARGV[0]
lexer = Tartrazine.lexer(name: File.basename(File.dirname(path)).downcase)
tokens = Tartrazine::RegexLexer.collapse_tokens(lexer.tokenizer(File.read(path)).to_a)
File.write("#{path}.json", tokens.to_json + "\n")
puts "wrote #{path}.json (#{tokens.size} tokens)"
