@[Link(ldflags: "#{__DIR__}/cre2.o -Wl,--copy-dt-needed-entries `pkg-config --libs re2`")]
lib LibCre2
  type Options = Void*

  fun opt_new = cre2_opt_new : Options
  fun opt_delete = cre2_opt_delete(op : Options) : Nil

  fun opt_posix_syntax = cre2_opt_posix_syntax(op : Options, flag : Bool) : Nil
  fun opt_longest_match = cre2_opt_longest_match(op : Options, flag : Bool) : Nil
  fun opt_log_errors = cre2_opt_log_errors(op : Options, flag : Bool) : Nil
  fun opt_literal = cre2_opt_literal(op : Options, flag : Bool) : Nil
  fun opt_never_nl = cre2_opt_never_nl(op : Options, flag : Bool) : Nil
  fun opt_case_sensitive = cre2_opt_case_sensitive(op : Options, flag : Bool) : Nil
  fun opt_perl_classes = cre2_opt_perl_classes(op : Options, flag : Bool) : Nil
  fun opt_word_boundary = cre2_opt_word_boundary(op : Options, flag : Bool) : Nil
  fun opt_one_line = cre2_opt_one_line(op : Options, flag : Bool) : Nil
  fun opt_dot_nl = cre2_opt_dot_nl(op : Options, flag : Bool) : Nil
  fun opt_encoding = cre2_opt_encoding(op : Options, encoding : Int32) : Nil
  fun opt_max_mem = cre2_opt_max_mem(op : Options, flag : Bool) : Nil

  struct StringPiece
    data : LibC::Char*
    length : Int32
  end

  type CRe2 = Void*

  fun new = cre2_new(pattern : LibC::Char*, patternlen : UInt32, opt : Options) : CRe2
  fun del = cre2_delete(re : CRe2) : Nil
  fun error_code = cre2_error_core(re : CRe2) : Int32
  fun num_capturing_groups(re : CRe2) : Int32
  fun program_size(re : CRe2) : Int32

  # Invalidated by further re use
  fun error_string = cre2_error_string(re : CRe2) : LibC::Char*
  fun error_arg = cre2_error_arg(re : CRe2, arg : StringPiece*) : Nil

  CRE2_UNANCHORED   = 1
  CRE2_ANCHOR_START = 2
  CRE2_ANCHOR_BOTH  = 3

  fun match = cre2_match(
    re : CRe2,
    text : LibC::Char*,
    textlen : UInt32,
    startpos : UInt32,
    endpos : UInt32,
    anchor : Int32,
    match : StringPiece*,
    nmatch : Int32
  ) : Int32
end

# match = Pointer(LibCre2::StringPiece).malloc(10)
# opts = LibCre2.opt_new
# LibCre2.opt_posix_syntax(opts, true)
# LibCre2.opt_longest_match(opts, true)
# LibCre2.opt_perl_classes(opts, true)
# LibCre2.opt_encoding(opts, 1)
# # LibCre2.opt_one_line(opts, false)
# # LibCre2.opt_never_nl(opts, false)

# pattern = "(\\s+)(foo)"
# text = "  foo"
# re = LibCre2.new(pattern, pattern.size, opts)
# p! LibCre2.match(re, text, text.size, 0, text.size,
#   LibCre2::CRE2_ANCHOR_START, match, 10)
# (0...10).each do |i|
#   p! String.new(Slice.new(match[i].data, match[i].length))
# end
