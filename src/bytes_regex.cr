lib LibPCRE2
  fun match_context_free = pcre2_match_context_free_8(mcontext : MatchContext*)
  fun jit_match = pcre2_jit_match_8(code : Code*, subject : UInt8*,
                                    length : LibC::SizeT, startoffset : LibC::SizeT, options : UInt32,
                                    match_data : MatchData*, mcontext : MatchContext*) : Int
end

module BytesRegex
  extend self

  # Whether Regex#match! may skip attempts whose first byte cannot
  # start a match. Only meant to be turned off by specs that check
  # the prefilter never changes tokenization.
  class_property? prefilter : Bool = true

  # The JIT stack and match data are unique per thread, mirroring how
  # Crystal's stdlib wraps PCRE2: a match call never yields, so nothing
  # else on the same thread can touch them while they are in use, and
  # other threads get their own. This makes concurrent tokenization of
  # a shared lexer safe (the same guarantee as ::Regex).
  thread_local(current_jit_stack : ::Crystal::ValueWithFinalizer(LibPCRE2::JITStack*)) do
    ptr = LibPCRE2.jit_stack_create(32_768, 1_048_576, nil)
    raise Exception.new("Error allocating JIT stack") if ptr.null?
    ::Crystal::ValueWithFinalizer.new(ptr, ->(value : LibPCRE2::JITStack*) { LibPCRE2.jit_stack_free(value) })
  end

  thread_local(current_match_context : ::Crystal::ValueWithFinalizer(LibPCRE2::MatchContext*)) do
    ptr = LibPCRE2.match_context_create(nil)
    raise Exception.new("Error allocating match context") if ptr.null?
    context = ::Crystal::ValueWithFinalizer.new(ptr, ->(value : LibPCRE2::MatchContext*) { LibPCRE2.match_context_free(value) })
    # The context is per-thread already: hand PCRE2 the stack pointer
    # directly instead of a callback it would invoke on every match
    LibPCRE2.jit_stack_assign(ptr, nil, BytesRegex.current_jit_stack.value.as(Void*))
    context
  end

  def self.match_context : LibPCRE2::MatchContext*
    current_match_context.value
  end

  thread_local(current_match_data : ::Crystal::ValueWithFinalizer(LibPCRE2::MatchData*)) do
    # Maximum ovector so one buffer adapts to every pattern, like the
    # stdlib does
    ptr = LibPCRE2.match_data_create(65_535, nil)
    raise Exception.new("Error allocating match data") if ptr.null?
    ::Crystal::ValueWithFinalizer.new(ptr, ->(value : LibPCRE2::MatchData*) { LibPCRE2.match_data_free(value) })
  end

  def self.match_data : LibPCRE2::MatchData*
    current_match_data.value
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
      @jit = LibPCRE2.jit_compile(@re, LibPCRE2::JIT_COMPLETE) == 0
      load_first_byte_info(pattern, flags, ignorecase == true)
    end

    # 256-bit set of bytes that can start a match, or nil when PCRE2
    # could not determine one. Kept as a heap Bytes on purpose: a
    # nilable StaticArray would be copied on every read in match!,
    # which costs more than the call it saves.
    @first : Bytes?

    # The pattern can only match at the start of a line or of the
    # subject (PCRE2 "first code type" 2)
    @line_start_only = false

    # Rules are matched ANCHORED at a position, so a rule whose
    # possible first bytes exclude text[pos] cannot match there and
    # the call into PCRE2 can be skipped: on typical source about
    # 80% of attempts fail this way. PCRE2 computes this information
    # at compile time but only when start-of-match optimizations are
    # enabled, and the real pattern needs NO_START_OPTIMIZE (see
    # above), so a throwaway copy is compiled just to read it.
    private def load_first_byte_info(pattern : String, flags : UInt32, ignorecase : Bool) : Nil
      # PCRE2 reports the first code unit of one case only for
      # caseless patterns, so those keep matching unconditionally
      return if ignorecase
      shadow = LibPCRE2.compile(pattern, pattern.bytesize, flags & ~LibPCRE2::NO_START_OPTIMIZE,
        out errorcode, out erroroffset, nil)
      return unless shadow
      begin
        first_type = 0_u32
        LibPCRE2.pattern_info(shadow, LibPCRE2::INFO_FIRSTCODETYPE, pointerof(first_type).as(Void*))
        case first_type
        when 1
          # A single fixed first code unit
          first_unit = 0_u32
          LibPCRE2.pattern_info(shadow, LibPCRE2::INFO_FIRSTCODEUNIT, pointerof(first_unit).as(Void*))
          set = Bytes.new(32, 0_u8)
          set[(first_unit & 0xff) >> 3] |= 1_u8 << (first_unit & 7)
          @first = set
        when 2
          @line_start_only = true
        else
          # Possibly a bitmap of first code units (nil when PCRE2 has
          # no information, eg. patterns that can match empty)
          bitmap = Pointer(UInt8).null
          LibPCRE2.pattern_info(shadow, LibPCRE2::INFO_FIRSTBITMAP, pointerof(bitmap).as(Void*))
          unless bitmap.null?
            set = Bytes.new(32, 0_u8)
            set.to_unsafe.copy_from(bitmap, 32)
            @first = set
          end
        end
      ensure
        LibPCRE2.code_free(shadow)
      end
    end

    # True when the first-byte information proves no match can start
    # at pos, so PCRE2 need not be called
    @[AlwaysInline]
    private def cannot_match_at?(text : Bytes, pos : Int32) : Bool
      return false unless BytesRegex.prefilter? && pos < text.size
      if set = @first
        byte = text.to_unsafe[pos]
        return (set.to_unsafe[byte >> 3] & (1_u8 << (byte & 7))) == 0
      end
      @line_start_only && pos > 0 && text.to_unsafe[pos - 1] != 10_u8
    end

    def finalize
      LibPCRE2.code_free(@re)
    end

    # Copy the offsets of all captured groups of the last match,
    # sanitizing non-participating groups (marked by PCRE2 with an
    # unset value) to -1. The snapshot stays valid even if this
    # regex is matched again (eg. by reentrant tokenization).
    # When `into` is given and large enough it is filled and
    # returned instead of allocating; the caller then needs the
    # group count (group_count * 2) since the slice may be larger.
    def snapshot_ovector(group_count : Int32, text_bytesize : Int32,
                         match_data : LibPCRE2::MatchData* = BytesRegex.match_data,
                         into : Slice(Int32)? = nil) : Slice(Int32)
      needed = group_count * 2
      ovector = LibPCRE2.get_ovector_pointer(match_data)
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
    def match!(text : Bytes, pos = 0, match_data : LibPCRE2::MatchData* = BytesRegex.match_data,
               context : LibPCRE2::MatchContext* = BytesRegex.match_context) : Int32
      return 0 if cannot_match_at?(text, pos)
      if @jit
        rc = LibPCRE2.jit_match(
          @re,
          text,
          text.size,
          pos,
          LibPCRE2::NO_UTF_CHECK,
          match_data,
          context)
        # Fall back to the interpreter on JIT runtime errors
        # (-1 is just "no match")
        if rc < -1
          rc = LibPCRE2.match(
            @re, text, text.size, pos,
            LibPCRE2::NO_UTF_CHECK, match_data, nil)
        end
      else
        rc = LibPCRE2.match(
          @re,
          text,
          text.size,
          pos,
          LibPCRE2::NO_UTF_CHECK,
          match_data,
          nil)
      end
      rc > 0 ? rc : 0
    end

    def match(str : Bytes, pos = 0) : Array(Match)
      rc = match!(str, pos)
      if rc > 0
        ovector = LibPCRE2.get_ovector_pointer(BytesRegex.match_data)
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
