# WASM entry point - minimal version for browser usage
require "./actions"
require "./formatter"
# Skip PNG formatter for WASM builds - use conditional requires
{% unless flag?(:wasm32) %}
  require "./formatters/**"
{% else %}
  require "./formatters/html"
  require "./formatters/svg"
  require "./formatters/json"
{% end %}
require "./rules"
require "./styles"
require "./tartrazine"

# Skip incompatible dependencies for WASM
{% unless flag?(:wasm32) %}
  require "base58"
{% end %}

require "baked_file_system"
require "json"
require "log"
require "xml"

{% if flag?(:wasm32) %}
  # Base58 compatibility shim for WASM
  struct Random
    def self.base58(length : Int) : String
      chars = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
      (0...length).map { chars[rand(chars.size)] }.join
    end
  end
{% end %}

module Tartrazine
  extend self
  VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}

  Log = ::Log.for("tartrazine")
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

{% if flag?(:wasm32) %}
  # WASM-specific API wrapper
  class WASMInterface
    # Initialize WASM interface
    def self.initialize
      # Set default essential lexers if not specified
      ENV["TT_LEXERS"] ||= "plaintext,html,css,javascript,json,python"
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
  end
{% end %}

# Include the rest of the lexer and token system
require "./lexer"
