require "baked_file_system"
require "./constants/lexers"

module Tartrazine
  class LexerFiles
    extend BakedFileSystem
    bake_folder "../lexers", __DIR__
  end

  # Get the lexer object for a language name
  # FIXME: support mimetypes
  def self.lexer(name : String? = nil, filename : String? = nil) : BaseLexer
    return lexer_by_name(name) if name && name != "autodetect"
    return lexer_by_filename(filename) if filename
  
    Lexer.from_xml(LexerFiles.get("/#{LEXERS_BY_NAME["plaintext"]}.xml").gets_to_end)
  end
  
  private def self.lexer_by_name(name : String) : BaseLexer
    lexer_file_name = LEXERS_BY_NAME.fetch(name.downcase, nil)
    return create_delegating_lexer(name) if lexer_file_name.nil? && name.includes? "+"
    raise Exception.new("Unknown lexer: #{name}") if lexer_file_name.nil?
  
    Lexer.from_xml(LexerFiles.get("/#{lexer_file_name}.xml").gets_to_end)
  end
  
  private def self.lexer_by_filename(filename : String) : BaseLexer
    candidates = Set(String).new
    LEXERS_BY_FILENAME.each do |k, v|
      candidates += v.to_set if File.match?(k, File.basename(filename))
    end
  
    case candidates.size
    when 0
      lexer_file_name = LEXERS_BY_NAME["plaintext"]
    when 1
      lexer_file_name = candidates.first
    else
      raise Exception.new("Multiple lexers match the filename: #{candidates.to_a.join(", ")}")
    end
  
    Lexer.from_xml(LexerFiles.get("/#{lexer_file_name}.xml").gets_to_end)
  end
  
  private def self.create_delegating_lexer(name : String) : BaseLexer
    language, root = name.split("+", 2)
    language_lexer = lexer(language)
    root_lexer = lexer(root)
    DelegatingLexer.new(language_lexer, root_lexer)
  end
  # Return a list of all lexers
  def self.lexers : Array(String)
    LEXERS_BY_NAME.keys.sort!
  end

  # A token, the output of the tokenizer
  alias Token = NamedTuple(type: String, value: String)

  abstract class BaseTokenizer
  end

  class Tokenizer < BaseTokenizer
    include Iterator(Token)
    property lexer : BaseLexer
    property text : Bytes
    property pos : Int32 = 0
    @dq = Deque(Token).new
    property state_stack = ["root"]

    def initialize(@lexer : BaseLexer, text : String, secondary = false)
      # Respect the `ensure_nl` config option
      if text.size > 0 && text[-1] != '\n' && @lexer.config[:ensure_nl] && !secondary
        text += "\n"
      end
      @text = text.to_slice
    end

    def next : Iterator::Stop | Token
      if @dq.size > 0
        return @dq.shift
      end
      if pos == @text.size
        return stop
      end

      matched = false
      while @pos < @text.size
        @lexer.states[@state_stack.last].rules.each do |rule|
          matched, new_pos, new_tokens = rule.match(@text, @pos, self)
          if matched
            @pos = new_pos
            split_tokens(new_tokens).each { |token| @dq << token }
            break
          end
        end
        if !matched
          if @text[@pos] == 10u8
            @dq << {type: "Text", value: "\n"}
            @state_stack = ["root"]
          else
            @dq << {type: "Error", value: String.new(@text[@pos..@pos])}
          end
          @pos += 1
          break
        end
      end
      self.next
    end

    # If a token contains a newline, split it into two tokens
    def split_tokens(tokens : Array(Token)) : Array(Token)
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
      split_tokens
    end
  end

  abstract class BaseLexer
    property config = {
      name:             "",
      priority:         0.0,
      case_insensitive: false,
      dot_all:          false,
      not_multiline:    false,
      ensure_nl:        false,
    }
    property states = {} of String => State

    def tokenizer(text : String, secondary = false) : BaseTokenizer
      Tokenizer.new(self, text, secondary)
    end
  end

  # This implements a lexer for Pygments RegexLexers as expressed
  # in Chroma's XML serialization.
  #
  # For explanations on what actions and states do
  # the Pygments documentation is a good place to start.
  # https://pygments.org/docs/lexerdevelopment/
  class Lexer < BaseLexer
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

  # A lexer that takes two lexers as arguments. A root lexer
  # and a language lexer. Everything is scalled using the
  # language lexer, afterwards all `Other` tokens are lexed
  # using the root lexer.
  #
  # This is useful for things like template languages, where
  # you have Jinja + HTML or Jinja + CSS and so on.
  class DelegatingLexer < BaseLexer
    property language_lexer : BaseLexer
    property root_lexer : BaseLexer

    def initialize(@language_lexer : BaseLexer, @root_lexer : BaseLexer)
    end

    def tokenizer(text : String, secondary = false) : DelegatingTokenizer
      DelegatingTokenizer.new(self, text, secondary)
    end
  end

  # This Tokenizer works with a DelegatingLexer. It first tokenizes
  # using the language lexer, and "Other" tokens are tokenized using
  # the root lexer.
  class DelegatingTokenizer < BaseTokenizer
    include Iterator(Token)
    @dq = Deque(Token).new
    @language_tokenizer : BaseTokenizer

    def initialize(@lexer : DelegatingLexer, text : String, secondary = false)
      # Respect the `ensure_nl` config option
      if text.size > 0 && text[-1] != '\n' && @lexer.config[:ensure_nl] && !secondary
        text += "\n"
      end
      @language_tokenizer = @lexer.language_lexer.tokenizer(text, true)
    end

    def next : Iterator::Stop | Token
      if @dq.size > 0
        return @dq.shift
      end
      token = @language_tokenizer.next
      if token.is_a? Iterator::Stop
        return stop
      elsif token.as(Token).[:type] == "Other"
        root_tokenizer = @lexer.root_lexer.tokenizer(token.as(Token).[:value], true)
        root_tokenizer.each do |root_token|
          @dq << root_token
        end
      else
        @dq << token.as(Token)
      end
      self.next
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
end
