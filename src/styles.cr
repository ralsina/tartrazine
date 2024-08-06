require "xml"

module Tartrazine
  class Style
    # These properties are tri-state.
    # true means it's set
    # false means it's not set
    # nil means inherit from parent style
    property bold : Bool?
    property nobold : Bool?
    property italic : Bool?
    property notalic : Bool?
    property underline : Bool?

    # These properties are either set or nil
    # (inherit from parent style)
    property background : String?
    property border : String?
    property color : String?
  end

  class Theme
    property name : String = ""

    property styles = {} of String => Style

    # Get the style for a token.
    def style(token)
    end

    # Load from a Chroma XML file
    def self.from_xml(xml : String) : Theme
      document = XML.parse(xml)
      theme = Theme.new
      style = document.first_element_child
      raise Exception.new("Error loading theme") if style.nil?
      theme.name = style["name"]
      style.children.select { |node| node.name == "entry" }.each do |node|
        s = Style.new
        style = node["style"].split

        s.bold = nil
        s.bold = true if style.includes?("bold")
        s.bold = false if style.includes?("nobold")

        s.italic = nil
        s.italic = true if style.includes?("italic")
        s.italic = false if style.includes?("noitalic")

        s.underline = nil
        s.underline = true if style.includes?("underline")
        s.underline = false if style.includes?("nounderline")

        s.color = style.find(&.starts_with?("#")).try &.split("#").last
        s.background = style.find(&.starts_with?("bg:#")).try &.split("#").last
        s.border = style.find(&.starts_with?("border:#")).try &.split("#").last

        theme.styles[node["type"]] = s
      end
      theme
    end
  end
end

t = Tartrazine::Theme.from_xml(File.read("styles/catppuccin-frappe.xml"))

pp! t.styles["Name"]
