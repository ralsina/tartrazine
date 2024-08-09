require "./actions"
require "./constants"
require "./formatter"
require "./rules"
require "./styles"
require "./lexer"

# These are lexer rules. They match with the text being parsed
# and perform actions, either emitting tokens or changing the
# state of the lexer.
module Tartrazine
  # This rule matches via a regex pattern

  class Rule
    property pattern : Regex = Re2.new ""
    property actions : Array(Action) = [] of Action
    property xml : String = "foo"

    def match(text, pos, lexer) : Tuple(Bool, Int32, Array(Token))
      match = pattern.match(text, pos)
      # We don't match if the match doesn't move the cursor
      # because that causes infinite loops
      return false, pos, [] of Token if match.nil? || match.end == 0
      # Log.trace { "#{match}, #{pattern.inspect}, #{text}, #{pos}" }
      tokens = [] of Token
      # Emit the tokens
      actions.each do |action|
        # Emit the token
        tokens += action.emit(match, lexer)
      end
      Log.trace { "#{xml}, #{match.end}, #{tokens}" }
      return true, match.end, tokens
    end

    def initialize(node : XML::Node, multiline, dotall, ignorecase)
      @xml = node.to_s
      @pattern = Re2.new(
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
        tokens += action.emit(nil, lexer)
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
      flags |= LibPCRE2::NO_UTF_CHECK
      @re = Regex::PCRE2.compile(pattern, flags) do |error_message|
        raise Exception.new(error_message)
      end
    end
  end
end
