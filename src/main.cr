require "./**" 

lexer = Tartrazine.lexer("crystal")
theme = Tartrazine.theme("catppuccin-macchiato")
puts Tartrazine::Html.new.format(File.read(ARGV[0]), lexer, theme)
