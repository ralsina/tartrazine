require "./cre2/cre2"
require "./actions"

# These are lexer rules. They match with the text being parsed
# and perform actions, either emitting tokens or changing the
# state of the lexer.
module Tartrazine
  # This rule matches via a regex pattern

  class Rule
    property pattern : Re3 = Re3.new ""
    property actions : Array(Action) = [] of Action
    property xml : String = "foo"

    def match(text, pos, lexer) : Tuple(Bool, Int32, Array(Token))
      matched, matches = pattern.match(text, pos)
      # We don't match if the match doesn't move the cursor
      # because that causes infinite loops

      return false, pos, [] of Token unless matched
      # Log.trace { "#{match}, #{pattern.inspect}, #{text}, #{pos}" }
      tokens = [] of Token
      # Emit the tokens
      actions.each do |action|
        # Emit the token
        tokens += action.emit(matches, lexer)
      end
      # Log.trace { "#{xml}, #{match.end}, #{tokens}" }
      return true, matches[0].length, tokens
    end

    def initialize(node : XML::Node, multiline, dotall, ignorecase)
      @xml = node.to_s
      @pattern = Re3.new(
        node["pattern"],
        multiline,
        dotall,
        ignorecase,
        anchored: true)
      add_actions(node)
    end

    def add_actions(node : XML::Node)
      node.children.each do |child|
        next unless child.element?
        @actions << Action.new(child.name, child)
      end
    end
  end

  # This rule includes another state. If any of the rules of the
  # included state matches, this rule matches.
  class IncludeStateRule < Rule
    property state : String = ""

    def match(text, pos, lexer) : Tuple(Bool, Int32, Array(Token))
      Log.trace { "Including state #{state} from #{lexer.state_stack.last}" }
      lexer.states[state].rules.each do |rule|
        matched, new_pos, new_tokens = rule.match(text, pos, lexer)
        Log.trace { "#{xml}, #{new_pos}, #{new_tokens}" } if matched
        return true, new_pos, new_tokens if matched
      end
      return false, pos, [] of Token
    end

    def initialize(node : XML::Node)
      @xml = node.to_s
      include_node = node.children.find { |child|
        child.name == "include"
      }
      @state = include_node["state"] if include_node
      add_actions(node)
    end
  end

  # This rule always matches, unconditionally
  class UnconditionalRule < Rule
    def match(text, pos, lexer) : Tuple(Bool, Int32, Array(Token))
      tokens = [] of Token
      actions.each do |action|
        tokens += action.emit(Pointer(LibCre2::StringPiece).malloc(1), lexer)
      end
      return true, pos, tokens
    end

    def initialize(node : XML::Node)
      @xml = node.to_s
      add_actions(node)
    end
  end

  # This is a hack to workaround that Crystal seems to disallow
  # having regexes multiline but not dot_all
  class Re2 < Regex
    @source = "fa"
    @options = Regex::Options::None
    @jit = true

    def initialize(pattern : String, multiline = false, dotall = false, ignorecase = false, anchored = false)
      flags = LibPCRE2::UTF | LibPCRE2::DUPNAMES |
              LibPCRE2::UCP
      flags |= LibPCRE2::MULTILINE if multiline
      flags |= LibPCRE2::DOTALL if dotall
      flags |= LibPCRE2::CASELESS if ignorecase
      flags |= LibPCRE2::ANCHORED if anchored
      @re = Regex::PCRE2.compile(pattern, flags) do |error_message|
        raise Exception.new(error_message)
      end
    end
  end

  class Re3
    @matches = Pointer(LibCre2::StringPiece).malloc(50)
    @opts : LibCre2::Options

    @re : LibCre2::CRe2

    def group_count
      LibCre2.num_capturing_groups(@re)
    end

    def initialize(pattern : String, multiline = false, dotall = false,
                   ignorecase = false, anchored = false)
      @opts = LibCre2.opt_new
      LibCre2.opt_posix_syntax(@opts, false)
      LibCre2.opt_longest_match(@opts, false)
      # These 3 are ignored when posix_syntax is false
      # LibCre2.opt_one_line(@opts, !multiline)
      # LibCre2.opt_perl_classes(@opts, true)
      # LibCre2.opt_word_boundary(@opts, true)
      LibCre2.opt_encoding(@opts, 1)
      LibCre2.opt_case_sensitive(@opts, !ignorecase)
      LibCre2.opt_dot_nl(@opts, dotall)
      pattern = "(?m)#{pattern}" if multiline
      @re = LibCre2.new(pattern, pattern.size, @opts)
    end

    def match(text, pos)
      matched = LibCre2.match(@re, text, text.size, pos, text.size,
        LibCre2::CRE2_ANCHOR_START, @matches, 50)
      return {matched != 0, @matches}
    end
  end
end


# re2 doesn't support this (should match "x")
# re = Tartrazine::Re3.new("x(?!foo)", multiline: true, dotall: false)
# m = re.match("xfoo", 0)
# p m[0], m[1][0]

