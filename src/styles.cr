require "./actions"
require "./constants"
require "./formatter"
require "./rules"
require "./styles"
require "./tartrazine"
require "sixteen"
require "xml"

module Tartrazine
  alias Color = Sixteen::Color

  def self.theme(name : String) : Theme
    begin
    return Theme.from_base16(name)
    rescue ex : Exception
      raise ex unless ex.message.try &.includes? "Theme not found"
    end
    begin
      return Theme.from_xml(ThemeFiles.get("/#{name}.xml").gets_to_end)
    rescue
      raise Exception.new("Theme #{name} not found")
    end
  end

  class ThemeFiles
    extend BakedFileSystem
    bake_folder "../styles", __DIR__
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
    property background : Color?
    property border : Color?
    property color : Color?

    # Styles are incomplete by default and inherit
    # from parents. If this is true, this style
    # is already complete and should not inherit
    # anything
    property? complete : Bool = false

    def initialize(@color = nil, @background = nil, @border = nil, @bold = nil, @italic = nil, @underline = nil)
    end

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
      theme = Theme.new
      theme.name = name
      # The color assignments are adapted from
      # https://github.com/mohd-akram/base16-pygments/

      theme.styles["Background"] = Style.new(color: t["base05"], background: t["base00"])
      theme.styles["LineHighlight"] = Style.new(color: t["base0D"], background: t["base01"])
      theme.styles["Text"] = Style.new(color: t["base05"])
      theme.styles["Error"] = Style.new(color: t["base08"])
      theme.styles["Comment"] = Style.new(color: t["base03"])
      theme.styles["CommentPreproc"] = Style.new(color: t["base0F"])
      theme.styles["CommentPreprocFile"] = Style.new(color: t["base0B"])
      theme.styles["Keyword"] = Style.new(color: t["base0E"])
      theme.styles["KeywordType"] = Style.new(color: t["base08"])
      theme.styles["NameAttribute"] = Style.new(color: t["base0D"])
      theme.styles["NameBuiltin"] = Style.new(color: t["base08"])
      theme.styles["NameBuiltinPseudo"] = Style.new(color: t["base08"])
      theme.styles["NameClass"] = Style.new(color: t["base0D"])
      theme.styles["NameConstant"] = Style.new(color: t["base09"])
      theme.styles["NameDecorator"] = Style.new(color: t["base09"])
      theme.styles["NameFunction"] = Style.new(color: t["base0D"])
      theme.styles["NameNamespace"] = Style.new(color: t["base0D"])
      theme.styles["NameTag"] = Style.new(color: t["base0E"])
      theme.styles["NameVariable"] = Style.new(color: t["base0D"])
      theme.styles["NameVariableInstance"] = Style.new(color: t["base08"])
      theme.styles["LiteralNumber"] = Style.new(color: t["base09"])
      theme.styles["Operator"] = Style.new(color: t["base0C"])
      theme.styles["OperatorWord"] = Style.new(color: t["base0E"])
      theme.styles["Literal"] = Style.new(color: t["base0B"])
      theme.styles["LiteralString"] = Style.new(color: t["base0B"])
      theme.styles["LiteralStringInterpol"] = Style.new(color: t["base0F"])
      theme.styles["LiteralStringRegex"] = Style.new(color: t["base0C"])
      theme.styles["LiteralStringSymbol"] = Style.new(color: t["base09"])
      theme
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

        s.color = style.find(&.starts_with?("#")).try { |v| Color.new v.split("#").last }
        s.background = style.find(&.starts_with?("bg:#")).try { |v| Color.new v.split("#").last }
        s.border = style.find(&.starts_with?("border:#")).try { |v| Color.new v.split("#").last }

        theme.styles[node["type"]] = s
      end
      # We really want a LineHighlight class
      if !theme.styles.has_key?("LineHighlight")
        theme.styles["LineHighlight"] = Style.new
        theme.styles["LineHighlight"].background = make_highlight_color(theme.styles["Background"].background)
      end
      theme
    end

    # If the color is dark, make it brighter and viceversa
    def self.make_highlight_color(base_color)
      # FIXME: do a proper luminance adjustment in the color class
      return nil if base_color.nil?
      color = Color.new(base_color.hex)
      if base_color.light?
        color.r = [(base_color.r - 40), 255].min.to_u8
        color.g = [(base_color.g - 40), 255].min.to_u8
        color.b = [(base_color.b - 40), 255].min.to_u8
      else
        color.r = [(base_color.r + 40), 255].min.to_u8
        color.g = [(base_color.g + 40), 255].min.to_u8
        color.b = [(base_color.b + 40), 255].min.to_u8
      end
      # Bug in color, setting rgb doesn't update hex
      color.hex = "#{color.r.to_s(16)}#{color.g.to_s(16)}#{color.b.to_s(16)}"
      color
    end
  end
end
