require "./actions"
require "./formatter"
require "./rules"
require "./styles"
require "./tartrazine"
require "sixteen"
require "xml"

module Tartrazine
  alias Color = Sixteen::Color

  struct ThemeFiles
    extend BakedFileSystem

    macro bake_selected_themes
      {% if env("TT_THEMES") %}
      {% for theme in env("TT_THEMES").split "," %}
      bake_file {{ theme }}+".xml", {{ read_file "#{__DIR__}/../styles/" + theme + ".xml" }}
      {% end %}
      {% end %}
    end

    {% if flag?(:nothemes) %}
      bake_selected_themes
    {% else %}
      bake_folder "../styles", __DIR__
    {% end %}
  end

  def self.theme(name : String, variant : String? = nil) : Theme
    # Normalize theme name by removing variant suffixes for base theme detection
    base_name = name.gsub(/-light$|-dark$/, "")

    # Handle variant preference for base16 themes
    if variant
      case variant.downcase
      when "light"
        # Special handling for Catppuccin
        if base_name == "catppuccin"
          begin
            return Theme.from_xml(ThemeFiles.get("/catppuccin-latte.xml").gets_to_end)
          rescue
            # Fallback to base16 if XML variant not found
            begin
              light_theme = Sixteen.light_variant(base_name)
              return Theme.from_base16(light_theme.name)
            rescue ex : Exception
              raise ex unless ex.message.try &.includes? "Theme not found"
            end
          end
        end

        # Check if the requested theme is already the light variant
        if name.ends_with?("-light")
          begin
            return Theme.from_xml(ThemeFiles.get("/#{name}.xml").gets_to_end)
          rescue
            # Continue with normal logic
          end
        end

        # For other themes, check if XML variant exists
        xml_light_name = "#{base_name}-light"
        begin
          return Theme.from_xml(ThemeFiles.get("/#{xml_light_name}.xml").gets_to_end)
        rescue
          # Variant doesn't exist, try to load the base theme as fallback
          begin
            return Theme.from_xml(ThemeFiles.get("/#{base_name}.xml").gets_to_end)
          rescue
            # Fallback to base16 if base XML theme also doesn't exist
            begin
              light_theme = Sixteen.light_variant(base_name)
              return Theme.from_base16(light_theme.name)
            rescue ex : Exception
              raise ex unless ex.message.try &.includes? "Theme not found"
            end
          end
        end
      when "dark"
        # Special handling for Catppuccin
        if base_name == "catppuccin"
          begin
            return Theme.from_xml(ThemeFiles.get("/catppuccin-mocha.xml").gets_to_end)
          rescue
            # Fallback to base16 if XML variant not found
            begin
              dark_theme = Sixteen.dark_variant(base_name)
              return Theme.from_base16(dark_theme.name)
            rescue ex : Exception
              raise ex unless ex.message.try &.includes? "Theme not found"
            end
          end
        end

        # Check if the requested theme is already the dark variant
        if name.ends_with?("-dark")
          begin
            return Theme.from_xml(ThemeFiles.get("/#{name}.xml").gets_to_end)
          rescue
            # Continue with normal logic
          end
        end

        # For other themes, check if XML variant exists
        xml_dark_name = "#{base_name}-dark"
        begin
          return Theme.from_xml(ThemeFiles.get("/#{xml_dark_name}.xml").gets_to_end)
        rescue
          # Variant doesn't exist, try to load the base theme as fallback
          begin
            return Theme.from_xml(ThemeFiles.get("/#{base_name}.xml").gets_to_end)
          rescue
            # Fallback to base16 if base XML theme also doesn't exist
            begin
              dark_theme = Sixteen.dark_variant(base_name)
              return Theme.from_base16(dark_theme.name)
            rescue ex : Exception
              raise ex unless ex.message.try &.includes? "Theme not found"
            end
          end
        end
      end
    end

    # Original theme loading logic - prefer XML themes first, then fallback to base16
    begin
      Theme.from_xml(ThemeFiles.get("/#{name}.xml").gets_to_end)
    rescue ex : Exception
      # XML theme not found, try base16
      begin
        if variant
          # Try to load the specific variant first (sixteen auto-generates if needed)
          case variant.downcase
          when "light"
            begin
              light_theme = Sixteen.light_variant(name)
              # Create theme directly from the variant theme object
              return create_theme_from_sixteen(light_theme, name)
            rescue
              # If light variant fails, continue to base theme
            end
          when "dark"
            begin
              dark_theme = Sixteen.dark_variant(name)
              # Create theme directly from the variant theme object
              return create_theme_from_sixteen(dark_theme, name)
            rescue
              # If dark variant fails, continue to base theme
            end
          end
        end
        # If no variant or variant loading failed, try base theme
        Theme.from_base16(name)
      rescue ex : Exception
        raise Exception.new("Error loading theme #{name}: #{ex.message}")
      end
    end
  end

  # Create a Tartrazine theme from a Sixteen theme object
  def self.create_theme_from_sixteen(sixteen_theme : Sixteen::Theme, theme_name : String? = nil) : Theme
    Theme.create_theme_from_sixteen(sixteen_theme, theme_name)
  end

  # Return a list of all themes
  def self.themes
    themes = Set(String).new
    ThemeFiles.files.each do |file|
      filename = file.path.split("/").last
      # Skip non-theme files like LICENSE, README
      next if filename == "LICENSE" || filename == "README"
      themes << filename.split(".").first
    end
    Sixteen::DataFiles.files.each do |file|
      filename = file.path.split("/").last
      # Only include YAML theme files from Sixteen (skip LICENSE, README, etc.)
      next unless filename.ends_with?(".yaml")
      themes << filename.split(".").first
    end
    themes.to_a.sort!
  end

  # Get theme families that have both dark and light variants
  def self.theme_families : Array(Sixteen::ThemeFamily)
    Sixteen.theme_families.select { |family|
      !family.dark_themes.empty? && !family.light_themes.empty?
    }
  end

  # Get themes with variant information
  def self.themes_with_variants : Array({name: String, has_light: Bool, has_dark: Bool, is_light: Bool, is_dark: Bool})
    result = [] of {name: String, has_light: Bool, has_dark: Bool, is_light: Bool, is_dark: Bool}

    # Add XML themes and detect explicit variants
    xml_themes = Set(String).new
    ThemeFiles.files.each do |file|
      filename = file.path.split("/").last
      next if filename == "LICENSE" || filename == "README"
      theme_name = filename.split(".").first
      xml_themes.add(theme_name)
    end

    # Consolidate XML themes by base name and detect variants
    base_xml_themes = Set(String).new

    xml_themes.each do |theme_name|
      # Find the base theme name by removing variant suffixes
      base_name = theme_name.gsub(/-(light|dark)(-.*)?$/, "")
      base_xml_themes.add(base_name)
    end

    base_xml_themes.each do |base_name|
      # Check if this base theme has explicit variants
      has_explicit_light = xml_themes.any?(&.starts_with?("#{base_name}-light"))
      has_explicit_dark = xml_themes.any?(&.starts_with?("#{base_name}-dark"))

      # Check if the base theme itself exists and determine its variant
      base_theme_exists = xml_themes.includes?(base_name)
      base_is_light = false
      base_is_dark = false

      if base_theme_exists
        begin
          theme = Tartrazine.theme(base_name)
          base_is_light = theme.light?
          base_is_dark = theme.dark?
        rescue
          # If we can't determine, assume it's not a variant
        end
      end

      # Determine overall light/dark availability
      has_light = has_explicit_light || (base_theme_exists && base_is_light)
      has_dark = has_explicit_dark || (base_theme_exists && base_is_dark)

      # Determine if this specific name is a variant
      is_light = base_name.ends_with?("-light") || (base_theme_exists && base_is_light && !has_explicit_dark)
      is_dark = base_name.ends_with?("-dark") || (base_theme_exists && base_is_dark && !has_explicit_light)

      result << {name: base_name, has_light: has_light, has_dark: has_dark, is_light: is_light, is_dark: is_dark}
    end

    # Add base16 themes using theme families with proper consolidation
    base16_family_names = Set(String).new

    Sixteen.theme_families.each do |family|
      # Extract the true base name by removing -light, -dark, and variant suffixes
      true_base_name = family.base_name.gsub(/-(light|dark)(-.+)?$/, "")

      # Skip base16 themes that are simple -light/-dark variants of existing XML themes
      # (XML themes are higher quality than base16 equivalents)
      if family.base_name.ends_with?("-light") || family.base_name.ends_with?("-dark")
        next if base_xml_themes.includes?(true_base_name)
      end

      base16_family_names.add(true_base_name)
    end

    # Create consolidated base16 theme entries
    base16_family_names.each do |base_name|
      # All base16 theme families have both light and dark variants (sixteen auto-generates missing ones)
      has_light = true
      has_dark = true
      is_light = false # Base themes aren't inherently light or dark variants
      is_dark = false

      result << {name: base_name, has_light: has_light, has_dark: has_dark, is_light: is_light, is_dark: is_dark}
    end

    # Remove duplicates and sort
    seen_names = Set(String).new
    unique_result = result.select do |theme_item|
      if seen_names.includes?(theme_item[:name])
        false
      else
        seen_names.add(theme_item[:name])
        true
      end
    end
    unique_result.sort_by { |theme_item| theme_item[:name] }
  end

  # Get only themes that have light and/or dark variants
  def self.themes_with_variants_only : Array({name: String, has_light: Bool, has_dark: Bool, is_light: Bool, is_dark: Bool})
    themes_with_variants.select { |theme| theme[:has_light] || theme[:has_dark] }
  end

  struct Style
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

  struct Theme
    property name : String = ""

    property styles = {} of String => Style

    def style_parents(token)
      parents = ["Background"]
      parts = token.underscore.split("_").map(&.capitalize)
      parts.each_with_index do |_, i|
        parents << parts[..i].join("")
      end
      parents
    end

    # Check if this is a light theme
    def light? : Bool
      # First try to determine from base16 metadata
      begin
        sixteen_theme = Sixteen.theme(@name)
        return sixteen_theme.variant == "light"
      rescue
        # Not a base16 theme, fall back to background color analysis
      end

      # For XML themes, analyze the background color
      bg_style = styles["Background"]?
      return false unless bg_style

      bg_color = bg_style.background
      return false unless bg_color

      # Consider a theme "light" if background brightness > 0.5 (50%)
      # Using a simple approximation based on RGB values
      bg_color.light?
    end

    # Check if this is a dark theme
    def dark? : Bool
      # First try to determine from base16 metadata
      begin
        sixteen_theme = Sixteen.theme(@name)
        return sixteen_theme.variant == "dark"
      rescue
        # Not a base16 theme, fall back to background color analysis
      end

      # For XML themes, analyze the background color
      bg_style = styles["Background"]?
      return false unless bg_style

      bg_color = bg_style.background
      return false unless bg_color

      # Consider a theme "dark" if background brightness <= 0.5 (50%)
      # Using a simple approximation based on RGB values
      bg_color.dark?
    end

    # Load from a base16 theme name using Sixteen
    def self.from_base16(name : String) : Theme
      t = Sixteen.theme(name)
      create_theme_from_sixteen(t, name)
    end

    # Create a Tartrazine theme from a Sixteen theme object
    def self.create_theme_from_sixteen(sixteen_theme : Sixteen::Theme, theme_name : String? = nil) : Theme
      theme = Theme.new
      theme.name = theme_name || sixteen_theme.name
      # The color assignments are adapted from
      # https://github.com/mohd-akram/base16-pygments/

      theme.styles["Background"] = Style.new(color: sixteen_theme["base05"], background: sixteen_theme["base00"], bold: true)
      theme.styles["LineHighlight"] = Style.new(color: sixteen_theme["base0D"], background: sixteen_theme["base01"])
      theme.styles["Text"] = Style.new(color: sixteen_theme["base05"])
      theme.styles["Error"] = Style.new(color: sixteen_theme["base08"])
      theme.styles["Comment"] = Style.new(color: sixteen_theme["base03"])
      theme.styles["CommentPreproc"] = Style.new(color: sixteen_theme["base0F"])
      theme.styles["CommentPreprocFile"] = Style.new(color: sixteen_theme["base0B"])
      theme.styles["Keyword"] = Style.new(color: sixteen_theme["base0E"])
      theme.styles["KeywordType"] = Style.new(color: sixteen_theme["base08"])
      theme.styles["NameAttribute"] = Style.new(color: sixteen_theme["base0D"])
      theme.styles["NameBuiltin"] = Style.new(color: sixteen_theme["base08"])
      theme.styles["NameBuiltinPseudo"] = Style.new(color: sixteen_theme["base08"])
      theme.styles["NameClass"] = Style.new(color: sixteen_theme["base0D"])
      theme.styles["NameConstant"] = Style.new(color: sixteen_theme["base09"])
      theme.styles["NameDecorator"] = Style.new(color: sixteen_theme["base09"])
      theme.styles["NameFunction"] = Style.new(color: sixteen_theme["base0D"])
      theme.styles["NameNamespace"] = Style.new(color: sixteen_theme["base0D"])
      theme.styles["NameTag"] = Style.new(color: sixteen_theme["base0E"])
      theme.styles["NameVariable"] = Style.new(color: sixteen_theme["base0D"])
      theme.styles["NameVariableInstance"] = Style.new(color: sixteen_theme["base08"])
      theme.styles["LiteralNumber"] = Style.new(color: sixteen_theme["base09"])
      theme.styles["Operator"] = Style.new(color: sixteen_theme["base0C"])
      theme.styles["OperatorWord"] = Style.new(color: sixteen_theme["base0E"])
      theme.styles["Literal"] = Style.new(color: sixteen_theme["base0B"])
      theme.styles["LiteralString"] = Style.new(color: sixteen_theme["base0B"])
      theme.styles["LiteralStringInterpol"] = Style.new(color: sixteen_theme["base0F"])
      theme.styles["LiteralStringRegex"] = Style.new(color: sixteen_theme["base0C"])
      theme.styles["LiteralStringSymbol"] = Style.new(color: sixteen_theme["base09"])

      # Additional common token types for better coverage
      theme.styles["Punctuation"] = Style.new(color: sixteen_theme["base05"])
      theme.styles["TextWhitespace"] = Style.new(color: sixteen_theme["base05"])
      theme.styles["CommentMultiline"] = Style.new(color: sixteen_theme["base03"], italic: true)
      theme.styles["LiteralStringSingle"] = Style.new(color: sixteen_theme["base0B"])
      theme.styles["LiteralStringOther"] = Style.new(color: sixteen_theme["base0B"])
      theme.styles["LiteralStringChar"] = Style.new(color: sixteen_theme["base0B"])
      theme.styles["LiteralStringBacktick"] = Style.new(color: sixteen_theme["base0B"])
      theme.styles["LiteralStringAffix"] = Style.new(color: sixteen_theme["base09"])
      theme.styles["LiteralStringDoc"] = Style.new(color: sixteen_theme["base0D"], italic: true)
      theme.styles["LiteralStringEscape"] = Style.new(color: sixteen_theme["base0F"])
      theme.styles["LiteralNumberFloat"] = Style.new(color: sixteen_theme["base09"])
      theme.styles["LiteralNumberHex"] = Style.new(color: sixteen_theme["base09"])
      theme.styles["LiteralNumberInteger"] = Style.new(color: sixteen_theme["base09"])
      theme.styles["LiteralNumberOct"] = Style.new(color: sixteen_theme["base09"])
      theme.styles["LiteralNumberBin"] = Style.new(color: sixteen_theme["base09"])
      theme.styles["KeywordReserved"] = Style.new(color: sixteen_theme["base0E"], bold: true)
      theme.styles["KeywordDeclaration"] = Style.new(color: sixteen_theme["base0E"], italic: true)
      theme.styles["KeywordNamespace"] = Style.new(color: sixteen_theme["base0E"])
      theme.styles["KeywordPseudo"] = Style.new(color: sixteen_theme["base0E"], italic: true)
      theme.styles["KeywordConstant"] = Style.new(color: sixteen_theme["base08"])
      theme.styles["CommentSpecial"] = Style.new(color: sixteen_theme["base0F"], bold: true)
      theme.styles["CommentHashbang"] = Style.new(color: sixteen_theme["base03"], bold: true)
      theme.styles["CommentPreprocFile"] = Style.new(color: sixteen_theme["base0B"], bold: true)
      theme.styles["CommentPreproc"] = Style.new(color: sixteen_theme["base0F"])
      theme.styles["GenericHeading"] = Style.new(color: sixteen_theme["base0D"], bold: true)
      theme.styles["GenericSubheading"] = Style.new(color: sixteen_theme["base0D"], bold: true, italic: true)
      theme.styles["GenericStrong"] = Style.new(color: sixteen_theme["base08"], bold: true)
      theme.styles["GenericEmph"] = Style.new(color: sixteen_theme["base09"], italic: true)
      theme.styles["GenericDeleted"] = Style.new(color: sixteen_theme["base08"])
      theme.styles["GenericInserted"] = Style.new(color: sixteen_theme["base0B"])
      theme.styles["GenericPrompt"] = Style.new(color: sixteen_theme["base0D"])
      theme.styles["GenericOutput"] = Style.new(color: sixteen_theme["base05"])
      theme.styles["GenericTraceback"] = Style.new(color: sixteen_theme["base08"])
      theme.styles["GenericError"] = Style.new(color: sixteen_theme["base08"])
      theme.styles["GenericUnderline"] = Style.new(color: sixteen_theme["base05"], underline: true)
      theme.styles["NameBuiltinPseudo"] = Style.new(color: sixteen_theme["base08"], italic: true)
      theme.styles["NameDecorator"] = Style.new(color: sixteen_theme["base09"], italic: true)
      theme.styles["NameNamespace"] = Style.new(color: sixteen_theme["base0E"], italic: true)
      theme.styles["Other"] = Style.new(color: sixteen_theme["base05"])

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
        theme.styles["LineHighlight"].bold = true
      end
      theme
    end

    # If the color is dark, make it brighter and viceversa
    def self.make_highlight_color(base_color)
      if base_color.nil?
        # WHo knows
        return Color.new(127, 127, 127)
      end
      if base_color.dark?
        base_color.lighter(0.2)
      else
        base_color.darker(0.2)
      end
    end
  end
end
