require "docopt"
require "./tartrazine"

HELP = <<-HELP
tartrazine: a syntax highlighting tool

You can use the CLI to generate HTML, terminal, JSON or SVG output
from a source file using different themes.
Keep in mind that not all formatters support all features.

Usage:
  tartrazine (-h, --help)
  tartrazine FILE -f html [-t theme][--standalone [--template file]]
                          [--line-numbers][-l lexer][-o output][--light|--dark]
  tartrazine -f html -t theme --css
  tartrazine FILE -f terminal [-t theme][-l lexer][--line-numbers]
                              [-o output][--light|--dark]
  tartrazine FILE -f svg  [-t theme][--standalone][--line-numbers]
                          [-l lexer][-o output][--light|--dark]
  tartrazine FILE -f png  [-t theme][--line-numbers]
                          [-l lexer][-o output][--font-path path][--font-size size][--light|--dark]
  tartrazine FILE -f json [-o output]
  tartrazine FILE -f highlights [-t theme][--standalone [--template file]]
                              [--line-numbers][-l lexer][-o output][--light|--dark]
  tartrazine -f highlights -t theme --css
  tartrazine --list-themes [--show-variants]
  tartrazine --list-lexers
  tartrazine --list-extensions <lexer>
  tartrazine --list-formatters
  tartrazine --version

Options:
  -f <formatter>      Format to use (html, terminal, json, svg, highlights)
  -t <theme>          Theme to use, see --list-themes [default: default-dark]
  --light             Force light variant of the theme (if available)
  --dark              Force dark variant of the theme (if available)
  -l <lexer>          Lexer (language) to use, see --list-lexers. Use more than
                      one lexer with "+" (e.g. jinja+yaml) [default: autodetect]
  -o <output>         Output file. Default is stdout.
  --standalone        Generate a standalone HTML file, which includes
                      all style information. If not given, it will generate just
                      a HTML fragment ready to include in your own page.
  --css               Generate a CSS file for the theme called <theme>.css
                      (works with html and highlights formatters)
  --template <file>   Use a custom template for the HTML output [default: none]
  --line-numbers      Include line numbers in the output
  --font-path <path>  Path to custom font file or directory for PNG output
  --font-size <size>  Font size for PNG output (width,height, e.g. 20,32)
  --list-extensions <lexer>  List file extensions for a lexer
  --show-variants    Show theme variant information in theme list
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
  if options["--show-variants"]
    # Show themes with variant information
    Tartrazine.themes_with_variants.each do |theme|
      variant_info = [] of String
      variant_info << "[L]" if theme[:has_light]
      variant_info << "[D]" if theme[:has_dark]
      variant_info << "light" if theme[:is_light]
      variant_info << "dark" if theme[:is_dark]

      if variant_info.empty?
        puts theme[:name]
      else
        puts "#{theme[:name]} #{variant_info.join(" ")}"
      end
    end
  else
    puts Tartrazine.themes.join("\n")
  end
  exit 0
end

if options["--list-lexers"]
  puts Tartrazine.lexers.join("\n")
  exit 0
end

if options["--list-formatters"]
  puts "html\njson\nterminal\nsvg\npng\nhighlights"
  exit 0
end

if options["--list-extensions"]
  lexer_name = options["--list-extensions"].as(String)
  begin
    extensions = Tartrazine.lexer_extensions(lexer_name)
    puts extensions.join(", ")
  rescue ex
    puts "Error: #{ex.message}"
    exit 1
  end
  exit 0
end

# Handle theme variant preferences
theme_variant = nil
if options["--light"]
  theme_variant = "light"
elsif options["--dark"]
  theme_variant = "dark"
end

theme = Tartrazine.theme(options["-t"].as(String), theme_variant)
template = options["--template"]?
if template && template != "none" # Otherwise we will use the default template
  template = File.open(template.as(String)).gets_to_end
else
  template = nil
end

if options["-f"]
  formatter_name = options["-f"].as(String)
  formatter = uninitialized Tartrazine::Formatter
  case formatter_name
  when "html"
    formatter = Tartrazine::Html.new
    formatter.standalone = options["--standalone"] != nil
    formatter.line_numbers = options["--line-numbers"] != nil
    formatter.theme = theme
    formatter.template = template if template
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
    font_path = options["--font-path"]?.try &.as(String)
    font_size = options["--font-size"]?.try &.as(String)
    if font_size
      size_parts = font_size.split(",")
      if size_parts.size != 2
        puts "Font size must be in format: width,height (e.g. 20,32)"
        exit 1
      end
      begin
        font_width = size_parts[0].to_i
        font_height = size_parts[1].to_i
        formatter = Tartrazine::Png.new(theme: theme, line_numbers: options["--line-numbers"] != nil, font_path: font_path, font_width: font_width, font_height: font_height)
      rescue ex
        puts "Invalid font size: #{ex.message}"
        exit 1
      end
    else
      begin
        formatter = Tartrazine::Png.new(theme: theme, line_numbers: options["--line-numbers"] != nil, font_path: font_path)
      rescue ex
        puts "Warning: Failed to load custom font: #{ex.message}"
        puts "Falling back to default font."
        formatter = Tartrazine::Png.new(theme: theme, line_numbers: options["--line-numbers"] != nil)
      end
    end
  when "highlights"
    formatter = Tartrazine::Highlights.new
    formatter.standalone = options["--standalone"] != nil
    formatter.line_numbers = options["--line-numbers"] != nil
    formatter.theme = theme
    formatter.template = template if template
  else
    puts "Invalid formatter: #{formatter_name}"
    puts "Available formatters: html, json, terminal, svg, png, highlights"
    exit 1
  end

  if (formatter.is_a?(Tartrazine::Html) || formatter.is_a?(Tartrazine::Highlights)) && options["--css"]
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
