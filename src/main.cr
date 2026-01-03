require "docopt"
require "./tartrazine"

HELP = <<-HELP
tartrazine: a syntax highlighting tool

You can use the CLI to generate HTML, terminal, JSON, SVG, PNG, JPEG or WebP output
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
                          [-l lexer][-o output][--font-path path][--font-size size][--width w][--height h][--light|--dark]
  tartrazine FILE -f jpeg [-t theme][--line-numbers]
                          [-l lexer][-o output][--font-path path][--font-size size][--width w][--height h][--quality q][--light|--dark]
  tartrazine FILE -f webp [-t theme][--line-numbers]
                          [-l lexer][-o output][--font-path path][--font-size size][--width w][--height h][--quality q][--light|--dark]
  tartrazine FILE -f json [-o output]
  tartrazine FILE -f highlights [-t theme][--standalone [--template file]]
                              [--line-numbers][-l lexer][-o output][--light|--dark]
  tartrazine -f highlights -t theme --css
  tartrazine --list-themes [--show-variants]
  tartrazine --list-variant-themes
  tartrazine --list-lexers
  tartrazine --list-extensions <lexer>
  tartrazine --list-formatters
  tartrazine --version

Options:
  -f <formatter>      Format to use (html, terminal, json, svg, png, jpeg, webp, highlights)
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
  --font-path <path>  Path to TrueType/OpenType font file (.ttf or .otf) for image output
                      (default: bundled JetBrains Mono)
  --font-size <size>  Font point size for image output (e.g. 14) [default: 14]
  --width <w>         Maximum image width in pixels (0 = auto based on content) [default: 0]
  --height <h>        Maximum image height in pixels (0 = auto based on content) [default: 0]
  --quality <q>       JPEG/WebP quality (1-100, default: 90)
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
  puts "html\njson\nterminal\nsvg\npng\njpeg\nwebp\nhighlights"
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

if options["--list-variant-themes"]
  # List only themes that have light/dark variants
  themes = Tartrazine.themes_with_variants_only
  themes.each do |theme|
    variant_info = [] of String
    variant_info << "[L]" if theme[:has_light]
    variant_info << "[D]" if theme[:has_dark]

    if variant_info.empty?
      puts theme[:name]
    else
      puts "#{theme[:name]} #{variant_info.join(" ")}"
    end
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

theme = Tartrazine.theme(options["-t"].try(&.to_s) || "default-dark", theme_variant)
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
  when "png", "jpeg", "webp"
    font_path = options["--font-path"]?.try &.as(String)
    font_size = options["--font-size"]?.try &.as(String)
    width = options["--width"]?.try &.as(String)
    height = options["--height"]?.try &.as(String)
    quality = options["--quality"]?.try &.as(String)

    # Parse font size (single point size value)
    parsed_font_size = 14 # default
    if font_size
      begin
        parsed_font_size = font_size.to_i
      rescue ex
        puts "Invalid font size: #{font_size}. Must be a number (e.g., 14)"
        exit 1
      end
    end

    # Parse width
    parsed_max_width = 0 # 0 means auto
    if width
      begin
        parsed_max_width = width.to_i
        if parsed_max_width < 0
          puts "Width must be >= 0 (0 = auto)"
          exit 1
        end
      rescue ex
        puts "Invalid width: #{width}. Must be a number (e.g., 800)"
        exit 1
      end
    end

    # Parse height
    parsed_max_height = 0 # 0 means auto
    if height
      begin
        parsed_max_height = height.to_i
        if parsed_max_height < 0
          puts "Height must be >= 0 (0 = auto)"
          exit 1
        end
      rescue ex
        puts "Invalid height: #{height}. Must be a number (e.g., 600)"
        exit 1
      end
    end

    # Parse quality (for JPEG/WebP)
    parsed_quality = 90 # default
    if quality
      begin
        parsed_quality = quality.to_i
        if parsed_quality < 1 || parsed_quality > 100
          puts "Quality must be between 1 and 100"
          exit 1
        end
      rescue ex
        puts "Invalid quality: #{quality}. Must be a number between 1 and 100"
        exit 1
      end
    end

    # Create the appropriate formatter
    begin
      case formatter_name
      when "png"
        formatter = Tartrazine::Png.new(
          theme: theme,
          line_numbers: options["--line-numbers"] != nil,
          font_path: font_path,
          font_size: parsed_font_size,
          max_width: parsed_max_width,
          max_height: parsed_max_height
        )
      when "jpeg"
        formatter = Tartrazine::Jpeg.new(
          theme: theme,
          line_numbers: options["--line-numbers"] != nil,
          font_path: font_path,
          font_size: parsed_font_size,
          max_width: parsed_max_width,
          max_height: parsed_max_height,
          quality: parsed_quality
        )
      when "webp"
        formatter = Tartrazine::Webp.new(
          theme: theme,
          line_numbers: options["--line-numbers"] != nil,
          font_path: font_path,
          font_size: parsed_font_size,
          max_width: parsed_max_width,
          max_height: parsed_max_height,
          quality: parsed_quality
        )
      end
    rescue ex
      puts "Error creating #{formatter_name.upcase} formatter: #{ex.message}"
      puts "Note: --font-path is optional for image output (uses bundled JetBrains Mono by default)"
      puts "      You can specify a custom font with --font-path pointing to a .ttf or .otf file"
      exit 1
    end
  when "highlights"
    formatter = Tartrazine::Highlights.new
    formatter.standalone = options["--standalone"] != nil
    formatter.line_numbers = options["--line-numbers"] != nil
    formatter.theme = theme
    formatter.template = template if template
  else
    puts "Invalid formatter: #{formatter_name}"
    puts "Available formatters: html, json, terminal, svg, png, jpeg, webp, highlights"
    exit 1
  end

  if (formatter.is_a?(Tartrazine::Html) || formatter.is_a?(Tartrazine::Highlights)) && options["--css"]
    File.open("#{options["-t"].try(&.to_s) || "default-dark"}.css", "w") do |outf|
      outf << formatter.style_defs
    end
    exit 0
  end

  lexer = Tartrazine.lexer(name: options["-l"].try(&.to_s), filename: options["FILE"].to_s)

  input = File.open(options["FILE"].as(String)).gets_to_end

  if options["-o"].nil?
    outf = STDOUT
  else
    outf = File.open(options["-o"].as(String), "w")
  end
  formatter.format(input, lexer, outf)
  outf.close
end
