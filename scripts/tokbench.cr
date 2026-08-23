require "../src/tartrazine"

sample_path = ARGV[0]? || "/usr/lib/python3.14/typing.py"
lexer_name = ARGV[1]? || "python"
iterations = (ARGV[2]? || 50).to_i

sample = File.read(sample_path)
lexer = Tartrazine.lexer(lexer_name)

10.times { lexer.tokenizer(sample).to_a }
token_count = lexer.tokenizer(sample).to_a.size

t = Time.instant
iterations.times { lexer.tokenizer(sample).to_a }
elapsed = Time.instant - t
ms = elapsed.total_milliseconds / iterations
puts "tokenize #{lexer_name}: #{ms.round(3)} ms/run #{sample.bytesize / 1024} KB #{token_count} tokens #{(sample.bytesize / 1024 / ms).round(1)} MB/s"

html = Tartrazine::Html.new(theme: Tartrazine.theme("monokai"))
html.format(sample, lexer)
t = Time.instant
iterations.times { html.format(sample, lexer) }
elapsed = Time.instant - t
puts "format html:      #{(elapsed.total_milliseconds / iterations).round(3)} ms/run"
