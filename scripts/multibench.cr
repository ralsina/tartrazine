require "../src/tartrazine"

# Multi-lexer tokenize benchmark. Usage: multibench.cr [iterations]
iterations = (ARGV[0]? || 30).to_i

def synth(path : String, source : String, times : Int32) : String
  return path if File.exists?(path)
  Dir.mkdir_p(File.dirname(path))
  File.write(path, (File.read(source) * times))
  path
end

# Bigger synthesized inputs so small samples give stable timings
big_html = synth("/tmp/tt-multibench/big.html",
  "#{__DIR__}/../spec/tests/html/javascript_backtracking.txt", 200)
big_j2 = synth("/tmp/tt-multibench/big.j2",
  "#{__DIR__}/../spec/examples/jinja+python/funko.py.j2", 200)

samples = [
  {"/usr/lib/python3.14/typing.py", "python"},
  {"#{__DIR__}/../src/lexer.cr", "crystal"},
  {big_html, "html"},
  {big_j2, "jinja+python"},
  {"#{__DIR__}/../README.md", "markdown"},
]

samples.each do |path, name|
  sample = File.read(path)
  lexer = Tartrazine.lexer(name)
  lexer.tokenizer(sample).to_a # warm up (template parse, caches)
  3.times { lexer.tokenizer(sample).to_a }
  best = Float64::MAX
  tokens = 0
  iterations.times do
    t = Time.instant
    tokens = lexer.tokenizer(sample).to_a.size
    best = Math.min(best, (Time.instant - t).total_milliseconds)
  end
  puts "#{name.rjust(14)}: #{best.round(2)} ms #{sample.bytesize // 1024} KB #{tokens} tokens"
end
