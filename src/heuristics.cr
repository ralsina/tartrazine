require "yaml"

module Tartrazine
  # Use linguist's heuristics to disambiguate between languages

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

  class Rule
    include YAML::Serializable
    property pattern : (String | Array(String))?
    property negative_pattern : (String | Array(String))?
    property named_pattern : String?
    property and : Array(Rule)?

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
        result = and.as(Array(Rule)).all?(&.match(content, named_patterns))
      end
      result
    end
  end

  class LangRule < Rule
    include YAML::Serializable
    property language : String | Array(String)
  end
end

# h = Tartrazine::Heuristic.from_yaml(File.read("heuristics/heuristics.yml"))
# p! h.run(ARGV[0], File.read(ARGV[0]))
