require "./actions"
require "./formatter"
require "./rules"
require "./styles"
require "./tartrazine"
require "baked_file_system"
require "base58"
require "json"
require "log"
require "xml"

module Tartrazine
  extend self
  VERSION = "0.2.0"

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
