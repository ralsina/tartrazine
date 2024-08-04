require "base58"
require "json"
require "xml"
require "./rules"
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


  class Emitter
    property type : String
    property xml : XML::Node
    property emitters : Array(Emitter) = [] of Emitter

    def initialize(@type : String, @xml : XML::Node?)
      # Some emitters may have emitters in them, like this:
      # <bygroups>
      # <token type="GenericPrompt"/>
      # <token type="Text"/>
      # <using lexer="bash"/>
      # </bygroups>
      #
      # The token emitters match with the first 2 groups in the regex
      # the using emitter matches the 3rd and shunts it to another lexer
      @xml.children.each do |node|
        next unless node.element?
        @emitters << Emitter.new(node.name, node)
      end
    end

    def emit(match : Regex::MatchData?, lexer : Lexer, match_group = 0) : Array(Token)
      case type
      when "token"
        raise Exception.new "Can't have a token without a match" if match.nil?
        [Token.new(type: xml["type"], value: match[match_group])]
      when "push"
        states_to_push = xml.attributes.select { |a| a.name == "state" }.map &.content
        if states_to_push.empty?
          # Push without a state means push the current state
          states_to_push = [lexer.state_stack.last]
        end
        states_to_push.each do |state|
          if state == "#pop"
            # Pop the state
            # puts "Popping state"
            lexer.state_stack.pop
          else
            # Really push
            lexer.state_stack << state
            # puts "Pushed #{lexer.state_stack}"
          end
        end
        [] of Token
      when "pop"
        depth = xml["depth"].to_i
        # puts "Popping #{depth} states"
        if lexer.state_stack.size <= depth
          # puts "Can't pop #{depth} states, only have #{lexer.state_stack.size}"
        else
          lexer.state_stack.pop(depth)
        end
        [] of Token
      when "bygroups"
        # FIXME: handle
        # ><bygroups>
        # <token type="Punctuation"/>
        # None
        # <token type="LiteralStringRegex"/>
        #
        # where that None means skipping a group
        #
        raise Exception.new "Can't have a token without a match" if match.nil?

        # Each group matches an emitter

        result = [] of Token
        @emitters.each_with_index do |e, i|
          next if match[i + 1]?.nil?
          result += e.emit(match, lexer, i + 1)
        end
        result
      when "using"
        # Shunt to another lexer entirely
        return [] of Token if match.nil?
        lexer_name = xml["lexer"].downcase
        # pp! "to tokenize:", match[match_group]
        LEXERS[lexer_name].tokenize(match[match_group], usingself: true)
      when "usingself"
        # Shunt to another copy of this lexer
        return [] of Token if match.nil?

        new_lexer = Lexer.from_xml(lexer.xml)
        # pp! "to tokenize:", match[match_group]
        new_lexer.tokenize(match[match_group], usingself: true)
      when "combined"
        # Combine two states into one anonymous state
        states = xml.attributes.select { |a| a.name == "state" }.map &.content
        new_state = states.map { |name| lexer.states[name] }.reduce { |s1, s2| s1 + s2 }
        lexer.states[new_state.name] = new_state
        lexer.state_stack << new_state.name
        [] of Token
      else
        raise Exception.new("Unknown emitter type: #{type}: #{xml}")
      end
    end
  end

  alias Token = NamedTuple(type: String, value: String)

  LEXERS = {} of String => Tartrazine::Lexer

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
        # puts "Stack is #{@state_stack} State is #{state.name}, pos is #{pos}, text is #{text[pos..pos + 10]}"
        state.rules.each do |rule|
          matched, new_pos, new_tokens = rule.match(text, pos, self)
          # puts "NOT MATCHED: #{rule.xml}"
          next unless matched
          # puts "MATCHED: #{rule.xml}"

          pos = new_pos
          tokens += new_tokens
          break # We go back to processing with current state
        end
        # If no rule matches, emit an error token
        unless matched
          # p! "Error at #{pos}"
          tokens << {type: "Error", value: "#{text[pos]}"}
          pos += 1
        end
      end
      tokens.reject { |t| t[:value] == "" }
    end

    def self.from_xml(xml : String) : Lexer
      l = Lexer.new
      l.xml = xml
      lexer = XML.parse(xml).first_element_child
      if lexer
        config = lexer.children.find { |n| n.name == "config" }
        if config
          l.config = {
            name:          xml_to_s(config, name) || "",
            aliases:       xml_to_a(config, _alias) || [] of String,
            filenames:     xml_to_a(config, filename) || [] of String,
            mime_types:    xml_to_a(config, mime_type) || [] of String,
            priority:      xml_to_f(config, priority) || 0.0,
            not_multiline: xml_to_s(config, not_multiline) == "true",
            # FIXME: This has no effect yet (see )
            dot_all:          xml_to_s(config, dot_all) == "true",
            case_insensitive: xml_to_s(config, case_insensitive) == "true",
            ensure_nl:        xml_to_s(config, ensure_nl) == "true",
          }
        end

        rules = lexer.children.find { |n| n.name == "rules" }
        if rules
          # Rules contains states 🤷
          rules.children.select { |n| n.name == "state" }.each do |state_node|
            state = State.new
            state.name = state_node["name"]
            if l.states.has_key?(state.name)
              raise Exception.new("Duplicate state: #{state.name}")
            else
              l.states[state.name] = state
            end
            # And states contain rules 🤷
            state_node.children.select { |n| n.name == "rule" }.each do |rule_node|
              case rule_node["pattern"]?
              when nil
                if rule_node.first_element_child.try &.name == "include"
                  rule = IncludeStateRule.new(rule_node)
                else
                  rule = Always.new(rule_node)
                end
              else
                flags = Regex::Options::ANCHORED
                flags |= Regex::Options::MULTILINE unless l.config[:not_multiline]
                flags |= Regex::Options::IGNORE_CASE if l.config[:case_insensitive]
                flags |= Regex::Options::DOTALL if l.config[:dot_all]
                rule = Rule.new(rule_node, flags)
              end
              state.rules << rule
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
  begin
    l = Tartrazine::Lexer.from_xml(File.read(fname))
  rescue ex : Exception
    # p! ex
    next
  end
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


    # # #<Regex::Error:Regex match error: match limit exceeded>
    # next if testname == "tests/fortran/test_string_cataback.txt"

    # # Difference is different unicode representation of a string literal
    # next if testname == "tests/java/test_string_literals.txt"
    # next if testname == "tests/systemd/example1.txt"
    # next if testname == "tests/json/test_strings.txt"

    # # Tartrazine agrees with pygments, disagrees with chroma
    # next if testname == "tests/java/test_default.txt"
    # next if testname == "tests/java/test_numeric_literals.txt"
    # next if testname == "tests/java/test_multiline_string.txt"

    # # Tartrazine disagrees with pygments and chroma, but it's fine
    # next if testname == "tests/php/test_string_escaping_run.txt"

    # # Chroma's output is bad, but so is Tartrazine's
    # next if "tests/html/javascript_unclosed.txt" == testname

    # # KNOWN BAD -- TO FIX
    # next if "tests/html/css_backtracking.txt" == testname
    # next if "tests/php/anonymous_class.txt" == testname
    # next if "tests/c/test_string_resembling_decl_end.txt" == testname
    # next if "tests/mcfunction/data.txt" == testname
    # next if "tests/mcfunction/selectors.txt" == testname

