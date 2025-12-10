# WASM-specific configuration and compatibility layer

# Configure dependencies for WASM
macro configure_wasm_dependencies
  {% if flag?(:wasm32) %}
    # WASM-compatible dependencies only
    require "xml"
    require "json"
    require "log"
    # Skip dependencies that don't work in WASM:
    # - stumpy_png (image processing)
    # - base58 (encoding - provide compatibility shim)

    # Base58 compatibility for WASM
    struct Random
      def self.base58(length : Int) : String
        # Simple alphanumeric fallback for WASM
        chars = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
        (0...length).map { chars[rand(chars.size)] }.join
      end
    end
  {% else %}
    # All dependencies for native builds
    require "xml"
    require "json"
    require "log"
    require "base58"
  {% end %}
end

# Configure formatters for WASM (exclude incompatible ones)
macro configure_wasm_formatters
  {% if flag?(:wasm32) %}
    # Only include formatters that work in WASM
    require "./formatters/html"
    require "./formatters/svg"
    require "./formatters/json"
    # Skip PNG formatter due to StumpyPNG dependencies
  {% else %}
    # Include all formatters for native builds
    require "./formatters/**"
  {% end %}
end

# Essential lexers that should always be available in WASM builds
ESSENTIAL_LEXERS = ["plaintext", "html", "css", "javascript", "json"]

# Configure minimal lexer set for WASM
macro configure_wasm_lexers
  {% if flag?(:wasm32) %}
    # For WASM builds, ensure we have at least the essential lexers
    ENV["TT_LEXERS"] ||= ESSENTIAL_LEXERS.join(",")
  {% end %}
end

# WASM-specific file system configuration
macro configure_wasm_loader(network_base_url = nil)
  {% if flag?(:wasm32) %}
    # For WASM, use a minimal baked loader with optional network fallback
    loaders = [] of Tartrazine::LexerLoader

    # Always include essential baked lexers
    base_loader = Tartrazine::BakedLexerLoader.new

    if {{network_base_url}}
      network_loader = Tartrazine::NetworkLexerLoader.new({{network_base_url}}, base_loader)
      loaders << network_loader
    else
      loaders << base_loader
    end

    Tartrazine.lexer_loader = loaders.size == 1 ? loaders.first : Tartrazine::HybridLexerLoader.new(loaders)
  {% end %}
end
