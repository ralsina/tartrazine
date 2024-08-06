require "./**" 

lexer = Tartrazine.lexer("crystal")
theme = Tartrazine.theme(ARGV[1])
puts Tartrazine::Html.new.format(File.read(ARGV[0]), lexer, theme)
