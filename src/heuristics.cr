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
      p! disambiguation
    end
  end

  class Disambiguation
    include YAML::Serializable
    property extensions : Array(String)
    property rules : Array(LangRule)
  end

  class Rule
    include YAML::Serializable
    property pattern : (String | Array(String))?
    property named_pattern : String?
    property and : Array(Rule)?
  end

  class LangRule < Rule
    include YAML::Serializable
    property language : String | Array(String)
  end
end

h = Tartrazine::Heuristic.from_yaml(File.read("heuristics/heuristics.yml"))
h.run("../elkjs/src/elk.h", File.read("../elkjs/src/elk.h"))
