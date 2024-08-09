require "./**"

lexer = Tartrazine.lexer("crystal")
theme = Tartrazine.theme(ARGV[1])
formatter = Tartrazine::Html.new
formatter.standalone = true
formatter.class_prefix = "tartrazine-"
puts formatter.format(File.read(ARGV[0]), lexer, theme)
