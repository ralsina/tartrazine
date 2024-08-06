require "sixteen"
require "xml"

module Tartrazine
  def self.theme(name : String) : Theme
    path = File.join("styles", "#{name}.xml")
    Theme.from_xml(File.read(path))
  end

  class Style
    # These properties are tri-state.
    # true means it's set
    # false means it's not set
    # nil means inherit from parent style
    property bold : Bool?
    property italic : Bool?
    property underline : Bool?

    # These properties are either set or nil
    # (inherit from parent style)
    property background : String?
    property border : String?
    property color : String?

    # Styles are incomplete by default and inherit
    # from parents. If this is true, this style
    # is already complete and should not inherit
    # anything
    property? complete : Bool = false

    macro merge_prop(prop)
      new.{{prop}} = other.{{prop}}.nil? ? self.{{prop}} : other.{{prop}}
    end

    def +(other : Style)
      new = Style.new
      merge_prop bold
      merge_prop italic
      merge_prop underline
      merge_prop background
      merge_prop border
      merge_prop color
      new
    end
  end

  class Theme
    property name : String = ""

    property styles = {} of String => Style

    # Get the style for a token.
    def style(token)
      styles[token] = Style.new unless styles.has_key?(token)
      s = styles[token]

      # We already got the data from the style hierarchy
      return s if s.complete?

      # Form the hierarchy of parent styles
      parents = style_parents(token)

      s = parents.map do |parent|
        styles[parent]
      end.reduce(s) do |acc, style|
        acc + style
      end
      s.complete = true
      styles[token] = s
      s
    end

    def style_parents(token)
      parents = ["Background"]
      parts = token.underscore.split("_").map(&.capitalize)
      parts.each_with_index do |_, i|
        parents << parts[..i].join("")
      end
      parents
    end

    # Load from a base16 theme name using Sixteen
    def self.from_base16(name : String) : Theme
      t = Sixteen.theme(name)
      # The color assignments are adapted from
      # https://github.com/mohd-akram/base16-pygments/

      t.styles["Background"] = Style.new(color: t["base05"], background: t["base00"])
      t.styles["Text"] = Style.new(color: t["base05"])
      t.styles["Error"] = Style.new(color: t["base08"])
      t.styles["Comment"] = Style.new(color: t["base03"])
      t.styles["CommentPreProc"] = Style.new(color: t["base0f"])
      t.styles["CommentPreProcFile"] = Style.new(color: t["base0b"])
      t.styles["Keyword"] = Style.new(color: t["base0e"])
      t.styles["KeywordType"] = Style.new(color: t["base08"])
      t.styles["NameAttribute"] = Style.new(color: t["base0d"])
      t.styles["NameBuiltin"] = Style.new(color: t["base08"])
      t.styles["NameBuiltinPseudo"] = Style.new(color: t["base08"])
      t.styles["NameClass"] = Style.new(color: t["base0d"])
      t.styles["NameConstant"] = Style.new(color: t["base09"])
      t.styles["NameDecorator"] = Style.new(color: t["base09"])
      t.styles["NameFunction"] = Style.new(color: t["base0d"])
      t.styles["NameNamespace"] = Style.new(color: t["base0d"])
      t.styles["NameTag"] = Style.new(color: t["base0e"])
      t.styles["NameVariable"] = Style.new(color: t["base0d"])
      t.styles["NameVariableInstance"] = Style.new(color: t["base08"])
      t.styles["Number"] = Style.new(color: t["base09"])
      t.styles["Operator"] = Style.new(color: t["base0c"])
      t.styles["OperatorWord"] = Style.new(color: t["base0e"])
      t.styles["Literal"] = Style.new(color: t["base0b"])
      t.styles["String"] = Style.new(color: t["base0b"])
      t.styles["StringInterpol"] = Style.new(color: t["base0f"])
      t.styles["StringRegex"] = Style.new(color: t["base0c"])
      t.styles["StringSymbol"] = Style.new(color: t["base09"])
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
