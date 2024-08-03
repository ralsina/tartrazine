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

    def match(text, pos, lexer) : Tuple(Bool, Int32, Array(Token))
      tokens = [] of Token
      match = pattern.match(text, pos)
      # We are matched, move post to after the match
      return false, pos, [] of Token if match.nil?

      # Emit the tokens
      emitters.each do |emitter|
        # Emit the token
        tokens += emitter.emit(match, lexer)
      end
      return true, match.end, tokens
    end
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

    def match(text, pos, lexer) : Tuple(Bool, Int32, Array(Token))
      puts "Including state #{state} from #{lexer.state_stack.last}"
      lexer.states[state].rules.each do |rule|
        matched, new_pos, new_tokens = rule.match(text, pos, lexer)
        return true, new_pos, new_tokens if matched
      end
      return false, pos, [] of Token
    end
  end

  # These rules look like this:
  # <rule>
  #   <pop depth="1"/>
  # </rule>
  # They match, don't move pos, probably alter
  # the stack, probably not generate tokens
  class Always < Rule
    def match(text, pos, lexer) : Tuple(Bool, Int32, Array(Token))
      tokens = [] of Token
      emitters.each do |emitter|
        tokens += emitter.emit(nil, lexer)
      end
      return true, pos, tokens
    end
  end

  class Emitter
    property type : String
    property xml : XML::Node

    def initialize(@type : String, @xml : XML::Node?)
    end

    def emit(match : Regex::MatchData?, lexer : Lexer) : Array(Token)
      case type
      when "token"
        raise Exception.new "Can't have a token without a match" if match.nil?
        [Token.new(type: xml["type"], value: match[0])]
        # TODO handle #push #push:n #pop and multiple states
      when "push"
        puts "Pushing state #{xml["state"]}"
        lexer.state_stack << xml["state"]
        [] of Token
      when "pop"
        puts "Popping #{xml["depth"]} states"
        lexer.state_stack.pop(xml["depth"].to_i)
        [] of Token
      else
        raise Exception.new("Unknown emitter type: #{type}: #{xml}")
      end
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
      matched = false
      while pos < text.size
        state = states[state_stack.last]
        state.rules.each do |rule|
          matched, new_pos, new_tokens = rule.match(text, pos, self)
          next unless matched
          pos = new_pos
          tokens += new_tokens
          break # We go back to processing with current state
        end
        # If no rule matches, emit an error token
        unless matched
          tokens << {type: "Error", value: ""}
          pos += 1
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
              case rule_node["pattern"]?
              when nil
                if rule_node.first_element_child.try &.name == "include"
                  rule = IncludeStateRule.new
                  include_node = rule_node.children.find { |n| n.name == "include" }
                  rule.state = include_node["state"] if include_node
                  state.rules << rule
                else
                  rule = Always.new
                  state.rules << rule
                end
              else
                rule = Rule.new
                begin
                  rule.pattern = /#{rule_node["pattern"]}/m
                  state.rules << rule
                rescue ex : Exception
                  puts "Bad regex in #{l.config[:name]}: #{ex}"
                  next
                end
              end

              next if rule.nil?
              # Rules contain maybe an emitter and maybe a transformer
              # emitters emit tokens, transformers do things to
              # the state stack.
              rule_node.children.each do |node|
                next unless node.element?
                # case node.name
                # when "pop", "push", "multi", "combine" # "include",
                #   transformer = Transformer.new
                #   transformer.type = node.name
                #   transformer.xml = node.to_s
                #   rule.transformers << transformer
                # else
                rule.emitters << Emitter.new(node.name, node)
                # end
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
  lexers[l.config[:name].downcase] = l
  l.config[:aliases].each do |key|
    lexers[key.downcase] = l
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



# Let's run some tests

Dir.glob("tests/*/") do |lexername|
  key = File.basename(lexername).downcase
  next unless lexers.has_key? key
  lexer = lexers[key]

  Dir.glob("#{lexername}*.txt") do |testname|
    test = File.read(testname).split("---input---\n").last.split("--tokens---").first
    tokens = lexer.tokenize(test)
    puts "Testing #{key} with #{testname}"
    # puts tokens
  end
end