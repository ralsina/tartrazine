# WASM entry point for browser usage
require "../tartrazine"

module Tartrazine
  # WASM-compatible API for browser usage
  class WASMInterface
    # Initialize the WASM module with optional network loading
    def self.initialize(network_base_url : String? = nil)
      configure_wasm_loader(network_base_url)
    end

    # Highlight text to HTML
    def self.to_html(text : String, language : String, theme : String = "default-dark") : String
      Tartrazine.to_html(text, language, theme)
    end

    # Highlight text to SVG
    def self.to_svg(text : String, language : String, theme : String = "default-dark") : String
      Tartrazine.to_svg(text, language, theme)
    end

    # Get available themes
    def self.available_themes : Array(String)
      Tartrazine.themes
    end

    # Get available lexers
    def self.available_lexers : Array(String)
      Tartrazine.lexers
    end

    # Check if a lexer is available
    def self.has_lexer?(language : String) : Bool
      Tartrazine.lexers.includes?(language)
    end

    # Get file extensions for a lexer
    def self.get_extensions(language : String) : Array(String)
      Tartrazine.lexer_extensions(language)
    end
  end
end
