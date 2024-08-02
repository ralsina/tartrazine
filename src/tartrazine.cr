require "xml"

module Tartrazine
  VERSION = "0.1.0"

  class Lexer
    property config = {
      name: "",
      aliases:    [] of String,
      filenames:  [] of String,
      mime_types: [] of String,
      priority:   0,
    }

    macro xml_to_s(node, name)
      {{node}}.children.find{|n| n.name == "{{name}}".lstrip("_")}.as(XML::Node).content.to_s
    end

    macro xml_to_a(node, name)
      {{node}}.children.select{|n| n.name == "{{name}}".lstrip("_")}.map {|n| n.content.to_s}
    end

    def self.from_xml(xml : String) : Lexer
      l = Lexer.new
      lexer = XML.parse(xml).first_element_child
      if lexer
        config = lexer.children.find { |n| n.name == "config" }
        if config
          l.config = {
            name: xml_to_s(config, name),
            aliases:  xml_to_a(config, _alias),
            filenames:  xml_to_a(config, filename),
            mime_types: xml_to_a(config, mime_type),
            priority:   xml_to_s(config, priority).to_i,
          }
        end
      end
      l
    end
  end
end

l = Tartrazine::Lexer.from_xml(File.read("chroma/lexers/embedded/plaintext.xml"))
p! l.config
