require "yaml"

  # Use linguist's heuristics to disambiguate between languages
  # This is *shamelessly* stolen from https://github.com/github-linguist/linguist
  # and ported to Crystal. Deepest thanks to the authors of Linguist
  # for licensing it liberally.
  # 
  # Consider this code (c) 2017 GitHub, Inc. even if I wrote it.
  module Linguist

  class Heuristic
    include YAML::Serializable

    property disambiguations : Array(Disambiguation)
    property named_patterns : Hash(String, String | Array(String))

    # Run the heuristics on the given filename and content
    def run(filename, content)
      ext = File.extname filename
      disambiguation = disambiguations.find do |item|
        item.extensions.includes? ext
      end
      disambiguation.try &.run(content, named_patterns)
    end
  end

  class Disambiguation
    include YAML::Serializable
    property extensions : Array(String)
    property rules : Array(LangRule)

    def run(content, named_patterns)
      rules.each do |rule|
        if rule.match(content, named_patterns)
          return rule.language
        end
      end
      nil
    end
  end

  class LangRule
    include YAML::Serializable
    property pattern : (String | Array(String))?
    property negative_pattern : (String | Array(String))?
    property named_pattern : String?
    property and : Array(LangRule)?
    property language : String | Array(String)?

    # ameba:disable Metrics/CyclomaticComplexity
    def match(content, named_patterns)
      # This rule matches without conditions
      return true if !pattern && !negative_pattern && !named_pattern && !and

      if pattern
        p_arr = [] of String
        p_arr << pattern.as(String) if pattern.is_a? String
        p_arr = pattern.as(Array(String)) if pattern.is_a? Array(String)
        return true if p_arr.any? { |pat| ::Regex.new(pat).matches?(content) }
      end
      if negative_pattern
        p_arr = [] of String
        p_arr << negative_pattern.as(String) if negative_pattern.is_a? String
        p_arr = negative_pattern.as(Array(String)) if negative_pattern.is_a? Array(String)
        return true if p_arr.none? { |pat| ::Regex.new(pat).matches?(content) }
      end
      if named_pattern
        p_arr = [] of String
        if named_patterns[named_pattern].is_a? String
          p_arr << named_patterns[named_pattern].as(String)
        else
          p_arr = named_patterns[named_pattern].as(Array(String))
        end
        result = p_arr.any? { |pat| ::Regex.new(pat).matches?(content) }
      end
      if and
        result = and.as(Array(LangRule)).all?(&.match(content, named_patterns))
      end
      result
    end
  end
end

h = Linguist::Heuristic.from_yaml(File.read("heuristics/heuristics.yml"))
fname = "/usr/include/sqlite3.h"
p! h.run(fname, File.read(fname))
