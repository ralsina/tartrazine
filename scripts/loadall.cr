require "../src/tartrazine"

ok = 0
broken = [] of {String, String}
Tartrazine.lexers_with_broken.each do |name|
  Tartrazine.lexer(name)
  ok += 1
rescue ex
  broken << {name, ex.message.to_s[0..60]}
end
puts "load ok: #{ok}, broken: #{broken.size}"
broken.each { |name, msg| puts "  #{name}: #{msg}" }
