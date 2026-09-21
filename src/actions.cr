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

    @content_index : Array(Int32) = [] of Int32
    @depth : Int32 = 0
    @lexer_index : Int32 = 0
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
        @states_to_push = xml.attributes.select do |attrib|
          attrib.name == "state"
        end.map &.content
      when ActionType::Pop
        @depth = xml["depth"].to_i
      when ActionType::Using
        @lexer_name = xml["lexer"].downcase
      when ActionType::Combined
        @states = xml.attributes.select do |attrib|
          attrib.name == "state"
        end.map &.content
      when ActionType::Usingbygroup
        @lexer_index = xml["lexer"].to_i
        @content_index = xml["content"].split(",").map(&.to_i)
      end
    end

    # Emit tokens into the accumulator, so matching a rule does not
    # allocate intermediate arrays per action.
    # ameba:disable Metrics/CyclomaticComplexity
    def emit(match : MatchDataView, tokenizer : Tokenizer, tokens : Array(Token), match_group = 0) : Nil
      case @type
      when ActionType::Token
        raise Exception.new "Can't have a token without a match" if match.empty?
        tokens << Token.new(type: @token_type, value: String.new(match.group(match_group)))
      when ActionType::Push
        if @states_to_push.empty?
          tokenizer.state_stack << tokenizer.state_stack.last
        else
          @states_to_push.each do |state|
            if state == "#pop" && tokenizer.state_stack.size > 1
              # Pop the state
              tokenizer.state_stack.pop
            else
              # Really push
              tokenizer.state_stack << state
            end
          end
        end
      when ActionType::Pop
        to_pop = [@depth, tokenizer.state_stack.size - 1].min
        tokenizer.state_stack.pop(to_pop)
      when ActionType::Bygroups
        # FIXME: handle
        # ><bygroups>
        # <token type="Punctuation"/>
        # None
        # <token type="LiteralStringRegex"/>
        #
        # where that None means skipping a group
        #

        # Each group matches an action. If the group match is empty,
        # the action is skipped.
        @actions.each_with_index do |e, action_index|
          group_index = action_index + 1
          next if group_index >= match.size || match.group_empty?(group_index)
          e.emit(match, tokenizer, tokens, group_index)
        end
      when ActionType::Using
        # Shunt to another lexer entirely
        return if match.empty?
        tokens.concat Tartrazine.lexer(@lexer_name).tokenizer(
          String.new(match.group(match_group)),
          secondary: true).to_a
      when ActionType::Usingself
        # Shunt to another copy of this lexer
        return if match.empty?
        tokens.concat tokenizer.lexer.tokenizer(
          String.new(match.group(match_group)),
          secondary: true).to_a
      when ActionType::Combined
        # Combine two or more states into one anonymous state
        new_state = @states.map do |name|
          tokenizer.state_for(name)
        end.reduce do |state1, state2|
          state1 + state2
        end
        tokenizer.remember_state(new_state)
        tokenizer.state_stack << new_state.name
      when ActionType::Usingbygroup
        # Shunt to content-specified lexer
        return if match.empty?
        content = IO::Memory.new
        @content_index.each do |group_index|
          content.write(match.group(group_index))
        end
        lexer_name = String.new(match.group(@lexer_index))
        begin
          tokens.concat Tartrazine.lexer(lexer_name).tokenizer(
            content.to_s,
            secondary: true).to_a
        rescue
          # Fallback to text lexer if requested lexer is not found
          tokens.concat Tartrazine.lexer("text").tokenizer(
            content.to_s,
            secondary: true).to_a
        end
      else
        raise Exception.new("Unknown action type: #{@type}")
      end
    end
  end
end
