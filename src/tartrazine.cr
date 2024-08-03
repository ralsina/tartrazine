require "base58"
require "json"
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

    def +(other : State)
      new_state = State.new
      new_state.name = Random.base58(8)
      new_state.rules = rules + other.rules
      new_state
    end
  end

  class Rule
    property pattern : Regex = Regex.new ""
    property emitters : Array(Emitter) = [] of Emitter
    property transformers : Array(Transformer) = [] of Transformer
    property xml : String = "foo"

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
      p! xml, match.end, tokens
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
        p! xml, new_pos, new_tokens if matched
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
      when "push"
        states_to_push = xml.attributes.select { |a| a.name == "state" }.map &.content
        if states_to_push.empty?
          # Push without a state means push the current state
          states_to_push = [lexer.state_stack.last]
        end
        states_to_push.each do |state|
          if state == "#pop"
            # Pop the state
            puts "Popping state"
            lexer.state_stack.pop
          else
            # Really push
            puts "Pushing state #{state}"
            lexer.state_stack << state
          end
        end
        [] of Token
      when "pop"
        depth = xml["depth"].to_i
        puts "Popping #{depth} states"
        if lexer.state_stack.size <= depth
          puts "Can't pop #{depth} states, only have #{lexer.state_stack.size}"
        else
          lexer.state_stack.pop(depth)
        end
        [] of Token
      when "bygroups"
        # This takes the groups in the regex and emits them as tokens
        # Get all the token nodes
        raise Exception.new "Can't have a token without a match" if match.nil?
        tokens = xml.children.select { |n| n.name == "token" }.map(&.["type"].to_s)
        result = [] of Token
        tokens.each_with_index do |t, i|
          result << {type: t, value: match[i + 1]}
        end
        result
      when "using"
        # Shunt to another lexer entirely
        return [] of Token if match.nil?
        lexer_name = xml["lexer"].downcase
        LEXERS[lexer_name].tokenize(match[0])
      when "combined"
        # Combine two states into one anonymous state
        states = xml.attributes.select { |a| a.name == "state" }.map &.content
        new_state = states.map {|name| lexer.states[name]}.reduce { |s1, s2| s1 + s2 }
        lexer.states[new_state.name] = new_state
        lexer.state_stack << new_state.name
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

  LEXERS = {} of String => Tartrazine::Lexer

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
        p! state_stack.last, pos
        state.rules.each do |rule|
          matched, new_pos, new_tokens = rule.match(text, pos, self)
          next unless matched
          p! rule.xml

          pos = new_pos
          tokens += new_tokens
          break # We go back to processing with current state
        end
        # If no rule matches, emit an error token
        unless matched
          tokens << {type: "Error", value: "?"}
          pos += 1
        end
      end
      tokens.reject { |t| t[:type] == "Text" && t[:value] == "" }
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
                  rule.xml = rule_node.to_s
                  include_node = rule_node.children.find { |n| n.name == "include" }
                  rule.state = include_node["state"] if include_node
                  state.rules << rule
                else
                  rule = Always.new
                  rule.xml = rule_node.to_s
                  state.rules << rule
                end
              else
                rule = Rule.new
                rule.xml = rule_node.to_s
                begin
                  rule.pattern = Regex.new(
                    rule_node["pattern"],
                    Regex::Options::ANCHORED | Regex::Options::MULTILINE
                  )
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

lexers = Tartrazine::LEXERS

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

def chroma_tokenize(lexer, text)
  output = IO::Memory.new
  input = IO::Memory.new(text)
  Process.run(
    "chroma",
    ["-f", "json", "-l", lexer],
    input: input, output: output
  )
  Array(Tartrazine::Token).from_json(output.to_s)
end

def test_file(testname, lexer)
  test = File.read(testname).split("---input---\n").last.split("---tokens---").first
  pp! test
  begin
    tokens = lexer.tokenize(test)
  rescue ex : Exception
    puts ">>>ERROR"
    p! ex
    exit 1
  end
  outp = IO::Memory.new
  i = IO::Memory.new(test)
  lname = lexer.config[:name]
  Process.run(
    "chroma",
    ["-f", "json", "-l", lname], input: i, output: outp
  )
  chroma_tokens = Array(Tartrazine::Token).from_json(outp.to_s)
  if chroma_tokens != tokens
    pp! tokens
    pp! chroma_tokens
    puts ">>>BAD"
  else
    puts ">>>GOOD"
  end
end

# test_file("tests/c/test_preproc_file2.txt", lexers["c"])
# exit 0

total = 0
Dir.glob("tests/*/") do |lexername|
  key = File.basename(lexername).downcase
  next unless lexers.has_key? key
  lexer = lexers[key]

  Dir.glob("#{lexername}*.txt") do |testname|
    puts "Testing #{key} with #{testname}"
    total += 1
    test_file(testname, lexer)
  end
end
puts ">>>TOTAL #{total}"
