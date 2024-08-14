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

  class Rule
    property pattern : Regex = Regex.new ""
    property actions : Array(Action) = [] of Action
    property xml : String = "foo"

    def match(text : Bytes, pos, lexer) : Tuple(Bool, Int32, Array(Token))
      match = pattern.match(text, pos)
      # We don't match if the match doesn't move the cursor
      # because that causes infinite loops
      return false, pos, [] of Token if match.empty? || match[0].size == 0
      # p! match, String.new(text[pos..pos+20])
      # Log.trace { "#{match}, #{pattern.inspect}, #{text}, #{pos}" }
      tokens = [] of Token
      # Emit the tokens
      actions.each do |action|
        # Emit the token
        tokens += action.emit(match, lexer)
      end
      Log.trace { "#{xml}, #{pos + match[0].size}, #{tokens}" }
      return true, pos + match[0].size, tokens
    end

    def initialize(node : XML::Node, multiline, dotall, ignorecase)
      @xml = node.to_s
      pattern = node["pattern"]
      # flags = Regex::Options::ANCHORED
      # MULTILINE implies DOTALL which we don't want, so we
      # use in-pattern flag (?m) instead
      # flags |= Regex::Options::MULTILINE if multiline
      pattern = "(?m)" + pattern if multiline
      # flags |= Regex::Options::DOTALL if dotall
      # flags |= Regex::Options::IGNORE_CASE if ignorecase
      @pattern = Regex.new(pattern, multiline, dotall, ignorecase, true)
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
        tokens += action.emit([] of Match, lexer)
      end
      return true, pos, tokens
    end

    def initialize(node : XML::Node)
      @xml = node.to_s
      add_actions(node)
    end
  end
end
