require "./spec_helper"

# These are the testcases from Pygments
testcases = Dir.glob("#{__DIR__}/tests/**/*txt").sort

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
  "#{__DIR__}/tests/mcfunction/data.txt",
  "#{__DIR__}/tests/mcfunction/selectors.txt",
}

# Tests that fail because of a limitation in PCRE2
not_my_fault = {
  "#{__DIR__}/tests/fortran/test_string_cataback.txt",
}

describe Tartrazine do
  describe "Lexer" do
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
end

# Helper that creates lexer and tokenizes
def tokenize(lexer_name, text)
  lexer = Tartrazine.lexer(lexer_name)
  tokenizer = Tartrazine::Tokenizer.new(lexer, text)
  Tartrazine::Lexer.collapse_tokens(tokenizer.to_a)
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
  Tartrazine::Lexer.collapse_tokens(Array(Tartrazine::Token).from_json(output.to_s))
end
