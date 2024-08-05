require "./actions"
require "./rules"
require "base58"
require "json"
require "log"
require "xml"

module Tartrazine
  VERSION = "0.1.0"

  Log = ::Log.for("tartrazine")

  # This implements a lexer for Pygments RegexLexers as expressed
  # in Chroma's XML serialization.
  #
  # For explanations on what actions, transformers, etc do
  # the Pygments documentation is a good place to start.
  # https://pygments.org/docs/lexerdevelopment/

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

    # Turn the text into a list of tokens.
    def tokenize(text, usingself = false) : Array(Token)
      @state_stack = ["root"]
      tokens = [] of Token
      pos = 0
      matched = false
      if text.size > 0 && text[-1] != '\n' && config[:ensure_nl] && !usingself
        text += "\n"
      end
      while pos < text.size
        state = states[@state_stack.last]
        Log.trace { "Stack is #{@state_stack} State is #{state.name}, pos is #{pos}, text is #{text[pos..pos + 10]}" }
        state.rules.each do |rule|
          matched, new_pos, new_tokens = rule.match(text, pos, self)
          Log.trace { "NOT MATCHED: #{rule.xml}" }
          next unless matched
          Log.trace { "MATCHED: #{rule.xml}" }

          pos = new_pos
          tokens += new_tokens
          break # We go back to processing with current state
        end
        # If no rule matches, emit an error token
        unless matched
          Log.trace { "Error at #{pos}" }
          tokens << {type: "Error", value: "#{text[pos]}"}
          pos += 1
        end
      end
      tokens.reject { |token| token[:value] == "" }
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
            name:          xml_to_s(config, name) || "",
            aliases:       xml_to_a(config, _alias) || [] of String,
            filenames:     xml_to_a(config, filename) || [] of String,
            mime_types:    xml_to_a(config, mime_type) || [] of String,
            priority:      xml_to_f(config, priority) || 0.0,
            not_multiline: xml_to_s(config, not_multiline) == "true",
            # FIXME: Because Crystal's multiline flag forces dot_all this
            # doesn't work perfectly yet.
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

  def self.get_lexer(name : String) : Lexer
    Lexer.from_xml(File.read("lexers/#{name}.xml"))
  end

  # This is a hack to workaround that Crystal seems to disallow
  # having regexes multiline but not dot_all
  class Re2 < Regex
    @source = "fa"
    @options = Regex::Options::None
    @jit = true

    def initialize(pattern : String, multiline = false, dotall = false, ignorecase = false)
      flags = LibPCRE2::UTF | LibPCRE2::DUPNAMES |
              LibPCRE2::UCP | LibPCRE2::ANCHORED
      flags |= LibPCRE2::MULTILINE if multiline
      flags |= LibPCRE2::DOTALL if dotall
      flags |= LibPCRE2::CASELESS if ignorecase
      @re = Regex::PCRE2.compile(pattern, flags) do |error_message|
        raise Exception.new(error_message)
      end
    end
  end
end

# Convenience macros to parse XML
macro xml_to_s(node, name)
{{node}}.children.find{|n| n.name == "{{name}}".lstrip("_")}.try &.content.to_s
end

macro xml_to_f(node, name)
({{node}}.children.find{|n| n.name == "{{name}}".lstrip("_")}.try &.content.to_s.to_f)
end

macro xml_to_a(node, name)
{{node}}.children.select{|n| n.name == "{{name}}".lstrip("_")}.map {|n| n.content.to_s}
end
