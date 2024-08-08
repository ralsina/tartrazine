require "./actions"
# require "cre2"

# These are lexer rules. They match with the text being parsed
# and perform actions, either emitting tokens or changing the
# state of the lexer.
module Tartrazine
  # This rule matches via a regex pattern

  # alias Regex = CRe2::Regex
  # alias MatchData = CRe2::MatchDataLike | Regex::MatchData | Nil
  alias MatchData = Regex::MatchData | Nil

  class Rule
    property pattern : Regex = Regex.new ""
    property actions : Array(Action) = [] of Action
    property xml : String = "foo"

    def match(text, pos, lexer) : Tuple(Bool, Int32, Array(Token))
      match = pattern.match(text, pos)
      # We don't match if the match doesn't move the cursor
      # because that causes infinite loops

      return false, pos, [] of Token if match.nil?
      # Log.trace { "#{match}, #{pattern.inspect}, #{text}, #{pos}" }
      tokens = [] of Token
      # Emit the tokens
      actions.each do |action|
        # Emit the token
        tokens += action.emit(match, lexer)
      end
      # Log.trace { "#{xml}, #{match.end}, #{tokens}" }
      return true, match[0].size, tokens
    end

    def initialize(node : XML::Node, multiline, dotall, ignorecase)
      @xml = node.to_s
      options = Regex::Options::ANCHORED
      options |= Regex::Options::MULTILINE if multiline
      options |= Regex::Options::DOTALL if dotall
      options |= Regex::Options::IGNORE_CASE if ignorecase
      @pattern = Regex.new(node["pattern"], options)
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
end
