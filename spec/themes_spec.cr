require "./spec_helper"

# Every theme name reported by Tartrazine.themes must load and be
# usable by a formatter (style resolution falls back to Background,
# which not every bundled XML theme defines)
describe "every listed theme loads" do
  lexer = Tartrazine.lexer("ruby")
  Tartrazine.themes.each do |name|
    it "loads and formats with #{name}" do
      theme = Tartrazine.theme(name)
      html = Tartrazine::Html.new(theme: theme).format("puts 1\n", lexer)
      html.should contain("puts")
    end
  end
end
