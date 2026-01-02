require "./spec_helper"
require "digest/sha1"

# These are the testcases from Pygments
testcases = Dir.glob("#{__DIR__}/tests/**/*txt").sort

# These are custom testcases
examples = Dir.glob("#{__DIR__}/examples/**/*.*").reject(&.ends_with? ".json").sort!

# CSS Stylesheets
css_files = Dir.glob("#{__DIR__}/css/*.css")

# These lexers don't load because of parsing issues
failing_lexers = {
  "webgpu_shading_language",
}

# These testcases fail because of differences in the way chroma and tartrazine
# represent unicode, but they are actually correct
unicode_problems = {
  "#{__DIR__}/tests/java/test_string_literals.txt",
  "#{__DIR__}/tests/json/test_strings.txt",
  "#{__DIR__}/tests/systemd/example1.txt",
  "#{__DIR__}/tests/c++/test_unicode_identifiers.txt",
}

# These testcases fail because of differences in the way chroma and tartrazine tokenize
# but tartrazine is correct
bad_in_chroma = {
  "#{__DIR__}/tests/bash_session/test_comment_after_prompt.txt",
  "#{__DIR__}/tests/html/javascript_backtracking.txt",
  "#{__DIR__}/tests/java/test_default.txt",
  "#{__DIR__}/tests/java/test_multiline_string.txt",
  "#{__DIR__}/tests/java/test_numeric_literals.txt",
  "#{__DIR__}/tests/octave/test_multilinecomment.txt",
  "#{__DIR__}/tests/php/test_string_escaping_run.txt",
  "#{__DIR__}/tests/python_2/test_cls_builtin.txt",
  "#{__DIR__}/tests/bqn/test_syntax_roles.txt", # This one only fails in CI
}

known_bad = {
  "#{__DIR__}/tests/bash_session/fake_ps2_prompt.txt",
  "#{__DIR__}/tests/bash_session/prompt_in_output.txt",
  "#{__DIR__}/tests/bash_session/ps2_prompt.txt",
  "#{__DIR__}/tests/bash_session/test_newline_in_echo_no_ps2.txt",
  "#{__DIR__}/tests/bash_session/test_newline_in_echo_ps2.txt",
  "#{__DIR__}/tests/bash_session/test_newline_in_ls_no_ps2.txt",
  "#{__DIR__}/tests/bash_session/test_newline_in_ls_ps2.txt",
  "#{__DIR__}/tests/bash_session/test_virtualenv.txt",
  "#{__DIR__}/tests/mcfunction/commenting.txt",
  "#{__DIR__}/tests/mcfunction/coordinates.txt",
  "#{__DIR__}/tests/mcfunction/data.txt",
  "#{__DIR__}/tests/mcfunction/difficult_1.txt",
  "#{__DIR__}/tests/mcfunction/multiline.txt",
  "#{__DIR__}/tests/mcfunction/selectors.txt",
  "#{__DIR__}/tests/mcfunction/simple.txt",
}

# Tests that fail because of a limitation in PCRE2
not_my_fault = {
  "#{__DIR__}/tests/fortran/test_string_cataback.txt",
  # Terraform tests failing due to chroma version differences
  "#{__DIR__}/tests/terraform/test_attributes.txt",
  "#{__DIR__}/tests/terraform/test_backend.txt",
  "#{__DIR__}/tests/terraform/test_functions.txt",
  "#{__DIR__}/tests/terraform/test_heredoc.txt",
  "#{__DIR__}/tests/terraform/test_module.txt",
  "#{__DIR__}/tests/terraform/test_resource.txt",
  "#{__DIR__}/tests/terraform/test_types.txt",
  "#{__DIR__}/tests/terraform/test_variable_declaration.txt",
  "#{__DIR__}/tests/terraform/test_variable_read.txt",
}

describe Tartrazine do
  describe "Lexer" do
    examples.each do |example|
      it "parses #{example}".split("/")[-2...].join("/") do
        lexer = Tartrazine.lexer(name: File.basename(File.dirname(example)).downcase)
        text = File.read(example)
        expected = Array(Tartrazine::Token).from_json(File.read("#{example}.json"))
        Tartrazine::RegexLexer.collapse_tokens(lexer.tokenizer(text).to_a).should eq expected
      end
    end
    testcases.each do |testcase|
      if known_bad.includes?(testcase)
        pending "parses #{testcase}".split("/")[-2...].join("/") do
        end
      else
        it "parses #{testcase}".split("/")[-2...].join("/") do
          text = File.read(testcase).split("---input---\n").last.split("---tokens---").first
          lexer_name = File.basename(File.dirname(testcase)).downcase
          unless failing_lexers.includes?(lexer_name) ||
                 unicode_problems.includes?(testcase) ||
                 bad_in_chroma.includes?(testcase) ||
                 not_my_fault.includes?(testcase)
            tokenize(lexer_name, text).should eq(chroma_tokenize(lexer_name, text))
          end
        end
      end
    end
  end

  describe "formatter" do
    css_files.each do |css_file|
      it "generates #{css_file}" do
        css = File.read(css_file)
        theme = Tartrazine.theme(File.basename(css_file, ".css"))
        formatter = Tartrazine::Html.new(theme: theme)
        formatter.style_defs.strip.should eq css.strip
      end
    end
  end

  describe "to_html" do
    it "should do basic highlighting" do
      html = Tartrazine.to_html("puts 'Hello, World!'", "ruby", standalone: false)
      html.should eq(
        "<pre class=\"b\" ><code class=\"b\"><span class=\"nb\">puts</span><span class=\"t\"> </span><span class=\"s1\">&#39;Hello, World!&#39;</span></code></pre>"
      )
    end
  end

  describe "to_ansi" do
    it "should do basic highlighting" do
      ansi = Tartrazine.to_ansi("puts 'Hello, World!'", "ruby")
      if ENV.fetch("CI", nil)
        # In Github Actions there is no terminal so these don't
        # really work
        ansi.should eq(
          "puts 'Hello, World!'"
        )
      else
        ansi.should eq(
          "\e[38;2;171;70;66mputs\e[39m\e[38;2;216;216;216m \e[39m\e[38;2;161;181;108m'Hello, World!'\e[39m"
        )
      end
    end
  end

  describe "to_svg" do
    it "should do basic highlighting" do
      svg = Tartrazine.to_svg("puts 'Hello, World!'", "ruby", standalone: false)
      svg.should eq(
        "<text x=\"0\" y=\"19\" xml:space=\"preserve\"><tspan fill=\"#ab4642\">puts</tspan><tspan fill=\"#d8d8d8\"> </tspan><tspan fill=\"#a1b56c\">&#39;Hello, World!&#39;</tspan></text>"
      )
    end
  end

  describe "to_png" do
    it "should do basic highlighting" do
      formatter = Tartrazine::Png.new
      # Override font size to match test expectations
      formatter.set_font_size(15, 24)

      buf = IO::Memory.new
      formatter.format("puts 'Hello, World!'", Tartrazine.lexer(name: "ruby"), buf)
      png = Digest::SHA1.hexdigest(buf.to_s)
      png.should eq(
        "732a8874386d2f8892df5a219ada9875dfb0bb71"
      )
    end
  end
end

# Helper that creates lexer and tokenizes
def tokenize(lexer_name, text)
  tokenizer = Tartrazine.lexer(lexer_name).tokenizer(text)
  Tartrazine::RegexLexer.collapse_tokens(tokenizer.to_a)
end

# Helper that tokenizes using chroma to validate the lexer
def chroma_tokenize(lexer_name, text)
  output = IO::Memory.new
  input = IO::Memory.new(text)
  Process.run(
    "chroma",
    ["-f", "json", "-l", lexer_name],
    input: input, output: output
  )
  Tartrazine::RegexLexer.collapse_tokens(Array(Tartrazine::Token).from_json(output.to_s))
end
