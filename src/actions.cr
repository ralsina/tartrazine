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
    Usingbygroup
    Usingself
  end

  struct Action
    property actions : Array(Action) = [] of Action

    property token_type : String = ""
    property states_to_push : Array(String) = [] of String
    property depth = 0
    property lexer_name : String = ""
    property states_to_combine : Array(String) = [] of String

    def initialize(@type : String, @xml : XML::Node?)
      # Extract information from the XML node we will use later

      # Some actions may have actions in them, like this:
      # <bygroups>
      # <token type="GenericPrompt"/>
      # <token type="Text"/>
      # <using lexer="bash"/>
      # </bygroups>
      #
      # The token actions match with the first 2 groups in the regex
      # the using action matches the 3rd and shunts it to another lexer

      known_types = %w(token push pop bygroups using usingself include combined)
      raise Exception.new(
        "Unknown action type: #{@type}") unless known_types.includes? @type

      @xml.children.each do |node|
        next unless node.element?
        @actions << Action.new(node.name, node)
      end

      case @type
      when "token"
        @token_type = xml["type"]? || ""
      when "push"
        @states_to_push = xml.attributes.select { |attrib|
          attrib.name == "state"
        }.map &.content || [] of String
      when "pop"
        @depth = xml["depth"]?.try &.to_i || 0
      when "using"
        @lexer_name = xml["lexer"]?.try &.downcase || ""
      when "combined"
        @states_to_combine = xml.attributes.select { |attrib|
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
      when "push"
        if @states_to_push.empty?
          # Push without a state means push the current state
          @states_to_push = [lexer.state_stack.last]
        end
        @states_to_push.each do |state|
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
        if lexer.state_stack.size > @depth
          lexer.state_stack.pop(@depth)
        end
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
        raise Exception.new "Can't have a token without a match" if match.empty?

        # Each group matches an action. If the group match is empty,
        # the action is skipped.
        result = [] of Token
        @actions.each_with_index do |e, i|
          begin
            next if match[i + 1].size == 0
          rescue IndexError
            # No match for the last group
            next
          end
          result += e.emit(match, tokenizer, i + 1)
        end
        result
      when ActionType::Using
        # Shunt to another lexer entirely
        return [] of Token if match.empty?
        Tartrazine.lexer(@lexer_name).tokenize(String.new(match[match_group].value), usingself: true)
      when "usingself"
        # Shunt to another copy of this lexer
        return [] of Token if match.empty?
        new_lexer = Lexer.from_xml(lexer.xml)
        new_lexer.tokenize(String.new(match[match_group].value), usingself: true)
      when "combined"
        # Combine two states into one anonymous state
        new_state = @states_to_combine.map { |name|
          lexer.states[name]
        }.reduce { |state1, state2|
          state1 + state2
        }
        tokenizer.lexer.states[new_state.name] = new_state
        tokenizer.state_stack << new_state.name
        [] of Token
      when ActionType::Usingbygroup
        # Shunt to content-specified lexer
        return [] of Token if match.empty?
        content = ""
        @content_index.each do |i|
          content += String.new(match[i].value)
        end
        Tartrazine.lexer(String.new(match[@lexer_index].value)).tokenizer(
          content,
          secondary: true).to_a
      else
        raise Exception.new("Unhandled action type: #{type}")
      end
    end
  end
end
