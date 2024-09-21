require "docopt"
require "./tartrazine"

HELP = <<-HELP
tartrazine: a syntax highlighting tool

You can use the CLI to generate HTML, terminal, JSON or SVG output
from a source file using different themes.
Keep in mind that not all formatters support all features.

Usage:
  tartrazine (-h, --help)
  tartrazine FILE -f html [-t theme][--standalone][--line-numbers]
                          [-l lexer][-o output]
  tartrazine -f html -t theme --css
  tartrazine FILE -f terminal [-t theme][-l lexer][--line-numbers]
                              [-o output]
  tartrazine FILE -f svg  [-t theme][--standalone][--line-numbers]
                          [-l lexer][-o output]
  tartrazine FILE -f png  [-t theme][--line-numbers]
                          [-l lexer][-o output]
  tartrazine FILE -f json [-o output]
  tartrazine --list-themes
  tartrazine --list-lexers
  tartrazine --list-formatters
  tartrazine --version

Options:
  -f <formatter>      Format to use (html, terminal, json, svg)
  -t <theme>          Theme to use, see --list-themes [default: default-dark]
  -l <lexer>          Lexer (language) to use, see --list-lexers. Use more than
                      one lexer with "+" (e.g. jinja+yaml) [default: autodetect]
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

theme = Tartrazine.theme(options["-t"].as(String))

if options["-f"]
  formatter = options["-f"].as(String)
  case formatter
  when "html"
    formatter = Tartrazine::Html.new
    formatter.standalone = options["--standalone"] != nil
    formatter.line_numbers = options["--line-numbers"] != nil
    formatter.theme = theme
  when "terminal"
    formatter = Tartrazine::Ansi.new
    formatter.line_numbers = options["--line-numbers"] != nil
    formatter.theme = theme
  when "json"
    formatter = Tartrazine::Json.new
  when "svg"
    formatter = Tartrazine::Svg.new
    formatter.standalone = options["--standalone"] != nil
    formatter.line_numbers = options["--line-numbers"] != nil
    formatter.theme = theme
  when "png"
    formatter = Tartrazine::Png.new
    formatter.line_numbers = options["--line-numbers"] != nil
    formatter.theme = theme
  else
    puts "Invalid formatter: #{formatter}"
    exit 1
  end

  if formatter.is_a?(Tartrazine::Html) && options["--css"]
    File.open("#{options["-t"].as(String)}.css", "w") do |outf|
      outf << formatter.style_defs
    end
    exit 0
  end

  lexer = Tartrazine.lexer(name: options["-l"].as(String), filename: options["FILE"].as(String))

  input = File.open(options["FILE"].as(String)).gets_to_end

  if options["-o"].nil?
    outf = STDOUT
  else
    outf = File.open(options["-o"].as(String), "w")
  end
  formatter.format(input, lexer, outf)
  outf.close
end
