require "./actions"
require "./bytes_regex"
require "./formatter"
require "./lexer"
require "./rules"
require "./styles"

# These are lexer rules. They match with the text being parsed
# and perform actions, either emitting tokens or changing the
# state of the lexer.
module Tartrazine
  # This rule matches via a regex pattern

  alias Regex = BytesRegex::Regex
  alias Match = BytesRegex::Match
  alias MatchData = Array(Match)

  abstract struct BaseRule
    abstract def match(text : Bytes, pos, lexer) : Tuple(Bool, Int32, Array(Token))
    abstract def initialize(node : XML::Node)

    property actions : Array(Action) = [] of Action

    def add_actions(node : XML::Node)
      node.children.each do |child|
        next unless child.element?
        @actions << Action.new(child.name, child)
      end
    end
  end

  struct Rule < BaseRule
    property pattern : Regex = Regex.new ""
    property actions : Array(Action) = [] of Action

    def match(text : Bytes, pos, lexer) : Tuple(Bool, Int32, Array(Token))
      match = pattern.match(text, pos)

      # No match
      return false, pos, [] of Token if match.size == 0
      return true, pos + match[0].size, actions.flat_map(&.emit(match, lexer))
    end

    def initialize(node : XML::Node)
    end

    def initialize(node : XML::Node, multiline, dotall, ignorecase)
      pattern = node["pattern"]
      pattern = "(?m)" + pattern if multiline
      @pattern = Regex.new(pattern, multiline, dotall, ignorecase, true)
      add_actions(node)
    end
  end

  # This rule includes another state. If any of the rules of the
  # included state matches, this rule matches.
  struct IncludeStateRule < BaseRule
    property state : String = ""

    def match(text, pos, lexer) : Tuple(Bool, Int32, Array(Token))
      Log.trace { "Including state #{state} from #{lexer.state_stack.last}" }
      lexer.states[state].rules.each do |rule|
        matched, new_pos, new_tokens = rule.match(text, pos, lexer)
        return true, new_pos, new_tokens if matched
      end
      return false, pos, [] of Token
    end

    def initialize(node : XML::Node)
      include_node = node.children.find { |child|
        child.name == "include"
      }
      @state = include_node["state"] if include_node
      add_actions(node)
    end
  end

  # This rule always matches, unconditionally
  struct UnconditionalRule < BaseRule
    NO_MATCH = [] of Match

    def match(text, pos, lexer) : Tuple(Bool, Int32, Array(Token))
      return true, pos, actions.flat_map(&.emit(NO_MATCH, lexer))
    end

    def initialize(node : XML::Node)
      add_actions(node)
    end
  end
end
