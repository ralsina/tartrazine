require "xml"

module Tartrazine
  VERSION = "0.1.0"

  # This implements a lexer for Pygments RegexLexers as expressed
  # in Chroma's XML serialization.
  #
  # For explanations on what emitters, transformers, etc do
  # the Pygments documentation is a good place to start.
  # https://pygments.org/docs/lexerdevelopment/
  class State
    property name : String = ""
    property rules = [] of Rule
  end

  class Rule
    property pattern : Regex = Regex.new ""
    property emitters : Array(Emitter) = [] of Emitter
    property transformers : Array(Transformer) = [] of Transformer
  end

  # This rule includes another state like this:
  #   <rule>
  #     <include state="interp"/>
  #   </rule>
  # </state>
  # <state name="interp">
  #   <rule pattern="\$\(\(">
  #     <token type="Keyword"/>
  # ...

  class IncludeStateRule < Rule
    property state : String = ""
  end

  class Emitter
    property type : String
    property xml : XML::Node

    def initialize(@type : String, @xml : XML::Node?)
    end

    def emit(match : Regex::MatchData) : Array(Token)
      case type
      when "token"
        return [Token.new(type: xml["type"], value: match[0])]
      end
      [] of Token
    end
  end

  class Transformer
    property type : String = ""
    property xml : String = ""

    def transform
      puts "Transforming #{type} #{xml}"
    end
  end

  alias Token = NamedTuple(type: String, value: String)

  class Lexer
    property config = {
      name:       "",
      aliases:    [] of String,
      filenames:  [] of String,
      mime_types: [] of String,
      priority:   0.0,
    }

    property states = {} of String => State

    property state_stack = ["root"]

    # Turn the text into a list of tokens.
    def tokenize(text) : Array(Token)
      tokens = [] of Token
      pos = 0
      while pos < text.size
        state = states[state_stack.last]
        matched = false
        state.rules.each do |rule|
          case rule
          when Rule # A normal regex rule
            match = rule.pattern.match(text, pos)

            # We are matched, move post to after the match
            next if match.nil?
            matched = true
            pos = match.end

            # Emit the tokens
            rule.emitters.each do |emitter|
              # Emit the token
              tokens += emitter.emit(match)
            end
            # Transform the state
            rule.transformers.each do |transformer|
              transformer.transform
            end
          when IncludeStateRule
            # TODO: something
          end
          # TODO: Emit error if no rule matched
        end
      end
      tokens
    end

    def self.from_xml(xml : String) : Lexer
      l = Lexer.new
      lexer = XML.parse(xml).first_element_child
      if lexer
        config = lexer.children.find { |n| n.name == "config" }
        if config
          l.config = {
            name:       xml_to_s(config, name) || "",
            aliases:    xml_to_a(config, _alias) || [] of String,
            filenames:  xml_to_a(config, filename) || [] of String,
            mime_types: xml_to_a(config, mime_type) || [] of String,
            priority:   xml_to_f(config, priority) || 0.0,
          }
        end

        rules = lexer.children.find { |n| n.name == "rules" }
        if rules
          # Rules contains states 🤷
          rules.children.select { |n| n.name == "state" }.each do |state_node|
            state = State.new
            state.name = state_node["name"]
            if l.states.has_key?(state.name)
              puts "Duplicate state: #{state.name}"
            else
              l.states[state.name] = state
            end
            # And states contain rules 🤷
            state_node.children.select { |n| n.name == "rule" }.each do |rule_node|
              if rule_node["pattern"]?
                # We have patter rules
                rule = Rule.new
                begin
                  rule.pattern = /#{rule_node["pattern"]}/m
                rescue ex : Exception
                  puts "Bad regex in #{l.config[:name]}: #{ex}"
                end
              else
                # And rules that include a state
                rule = IncludeStateRule.new
                include_node = rule_node.children.find { |n| n.name == "include" }
                rule.state = include_node["state"] if include_node
              end
              state.rules << rule

              # Rules contain maybe an emitter and maybe a transformer
              # emitters emit tokens, transformers do things to
              # the state stack.
              rule_node.children.each do |node|
                next unless node.element?
                case node.name
                when "pop", "push", "include", "multi", "combine"
                  transformer = Transformer.new
                  transformer.type = node.name
                  transformer.xml = node.to_s
                  rule.transformers << transformer
                when "bygroups", "combined", "mutators", "token", "using", "usingbygroup", "usingself"
                  rule.emitters << Emitter.new(node.name, node)
                end
              end
            end
          end
        end
      end
      l
    end
  end
end

# Try loading all lexers

lexers = {} of String => Tartrazine::Lexer
Dir.glob("lexers/*.xml").each do |fname|
  l = Tartrazine::Lexer.from_xml(File.read(fname))
  lexers[l.config[:name]] = l
end

# Parse some plaintext
puts lexers["plaintext"].tokenize("Hello, world!\n")

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
