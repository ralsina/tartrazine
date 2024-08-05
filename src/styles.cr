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

    styles = Hash{String => Style}

    # Get the style for a token.
    def style(token)
    end
  end
end
