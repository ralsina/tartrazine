require "./actions"

# These are lexer rules. They match with the text being parsed
# and perform actions, either emitting tokens or changing the
# state of the lexer.
module Tartrazine
  # This rule matches via a regex pattern
  class Rule
    property pattern : Regex = Regex.new ""
    property actions : Array(Action) = [] of Action
    property xml : String = "foo"

    def match(text, pos, lexer) : Tuple(Bool, Int32, Array(Token))
      tokens = [] of Token
      match = pattern.match(text, pos)
      # We don't match if the match doesn't move the cursor
      # because that causes infinite loops
      # pp! match, pattern.inspect, text, pos
      return false, pos, [] of Token if match.nil? || match.end == 0
      # Emit the tokens
      actions.each do |action|
        # Emit the token
        tokens += action.emit(match, lexer)
      end
      # p! xml, match.end, tokens
      return true, match.end, tokens
    end

    def initialize(node : XML::Node, flags)
      @xml = node.to_s
      @pattern = Regex.new(node["pattern"], flags)
      add_actions(node)
    end

    def add_actions(node : XML::Node)
      node.children.each do |node|
        next unless node.element?
        @actions << Action.new(node.name, node)
      end
    end
  end

  # This rule includes another state. If any of the rules of the
  # included state matches, this rule matches.
  class IncludeStateRule < Rule
    property state : String = ""

    def match(text, pos, lexer) : Tuple(Bool, Int32, Array(Token))
      # puts "Including state #{state} from #{lexer.state_stack.last}"
      lexer.states[state].rules.each do |rule|
        matched, new_pos, new_tokens = rule.match(text, pos, lexer)
        # p! xml, new_pos, new_tokens if matched
        return true, new_pos, new_tokens if matched
      end
      return false, pos, [] of Token
    end

    def initialize(node : XML::Node)
      @xml = node.to_s
      include_node = node.children.find { |n| n.name == "include" }
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
