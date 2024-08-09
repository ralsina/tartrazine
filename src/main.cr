require "./**"

HELP = <<-HELP
tartrazine: a syntax highlighting tool

Usage:

  tartrazine FILE -f html [-t theme][--standalone][--line-numbers]
                          [-l lexer] [-o output][--css]
  tartrazine FILE -f terminal [-t theme][-l lexer][-o output]
  tartrazine FILE -f json [-o output]
  tartrazine --list-themes
  tartrazine --list-lexers

-f <formatter>      Format to use (html, terminal, json)
-t <theme>          Theme to use (see --list-themes)
-l <lexer>          Lexer (language) to use (see --list-lexers)
-o <output>         Output file (default: stdout)
--standalone        Generate a standalone HTML file
--css               Generate a CSS file for the theme
--line-numbers      Include line numbers in the output
HELP

lexer = Tartrazine.lexer("crystal")
theme = Tartrazine.theme(ARGV[1])
formatter = Tartrazine::Json.new
# formatter.standalone = true
# formatter.class_prefix = "hl-"
# formatter.line_number_id_prefix = "ln-"
# formatter.line_numbers = true
# formatter.highlight_lines = [3..7, 20..30]
# formatter.linkable_line_numbers = false
# formatter.wrap_long_lines = false
puts formatter.format(File.read(ARGV[0]), lexer, theme)
