require "./spec_helper"

# The first-byte prefilter in BytesRegex::Regex#match! skips calling
# PCRE2 when the byte at the current position cannot start a match.
# It must never change tokenization: this runs the Pygments/Chroma
# test inputs for a few busy lexers with the prefilter on and off and
# asserts identical tokens.
describe "first-byte prefilter" do
  inputs = Dir.glob("#{__DIR__}/tests/{python,c,c++,html,bash,ruby,go,rust,javascript}/*.txt").sort

  it "has inputs to compare" do
    inputs.size.should be > 50
  end

  inputs.each do |path|
    lexer_name = File.basename(File.dirname(path)).downcase
    it "does not change tokens for #{lexer_name}/#{File.basename(path)}" do
      text = File.read(path).split("---input---\n").last.split("---tokens---").first
      lexer = Tartrazine.lexer(lexer_name)

      BytesRegex.prefilter = false
      unfiltered = lexer.tokenizer(text).to_a
      BytesRegex.prefilter = true
      filtered = lexer.tokenizer(text).to_a

      filtered.should eq unfiltered
    ensure
      BytesRegex.prefilter = true
    end
  end
end
