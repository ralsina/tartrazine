require "./actions"
require "./formatter"
require "./rules"
require "./styles"
require "./tartrazine"

# These are Lexer actions. When a rule matches, it will
# perform a list of actions. These actions can emit tokens
# or change the state machine.
module Tartrazine
  enum ActionType
    Bygroups
    Combined
    Include
    Pop
    Push
    Token
    Using
    Usingself
  end

  struct Action
    property actions : Array(Action) = [] of Action

    @depth : Int32 = 0
    @lexer_name : String = ""
    @states : Array(String) = [] of String
    @states_to_push : Array(String) = [] of String
    @token_type : String = ""
    @type : ActionType = ActionType::Token

    def initialize(t : String, xml : XML::Node?)
      @type = ActionType.parse(t.capitalize)

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
      case @type
      when ActionType::Token
        @token_type = xml["type"]
      when ActionType::Push
        @states_to_push = xml.attributes.select { |attrib|
          attrib.name == "state"
        }.map &.content
      when ActionType::Pop
        @depth = xml["depth"].to_i
      when ActionType::Using
        @lexer_name = xml["lexer"].downcase
      when ActionType::Combined
        @states = xml.attributes.select { |attrib|
          attrib.name == "state"
        }.map &.content
      end
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def emit(match : MatchData, tokenizer : Tokenizer, match_group = 0) : Array(Token)
      case @type
      when ActionType::Token
        raise Exception.new "Can't have a token without a match" if match.empty?
        [Token.new(type: @token_type, value: String.new(match[match_group].value))]
      when ActionType::Push
        to_push = @states_to_push.empty? ? [tokenizer.state_stack.last] : @states_to_push
        to_push.each do |state|
          if state == "#pop" && tokenizer.state_stack.size > 1
            # Pop the state
            tokenizer.state_stack.pop
          else
            # Really push
            tokenizer.state_stack << state
          end
        end
        [] of Token
      when ActionType::Pop
        to_pop = [@depth, tokenizer.state_stack.size - 1].min
        tokenizer.state_stack.pop(to_pop)
        [] of Token
      when ActionType::Bygroups
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
          result += e.emit(match, tokenizer, i + 1)
        end
        result
      when ActionType::Using
        # Shunt to another lexer entirely
        return [] of Token if match.empty?
        Tokenizer.new(
          Tartrazine.lexer(@lexer_name),
          String.new(match[match_group].value),
          secondary: true).to_a
      when ActionType::Usingself
        # Shunt to another copy of this lexer
        return [] of Token if match.empty?
        Tokenizer.new(
          tokenizer.lexer,
          String.new(match[match_group].value),
          secondary: true).to_a
      when ActionType::Combined
        # Combine two or more states into one anonymous state
        new_state = @states.map { |name|
          tokenizer.lexer.states[name]
        }.reduce { |state1, state2|
          state1 + state2
        }
        tokenizer.lexer.states[new_state.name] = new_state
        tokenizer.state_stack << new_state.name
        [] of Token
      else
        raise Exception.new("Unknown action type: #{@type}")
      end
    end
  end
end
