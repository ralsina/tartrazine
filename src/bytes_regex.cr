lib LibPCRE2
  fun jit_match = pcre2_jit_match_8(code : Code*, subject : UInt8*,
                                    length : LibC::SizeT, startoffset : LibC::SizeT, options : UInt32,
                                    match_data : MatchData*, mcontext : MatchContext*) : Int
end

module BytesRegex
  extend self

  # Shared JIT stack used by all regexes in this process
  @@jit_stack : LibPCRE2::JITStack*?

  def self.jit_stack : LibPCRE2::JITStack*
    @@jit_stack ||= LibPCRE2.jit_stack_create(32_768, 1_048_576, nil)
  end

  class Regex
    def initialize(pattern : String, multiline = false, dotall = false, ignorecase = false, anchored = false)
      # Chroma patterns are written for Go's regexp, which supports
      # \uXXXX unicode escapes; PCRE2 does not, but supports the
      # equivalent \x{XXXX}. Translating can only turn compile
      # failures into successes, since \u is not valid PCRE2 at all.
      pattern = pattern.gsub(/\\u([0-9a-fA-F]{4})/, "\\x{\\1}")
      # NO_START_OPTIMIZE: every rule is matched ANCHORED, so PCRE2's
      # start-of-match optimization (scanning forward for a required
      # literal) can never succeed; on inputs missing that literal it
      # scans to the JIT's cap on every failing attempt, which is
      # quadratic on repetitive input
      flags = LibPCRE2::UTF | LibPCRE2::UCP | LibPCRE2::NO_UTF_CHECK | LibPCRE2::NO_START_OPTIMIZE
      flags |= LibPCRE2::MULTILINE if multiline
      flags |= LibPCRE2::DOTALL if dotall
      flags |= LibPCRE2::CASELESS if ignorecase
      flags |= LibPCRE2::ANCHORED if anchored
      if @re = LibPCRE2.compile(
           pattern,
           pattern.bytesize,
           flags,
           out errorcode,
           out erroroffset,
           nil)
      else
        msg = String.new(256) do |buffer|
          bytesize = LibPCRE2.get_error_message(errorcode, buffer, 256)
          {bytesize, 0}
        end
        raise Exception.new "Error #{msg} compiling regex at offset #{erroroffset}"
      end
      @match_data = LibPCRE2.match_data_create_from_pattern(@re, nil)
      @last_rc = 0
      @jit = LibPCRE2.jit_compile(@re, LibPCRE2::JIT_COMPLETE) == 0
      @context = LibPCRE2.match_context_create(nil)
      if @context
        LibPCRE2.jit_stack_assign(@context, ->(_data : Void*) { BytesRegex.jit_stack }, nil)
      end
    end

    def finalize
      LibPCRE2.match_data_free(@match_data)
      LibPCRE2.code_free(@re)
    end

    # Number of captured groups of the last successful match
    def group_count : Int32
      @last_rc
    end

    # Copy the offsets of all captured groups of the last match,
    # sanitizing non-participating groups (marked by PCRE2 with an
    # unset value) to -1. The snapshot stays valid even if this
    # regex is matched again (eg. by reentrant tokenization).
    # When `into` is given and large enough it is filled and
    # returned instead of allocating; the caller then needs the
    # group count (group_count * 2) since the slice may be larger.
    def snapshot_ovector(text_bytesize : Int32, into : Slice(Int32)? = nil) : Slice(Int32)
      needed = @last_rc * 2
      ovector = LibPCRE2.get_ovector_pointer(@match_data)
      buffer = if into && into.size >= needed
                 into
               else
                 Slice(Int32).new(needed)
               end
      needed.times do |index|
        raw = ovector[index]
        buffer[index] = raw > text_bytesize ? -1 : raw.to_i32
      end
      buffer
    end

    # Run a match and return the number of captured groups,
    # or 0 if there was no match. Results stay available through
    # group_start/group_end until the next match on this Regex.
    def match!(text : Bytes, pos = 0) : Int32
      if @jit && @context
        rc = LibPCRE2.jit_match(
          @re,
          text,
          text.size,
          pos,
          LibPCRE2::NO_UTF_CHECK,
          @match_data,
          @context)
        # Fall back to the interpreter on JIT runtime errors
        # (-1 is just "no match")
        if rc < -1
          rc = LibPCRE2.match(
            @re, text, text.size, pos,
            LibPCRE2::NO_UTF_CHECK, @match_data, nil)
        end
      else
        rc = LibPCRE2.match(
          @re,
          text,
          text.size,
          pos,
          LibPCRE2::NO_UTF_CHECK,
          @match_data,
          nil)
      end
      @last_rc = rc > 0 ? rc : 0
    end

    def match(str : Bytes, pos = 0) : Array(Match)
      rc = match!(str, pos)
      if rc > 0
        ovector = LibPCRE2.get_ovector_pointer(@match_data)
        (0...rc).map do |i|
          m_start = ovector[2 * i]
          m_end = ovector[2 * i + 1]
          if m_start == m_end
            m_value = Bytes.new(0)
          else
            m_value = str[m_start...m_end]
          end
          Match.new(m_value, m_start, m_end - m_start)
        end
      else
        [] of Match
      end
    end
  end

  struct Match
    property value : Bytes
    property start : UInt64
    property size : UInt64

    def initialize(@value : Bytes, @start : UInt64, @size : UInt64)
    end
  end
end

# pattern = "foo"
# str = "foo bar"
# re = BytesRegex::Regex.new(pattern)
# p! String.new(re.match(str.to_slice)[0].value)
