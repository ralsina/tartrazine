module BytesRegex
  extend self

  class Regex
    def initialize(pattern : String, multiline = false, dotall = false, ignorecase = false, anchored = false)
      flags = LibPCRE2::UTF | LibPCRE2::DUPNAMES | LibPCRE2::UCP | LibPCRE2::NO_UTF_CHECK
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
    end

    def finalize
      LibPCRE2.match_data_free(@match_data)
      LibPCRE2.code_free(@re)
    end

    def match(str : Bytes, pos = 0) : Array(Match)
      match = [] of Match
      rc = LibPCRE2.match(
        @re,
        str,
        str.size,
        pos,
        LibPCRE2::NO_UTF_CHECK,
        @match_data,
        nil)
      if rc < 0
        # No match, do nothing
      else
        ovector = LibPCRE2.get_ovector_pointer(@match_data)
        (0...rc).each do |i|
          m_start = ovector[2 * i]
          m_size = ovector[2 * i + 1] - m_start
          if m_size == 0
            m_value = Bytes.new(0)
          else
            m_value = str[m_start...m_start + m_size]
          end
          match << Match.new(m_value, m_start, m_size)
        end
      end
      match
    end
  end

  class Match
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
