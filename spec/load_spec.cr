require "./spec_helper"

# Every lexer name reported by Tartrazine.lexers must actually load.
# This is the guard for the list staying honest: if a lexer starts
# failing (or a broken one gets fixed), the BROKEN_LEXERS list in
# src/lexer.cr must be updated in the same commit.
describe "every listed lexer loads" do
  Tartrazine.lexers.each do |name|
    it "loads #{name}" do
      Tartrazine.lexer(name).should_not be_nil
    end
  end
end

describe "known-broken lexers" do
  it "matches exactly the set that fails to load" do
    actually_broken = Tartrazine.lexers_with_broken.select do |name|
      Tartrazine.lexer(name)
      false
    rescue
      true
    end
    unless actually_broken.sort! == Tartrazine::BROKEN_LEXERS.sort
      fail "BROKEN_LEXERS is out of date: a lexer was fixed or newly broken"
    end
  end
end
