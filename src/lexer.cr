module Tartrazine
  class LexerFiles
    extend BakedFileSystem

    bake_folder "../lexers", __DIR__
  end

  # This implements a lexer for Pygments RegexLexers as expressed
  # in Chroma's XML serialization.
  #
  # For explanations on what actions and states do
  # the Pygments documentation is a good place to start.
  # https://pygments.org/docs/lexerdevelopment/
  class Lexer
    property config = {
      name:             "",
      aliases:          [] of String,
      filenames:        [] of String,
      mime_types:       [] of String,
      priority:         0.0,
      case_insensitive: false,
      dot_all:          false,
      not_multiline:    false,
      ensure_nl:        false,
    }
    property xml : String = ""

    property states = {} of String => State

    property state_stack = ["root"]

    # Turn the text into a list of tokens. The `usingself` parameter
    # is true when the lexer is being used to tokenize a string
    # from a larger text that is already being tokenized.
    # So, when it's true, we don't modify the text.
    def tokenize(text, usingself = false) : Array(Token)
      @state_stack = ["root"]
      tokens = [] of Token
      pos = 0
      matched = false

      # Respect the `ensure_nl` config option
      if text.size > 0 && text[-1] != '\n' && config[:ensure_nl] && !usingself
        text += "\n"
      end

      # Loop through the text, applying rules
      while pos < text.size
        state = states[@state_stack.last]
        # Log.trace { "Stack is #{@state_stack} State is #{state.name}, pos is #{pos}, text is #{text[pos..pos + 10]}" }
        state.rules.each do |rule|
          matched, new_pos, new_tokens = rule.match(text, pos, self)
          if matched
            # Move position forward, save the tokens,
            # tokenize from the new position
            # Log.trace { "MATCHED: #{rule.xml}" }
            pos = new_pos
            tokens += new_tokens
            break
          end
          # Log.trace { "NOT MATCHED: #{rule.xml}" }
        end
        # If no rule matches, emit an error token
        unless matched
          # Log.trace { "Error at #{pos}" }
          tokens << {type: "Error", value: "#{text[pos]}"}
          pos += 1
        end
      end
      Lexer.collapse_tokens(tokens)
    end

    # Collapse consecutive tokens of the same type for easier comparison
    # and smaller output
    def self.collapse_tokens(tokens : Array(Tartrazine::Token)) : Array(Tartrazine::Token)
      result = [] of Tartrazine::Token
      tokens = tokens.reject { |token| token[:value] == "" }
      tokens.each do |token|
        if result.empty?
          result << token
          next
        end
        last = result.last
        if last[:type] == token[:type]
          new_token = {type: last[:type], value: last[:value] + token[:value]}
          result.pop
          result << new_token
        else
          result << token
        end
      end
      result
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def self.from_xml(xml : String) : Lexer
      l = Lexer.new
      l.xml = xml
      lexer = XML.parse(xml).first_element_child
      if lexer
        config = lexer.children.find { |node|
          node.name == "config"
        }
        if config
          l.config = {
            name:             xml_to_s(config, name) || "",
            aliases:          xml_to_a(config, _alias) || [] of String,
            filenames:        xml_to_a(config, filename) || [] of String,
            mime_types:       xml_to_a(config, mime_type) || [] of String,
            priority:         xml_to_f(config, priority) || 0.0,
            not_multiline:    xml_to_s(config, not_multiline) == "true",
            dot_all:          xml_to_s(config, dot_all) == "true",
            case_insensitive: xml_to_s(config, case_insensitive) == "true",
            ensure_nl:        xml_to_s(config, ensure_nl) == "true",
          }
        end

        rules = lexer.children.find { |node|
          node.name == "rules"
        }
        if rules
          # Rules contains states 🤷
          rules.children.select { |node|
            node.name == "state"
          }.each do |state_node|
            state = State.new
            state.name = state_node["name"]
            if l.states.has_key?(state.name)
              raise Exception.new("Duplicate state: #{state.name}")
            else
              l.states[state.name] = state
            end
            # And states contain rules 🤷
            state_node.children.select { |node|
              node.name == "rule"
            }.each do |rule_node|
              case rule_node["pattern"]?
              when nil
                if rule_node.first_element_child.try &.name == "include"
                  rule = IncludeStateRule.new(rule_node)
                else
                  rule = UnconditionalRule.new(rule_node)
                end
              else
                rule = Rule.new(rule_node,
                  multiline: !l.config[:not_multiline],
                  dotall: l.config[:dot_all],
                  ignorecase: l.config[:case_insensitive])
              end
              state.rules << rule
            end
          end
        end
      end
      l
    end
  end

  # A Lexer state. A state has a name and a list of rules.
  # The state machine has a state stack containing references
  # to states to decide which rules to apply.
  class State
    property name : String = ""
    property rules = [] of Rule

    def +(other : State)
      new_state = State.new
      new_state.name = Random.base58(8)
      new_state.rules = rules + other.rules
      new_state
    end
  end

  # A token, the output of the tokenizer
  alias Token = NamedTuple(type: String, value: String)

  def self.lexer(name : String) : Lexer
    Lexer.from_xml(LexerFiles.get("/#{name}.xml").gets_to_end)
  end
end
