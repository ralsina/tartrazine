require "baked_file_system"
require "./constants/lexers"

module Tartrazine
  class LexerFiles
    extend BakedFileSystem

    bake_folder "../lexers", __DIR__
  end

  # Get the lexer object for a language name
  # FIXME: support mimetypes
  def self.lexer(name : String? = nil, filename : String? = nil) : Lexer
    if name.nil? && filename.nil?
      lexer_file_name = LEXERS_BY_NAME["plaintext"]
    elsif name && name != "autodetect"
      lexer_file_name = LEXERS_BY_NAME[name.downcase]
    else
      # Guess by filename
      candidates = Set(String).new
      LEXERS_BY_FILENAME.each do |k, v|
        candidates += v.to_set if File.match?(k, File.basename(filename.to_s))
      end
      case candidates.size
      when 0
        lexer_file_name = LEXERS_BY_NAME["plaintext"]
      when 1
        lexer_file_name = candidates.first
      else
        raise Exception.new("Multiple lexers match the filename: #{candidates.to_a.join(", ")}")
      end
    end
    Lexer.from_xml(LexerFiles.get("/#{lexer_file_name}.xml").gets_to_end)
  end

  # Return a list of all lexers
  def self.lexers : Array(String)
    LEXERS_BY_NAME.keys.sort!
  end

  # This implements a lexer for Pygments RegexLexers as expressed
  # in Chroma's XML serialization.
  #
  # For explanations on what actions and states do
  # the Pygments documentation is a good place to start.
  # https://pygments.org/docs/lexerdevelopment/
  struct Lexer
    property config = {
      name:             "",
      priority:         0.0,
      case_insensitive: false,
      dot_all:          false,
      not_multiline:    false,
      ensure_nl:        false,
    }
    # property xml : String = ""
    property states = {} of String => State
    property state_stack = ["root"]

    def copy : Lexer
      new_lexer = Lexer.new
      new_lexer.config = config
      new_lexer.states = states
      new_lexer.state_stack = state_stack[0..-1]
      new_lexer
    end

    # Turn the text into a list of tokens. The `secondary` parameter
    # is true when the lexer is being used to tokenize a string
    # from a larger text that is already being tokenized.
    # So, when it's true, we don't modify the text.
    def tokenize(text : String, secondary = false) : Array(Token)
      @state_stack = ["root"]
      tokens = [] of Token
      pos = 0
      matched = false

      # Respect the `ensure_nl` config option
      if text.size > 0 && text[-1] != '\n' && config[:ensure_nl] && !secondary
        text += "\n"
      end

      # We operate in bytes from now on
      text_bytes = text.to_slice
      # Loop through the text, matching rules
      while pos < text_bytes.size
        states[@state_stack.last].rules.each do |rule|
          matched, new_pos, new_tokens = rule.match(text_bytes, pos, self)
          if matched
            # Move position forward, save the tokens,
            pos = new_pos
            tokens += new_tokens
            break
          end
        end
        if !matched
          # at EOL, emit the newline, reset state to "root"
          if text_bytes[pos] == 10u8
            tokens << {type: "Text", value: "\n"}
            @state_stack = ["root"]
          else
            # Emit an error token
            tokens << {type: "Error", value: String.new(text_bytes[pos..pos])}
          end
          # Move forward 1
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

    # Group tokens into lines, splitting them when a newline is found
    def group_tokens_in_lines(tokens : Array(Token)) : Array(Array(Token))
      split_tokens = [] of Token
      tokens.each do |token|
        if token[:value].includes?("\n")
          values = token[:value].split("\n")
          values.each_with_index do |value, index|
            value += "\n" if index < values.size - 1
            split_tokens << {type: token[:type], value: value}
          end
        else
          split_tokens << token
        end
      end
      lines = [Array(Token).new]
      split_tokens.each do |token|
        lines.last << token
        if token[:value].includes?("\n")
          lines << Array(Token).new
        end
      end
      lines
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def self.from_xml(xml : String) : Lexer
      l = Lexer.new
      lexer = XML.parse(xml).first_element_child
      if lexer
        config = lexer.children.find { |node|
          node.name == "config"
        }
        if config
          l.config = {
            name:             xml_to_s(config, name) || "",
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
  struct State
    property name : String = ""
    property rules = [] of BaseRule

    def +(other : State)
      new_state = State.new
      new_state.name = Random.base58(8)
      new_state.rules = rules + other.rules
      new_state
    end
  end

  # A token, the output of the tokenizer
  alias Token = NamedTuple(type: String, value: String)
end
