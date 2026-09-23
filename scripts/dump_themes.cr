require "../src/tartrazine"

# Dump every theme x variant resolution for equivalence checking
def style_str(style : Tartrazine::Style) : String
  color = style.color.try &.hex.to_s || "-"
  background = style.background.try &.hex.to_s || "-"
  border = style.border.try &.hex.to_s || "-"
  "#{style.bold}/#{style.italic}/#{style.underline}/#{color}/#{background}/#{border}"
end

result = [] of String
Tartrazine.themes.each do |name|
  [nil, "light", "dark"].each do |variant|
    theme = Tartrazine.theme(name, variant)
    styles = theme.styles.keys.sort!.map { |k| "#{k}=#{style_str(theme.styles[k])}" }
    result << "#{name}|#{variant}|#{theme.name}|#{theme.base16?}|#{styles.join(";")}"
  rescue ex
    result << "#{name}|#{variant}|ERROR|#{ex.message}"
  end
end
puts result.join("\n")
