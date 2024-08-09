require "./**"

lexer = Tartrazine.lexer("crystal")
theme = Tartrazine.theme(ARGV[1])
formatter = Tartrazine::Html.new
formatter.standalone = true
formatter.class_prefix = "hl-"
formatter.line_number_id_prefix = "ln-"
formatter.line_numbers = true
formatter.highlight_lines = [3..7, 20..30]
puts formatter.format(File.read(ARGV[0]), lexer, theme)
