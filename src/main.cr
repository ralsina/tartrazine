require "docopt"
require "./**"

HELP = <<-HELP
tartrazine: a syntax highlighting tool

Usage:
  tartrazine (-h, --help)
  tartrazine FILE -f html [-t theme][--standalone][--line-numbers][-l lexer] [-o output]
  tartrazine -f html -t theme --css
  tartrazine FILE -f terminal [-t theme][-l lexer][-o output]
  tartrazine FILE -f json [-o output]
  tartrazine --list-themes
  tartrazine --list-lexers
  tartrazine --list-formatters
  tartrazine --version

Options:
  -f <formatter>      Format to use (html, terminal, json)
  -t <theme>          Theme to use, see --list-themes [default: default-dark]
  -l <lexer>          Lexer (language) to use, see --list-lexers [default: autodetect]
  -o <output>         Output file. Default is stdout.
  --standalone        Generate a standalone HTML file, which includes
                      all style information. If not given, it will generate just
                      a HTML fragment ready to include in your own page.
  --css               Generate a CSS file for the theme called <theme>.css
  --line-numbers      Include line numbers in the output
  -h, --help          Show this screen
  -v, --version       Show version number
HELP

options = Docopt.docopt(HELP, ARGV)

# Handle version manually
if options["--version"]
  puts "tartrazine #{Tartrazine::VERSION}"
  exit 0
end

if options["--list-themes"]
  puts Tartrazine.themes.join("\n")
  exit 0
end

if options["--list-lexers"]
  puts Tartrazine.lexers.join("\n")
  exit 0
end

if options["--list-formatters"]
  puts "html\njson\nterminal"
  exit 0
end

if options["-f"]
  formatter = options["-f"].as(String)
  case formatter
  when "html"
    formatter = Tartrazine::Html.new
    formatter.standalone = options["--standalone"] != nil
    formatter.line_numbers = options["--line-numbers"] != nil
  when "terminal"
    formatter = Tartrazine::Ansi.new
  when "json"
    formatter = Tartrazine::Json.new
  else
    puts "Invalid formatter: #{formatter}"
    exit 1
  end

  theme = Tartrazine.theme(options["-t"].as(String))

  if formatter.is_a?(Tartrazine::Html) && options["--css"]
    File.open("#{options["-t"].as(String)}.css", "w") do |outf|
      outf.puts formatter.get_style_defs(theme)
    end
    exit 0
  end

  lexer = Tartrazine.lexer(name: options["-l"].as(String), filename: options["FILE"].as(String))

  input = File.open(options["FILE"].as(String)).gets_to_end
  output = formatter.format(input, lexer, theme)

  if options["-o"].nil?
    puts output
  else
    File.open(options["-o"].as(String), "w") do |outf|
      outf.puts output
    end
  end
end
