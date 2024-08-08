require "xml"

# These are Lexer actions. When a rule matches, it will
# perform a list of actions. These actions can emit tokens
# or change the state machine.
module Tartrazine
  class Action
    property type : String
    property xml : XML::Node
    property actions : Array(Action) = [] of Action

    def initialize(@type : String, @xml : XML::Node?)
      # Some actions may have actions in them, like this:
      # <bygroups>
      # <token type="GenericPrompt"/>
      # <token type="Text"/>
      # <using lexer="bash"/>
      # </bygroups>
      #
      # The token actions match with the first 2 groups in the regex
      # the using action matches the 3rd and shunts it to another lexer
      @xml.children.each do |node|
        next unless node.element?
        @actions << Action.new(node.name, node)
      end
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def emit(match : Regex::MatchData | CRe2::MatchDataLike | Nil,
             lexer : Lexer, match_group = 0) : Array(Token)
      case type
      when "token"
        raise Exception.new "Can't have a token without a match" if match.nil? || match[0].size == 0
        [Token.new(type: xml["type"], value: match[0])]
      when "push"
        states_to_push = xml.attributes.select { |attrib|
          attrib.name == "state"
        }.map &.content
        if states_to_push.empty?
          # Push without a state means push the current state
          states_to_push = [lexer.state_stack.last]
        end
        states_to_push.each do |state|
          if state == "#pop"
            # Pop the state
            Log.trace { "Popping state" }
            lexer.state_stack.pop
          else
            # Really push
            lexer.state_stack << state
            Log.trace { "Pushed #{lexer.state_stack}" }
          end
        end
        [] of Token
      when "pop"
        depth = xml["depth"].to_i
        Log.trace { "Popping #{depth} states" }
        if lexer.state_stack.size <= depth
          Log.trace { "Can't pop #{depth} states, only have #{lexer.state_stack.size}" }
        else
          lexer.state_stack.pop(depth)
        end
        [] of Token
      when "bygroups"
        # FIXME: handle
        # ><bygroups>
        # <token type="Punctuation"/>https://github.com/google/re2/wiki/Syntax
        # None
        # <token type="LiteralStringRegex"/>
        #
        # where that None means skipping a group
        #
        raise Exception.new "Can't have a bygroups without a match" if match.nil? || match[0].size == 0

        # Each group matches an action. If the group match is empty,
        # the action is skipped.
        result = [] of Token
        @actions.each_with_index do |e, i|
          next if match[i].size == 0
          result += e.emit(match, lexer, i)
        end
        result
      when "using"
        # Shunt to another lexer entirely
        return [] of Token if match.nil? || match[0].size == 0
        lexer_name = xml["lexer"].downcase
        # Log.trace { "to tokenize: #{match[match_group]}" }
        to_tokenize = match[match_group]
        Tartrazine.lexer(lexer_name).tokenize(to_tokenize, usingself: true)
      when "usingself"
        # Shunt to another copy of this lexer
        return [] of Token if match.nil? || match[0].size == 0

        new_lexer = Lexer.from_xml(lexer.xml)
        # Log.trace { "to tokenize: #{match[match_group]}" }
        to_tokenize = match[match_group]
        new_lexer.tokenize(to_tokenize, usingself: true)
      when "combined"
        # Combine two states into one anonymous state
        states = xml.attributes.select { |attrib|
          attrib.name == "state"
        }.map &.content
        new_state = states.map { |name|
          lexer.states[name]
        }.reduce { |state1, state2|
          state1 + state2
        }
        lexer.states[new_state.name] = new_state
        lexer.state_stack << new_state.name
        [] of Token
      else
        raise Exception.new("Unknown action type: #{type}: #{xml}")
      end
    end
  end
end
