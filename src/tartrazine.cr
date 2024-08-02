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

  class IncludeState < Rule
    property include : String = ""
  end

  class Lexer
    property config = {
      name:       "",
      aliases:    [] of String,
      filenames:  [] of String,
      mime_types: [] of String,
      priority:   0,
    }

    property states = [] of State

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
            priority:   xml_to_i(config, priority) || 0,
          }
        end

        rules = lexer.children.find { |n| n.name == "rules" }
        if rules
          # Rules contains states 🤷
          rules.children.select { |n| n.name == "state" }.each do |node|
            state = State.new
            l.states << state
            state.name = node["name"]
            # And states contain rules 🤷
            node.children.select { |n| n.name == "rule" }.each do |rule_node|
              if rule_node["pattern"]?
                rule = Rule.new
                state.rules << rule
                rule.pattern = /#{rule_node["pattern"]}/
              else
                puts "Unknown rule type: #{rule_node}"
              end
            end
          end
        end
      end
      l
    end
  end
end

l = Tartrazine::Lexer.from_xml(File.read("lexers/solidity.xml"))
# p! l.config, l.states

# Convenience macros to parse XML
macro xml_to_s(node, name)
{{node}}.children.find{|n| n.name == "{{name}}".lstrip("_")}.try &.content.to_s
end

macro xml_to_i(node, name)
({{node}}.children.find{|n| n.name == "{{name}}".lstrip("_")}.try &.content.to_s.to_i)
end

macro xml_to_a(node, name)
{{node}}.children.select{|n| n.name == "{{name}}".lstrip("_")}.map {|n| n.content.to_s}
end
