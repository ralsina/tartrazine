require "./actions"
require "./formatter"
require "./rules"
require "./styles"
require "./tartrazine"

# These are Lexer actions. When a rule matches, it will
# perform a list of actions. These actions can emit tokens
# or change the state machine.
module Tartrazine
  class Action
    property actions : Array(Action) = [] of Action
    property type : String

    @depth : Int32 = 0
    @lexer_name : String = ""
    @states : Array(String) = [] of String
    @states_to_push : Array(String) = [] of String
    @token_type : String = ""

    def initialize(@type : String, xml : XML::Node?)
      known_types = %w(token push pop combined bygroups include using usingself)
      raise Exception.new("Unknown action type: #{type}") unless known_types.includes? type

      # Some actions may have actions in them, like this:
      # <bygroups>
      # <token type="GenericPrompt"/>
      # <token type="Text"/>
      # <using lexer="bash"/>
      # </bygroups>
      #
      # The token actions match with the first 2 groups in the regex
      # the using action matches the 3rd and shunts it to another lexer
      xml.children.each do |node|
        next unless node.element?
        @actions << Action.new(node.name, node)
      end

      # Prefetch the attributes we ned from the XML and keep them
      case type
      when "token"
        @token_type = xml["type"]
      when "push"
        @states_to_push = xml.attributes.select { |attrib|
          attrib.name == "state"
        }.map &.content
      when "pop"
        @depth = xml["depth"].to_i
      when "using"
        @lexer_name = xml["lexer"].downcase
      when "combined"
        @states = xml.attributes.select { |attrib|
          attrib.name == "state"
        }.map &.content
      end
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def emit(match : MatchData, lexer : Lexer, match_group = 0) : Array(Token)
      case type
      when "token"
        raise Exception.new "Can't have a token without a match" if match.empty?
        [Token.new(type: @token_type, value: String.new(match[match_group].value))]
      when "push"
        to_push = @states_to_push.empty? ? [lexer.state_stack.last] : @states_to_push
        to_push.each do |state|
          if state == "#pop"
            # Pop the state
            lexer.state_stack.pop
          else
            # Really push
            lexer.state_stack << state
          end
        end
        [] of Token
      when "pop"
        to_pop = [@depth, lexer.state_stack.size - 1].min
        lexer.state_stack.pop(to_pop)
        [] of Token
      when "bygroups"
        # FIXME: handle
        # ><bygroups>
        # <token type="Punctuation"/>
        # None
        # <token type="LiteralStringRegex"/>
        #
        # where that None means skipping a group
        #
        raise Exception.new "Can't have a token without a match" if match.nil?

        # Each group matches an action. If the group match is empty,
        # the action is skipped.
        result = [] of Token
        @actions.each_with_index do |e, i|
          begin
            next if match[i + 1].size == 0
          rescue IndexError
            # FIXME: This should not actually happen
            # No match for this group
            next
          end
          result += e.emit(match, lexer, i + 1)
        end
        result
      when "using"
        # Shunt to another lexer entirely
        return [] of Token if match.empty?
        Tartrazine.lexer(@lexer_name).tokenize(String.new(match[match_group].value), usingself: true)
      when "usingself"
        # Shunt to another copy of this lexer
        return [] of Token if match.empty?
        new_lexer = lexer.copy
        new_lexer.tokenize(String.new(match[match_group].value), usingself: true)
      when "combined"
        # Combine two states into one anonymous state
        new_state = @states.map { |name|
          lexer.states[name]
        }.reduce { |state1, state2|
          state1 + state2
        }
        lexer.states[new_state.name] = new_state
        lexer.state_stack << new_state.name
        [] of Token
      else
        raise Exception.new("Unknown action type: #{type}")
      end
    end
  end
end
