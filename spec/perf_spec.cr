require "./spec_helper"

# Performance regression tests: catch accidental super-linear behavior
# like the quadratic array slicing removed after issue #27.
#
# These are not run by default because timings are machine-dependent.
# Run them with:
#
#   TT_PERF=1 crystal spec spec/perf_spec.cr
#
# Each formatter is benchmarked at two sizes (n and 4n lines). Linear
# formatting should take ~4x longer at 4n; the threshold is set
# generously above that so slow machines don't flake, while a quadratic
# regression (expected ~16x) fails reliably.

def sample_code(lines : Int32) : String
  (1..lines).map do |i|
    %(variable_#{i} = "value #{i * 3}" # comment number #{i}\n)
  end.join
end

def benchmark_formatter(name : String, code : String) : Float64
  lexer = Tartrazine.lexer("ruby")
  formatter = case name
              when "html" then Tartrazine::Html.new
              when "ansi" then Tartrazine::Ansi.new
              when "svg"  then Tartrazine::Svg.new
              when "json" then Tartrazine::Json.new
              else
                raise Exception.new("Unknown formatter: #{name}")
              end
  elapsed = 0_f64
  # Best of 3 runs to reduce noise from GC and scheduler
  3.times do
    outp = IO::Memory.new
    t0 = Time.monotonic
    formatter.format(code, lexer, outp)
    seconds = (Time.monotonic - t0).total_seconds
    elapsed = seconds if elapsed == 0 || seconds < elapsed
  end
  elapsed
end

describe "formatter performance" do
  line_count = ENV.fetch("TT_PERF_LINES", "4000").to_i
  scale_factor = 4

  ["html", "ansi", "svg", "json"].each do |formatter_name|
    {% if env("TT_PERF") %}
      it "scales linearly for #{formatter_name}" do
        small = sample_code(line_count)
        large = sample_code(line_count * scale_factor)

        small_time = benchmark_formatter(formatter_name, small)
        large_time = benchmark_formatter(formatter_name, large)

        ratio = large_time / small_time
        # Linear expectation: ~scale_factor. Allow up to 2.5x that for
        # noise; quadratic behavior lands near scale_factor^2.
        max_ratio = scale_factor * 2.5
        ratio.should be < max_ratio,
          "#{formatter_name}: #{scale_factor}x input took #{ratio.round(2)}x longer " \
          "(#{(small_time * 1000).round(2)}ms -> #{(large_time * 1000).round(2)}ms), " \
          "expected < #{max_ratio}x — this looks like super-linear behavior"
      end
    {% else %}
      pending "scales linearly for #{formatter_name} (set TT_PERF=1 to run)"
    {% end %}
  end
end
