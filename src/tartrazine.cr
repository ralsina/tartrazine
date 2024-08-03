require "xml"

module Tartrazine
  VERSION = "0.1.0"

  class State
    property name : String = ""
    property rules = [] of Rule
  end

  class Rule
    property pattern : Regex? = nil
  end

  # This rule includes another state
  # I have no idea what thet MEANS yet but in the XML
  # it's this:
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
    property type : String = ""
  end

  class Lexer
    property config = {
      name:       "",
      aliases:    [] of String,
      filenames:  [] of String,
      mime_types: [] of String,
      priority:   0.0,
    }

    property states = {} of String => State

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
                  rule.pattern = /#{rule_node["pattern"]}/
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
                  puts "transformer: #{node.to_s}"
                when "bygroups", "combined", "mutators", "token", "using", "usingbygroup", "usingself"
                  puts "emitter: #{node.to_s}"
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

Dir.glob("lexers/*.xml").each do |fname|
  Tartrazine::Lexer.from_xml(File.read(fname))
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
