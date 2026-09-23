require "./constants/lexers"
require "./heuristics"
require "baked_file_system"
require "crystal/syntax_highlighter"

module Tartrazine
  # Raised when a lexer name/mimetype cannot be resolved
  class UnknownLexerError < Exception
  end

  class LexerFiles
    extend BakedFileSystem

    macro bake_selected_lexers
      # Always bake the plaintext fallback and the autodetect
      # heuristics so nolexer builds keep working when no specific
      # lexer is requested or the filename is ambiguous
      bake_file "plaintext.xml", {{ read_file "#{__DIR__}/../lexers/plaintext.xml" }}
      bake_file "heuristics.yml", {{ read_file "#{__DIR__}/../lexers/heuristics.yml" }}

      {% lexer_files = `ls -1 #{__DIR__}/../lexers`.split("\n") %}
      {% for lexer in env("TT_LEXERS").split "," %}
        {% if lexer == "crystal" %}
          # The crystal lexer is native Crystal code, there is no XML to bake
        {% elsif !lexer_files.includes?(lexer + ".xml") %}
          {% raise "Unknown lexer '#{lexer.id}' in TT_LEXERS: no file lexers/#{lexer.id}.xml" %}
        {% else %}
          bake_file {{ lexer }}+".xml", {{ read_file "#{__DIR__}/../lexers/" + lexer + ".xml" }}
        {% end %}
      {% end %}
    end

    {% if flag?(:nolexers) %}
      bake_selected_lexers
    {% else %}
      bake_folder "../lexers", __DIR__
    {% end %}
  end

  # Thread-safe lexer template containing only static data (rules, states, config)
  struct LexerTemplate
    property config : Hash(Symbol, String | Bool | Float64)
    property states : Hash(String, State)

    def initialize(@config, @states)
    end
  end

  # Template cache for parsed lexer data - thread-safe for read access
  @@lexer_templates = {} of String => LexerTemplate
  @@template_mutex = Mutex.new

  # Cache of lexer instances. Lexers are immutable after creation
  # (all tokenization state lives in the Tokenizer), so a single
  # instance can be shared by every user.
  @@lexer_cache = {} of String => BaseLexer
  @@lexer_mutex = Mutex.new

  # Lazily-parsed heuristics for lexer_by_content
  @@heuristics : Linguist::Heuristic?

  # Get the lexer object for a language name
  def self.lexer(name : String? = nil, filename : String? = nil, mimetype : String? = nil) : BaseLexer
    return lexer_by_name(name) if name && name != "autodetect"
    return lexer_by_filename(filename) if filename
    return lexer_by_mimetype(mimetype) if mimetype

    lexer_file_name = LEXERS_BY_NAME["plaintext"]
    create_from_template(lexer_file_name)
  end

  private def self.lexer_by_mimetype(mimetype : String) : BaseLexer
    lexer_file_name = LEXERS_BY_MIMETYPE.fetch(mimetype, nil)
    raise UnknownLexerError.new("Unknown mimetype: #{mimetype}") if lexer_file_name.nil?

    create_from_template(lexer_file_name)
  end

  private def self.lexer_by_name(name : String) : BaseLexer
    if name == "crystal"
      cached = @@lexer_cache["crystal"]?
      return cached if cached
      return @@lexer_mutex.synchronize { @@lexer_cache["crystal"] ||= CrystalLexer.new }
    end
    lexer_file_name = LEXERS_BY_NAME.fetch(name.downcase, nil)
    # Accept a lexer's file name directly (eg. common_lisp), even
    # when it is not registered as an alias
    if lexer_file_name.nil? && LexerFiles.files.any? { |file| file.path == "/#{name.downcase}.xml" }
      lexer_file_name = name.downcase
    end
    return create_delegating_lexer(name) if lexer_file_name.nil? && name.includes? "+"
    raise UnknownLexerError.new("Unknown lexer: #{name}") if lexer_file_name.nil?

    create_from_template(lexer_file_name)
  rescue BakedFileSystem::NoSuchFileError
    raise UnknownLexerError.new("Unknown lexer: #{name}")
  end

  private def self.lexer_by_filename(filename : String) : BaseLexer
    if filename.ends_with?(".cr")
      return CrystalLexer.new
    end

    candidates = Set(String).new
    LEXERS_BY_FILENAME.each do |k, v|
      candidates += v.to_set if File.match?(k, File.basename(filename))
    end

    case candidates.size
    when 0
      lexer_file_name = LEXERS_BY_NAME["plaintext"]
    when 1
      lexer_file_name = candidates.first
    else
      lexer_file_name = lexer_by_content(filename)
      begin
        return lexer(lexer_file_name)
      rescue Exception
        raise Exception.new("Multiple lexers match the filename: #{candidates.to_a.join(", ")}, heuristics suggest #{lexer_file_name} but there is no matching lexer.")
      end
    end

    create_from_template(lexer_file_name)
  end

  private def self.lexer_by_content(fname : String) : String?
    # Parsed once and shared: the heuristic rules never change
    @@heuristics ||= Linguist::Heuristic.from_yaml(LexerFiles.get("/heuristics.yml").gets_to_end)
    result = @@heuristics.as(Linguist::Heuristic).run(fname, File.read(fname))
    case result
    when Nil
      raise Exception.new "No lexer found for #{fname}"
    when String
      result.as(String)
    when Array(String)
      result.first
    end
  end

  private def self.create_delegating_lexer(name : String) : BaseLexer
    cached = @@lexer_cache[name]?
    return cached if cached
    language, root = name.split("+", 2)
    lexer = DelegatingLexer.new(lexer(language), lexer(root))
    @@lexer_cache[name] = lexer
    lexer
  end

  # Create a lexer instance from cached template data, caching the
  # instance itself (lexers are immutable after creation)
  private def self.create_from_template(lexer_file_name : String) : BaseLexer
    cached = @@lexer_cache[lexer_file_name]?
    return cached if cached
    @@lexer_mutex.synchronize do
      cached = @@lexer_cache[lexer_file_name]?
      return cached if cached

      template = get_or_create_template(lexer_file_name)

      # Create lexer instance with cached data
      lexer = RegexLexer.new
      lexer.config = {
        name:             template.config[:name].as(String),
        priority:         template.config[:priority].as(Float64),
        case_insensitive: template.config[:case_insensitive].as(Bool),
        dot_all:          template.config[:dot_all].as(Bool),
        not_multiline:    template.config[:not_multiline].as(Bool),
        ensure_nl:        template.config[:ensure_nl].as(Bool),
      }
      lexer.states = template.states
      @@lexer_cache[lexer_file_name] = lexer
      lexer
    end
  end

  # Get or create a lexer template with thread-safe caching
  private def self.get_or_create_template(lexer_file_name : String) : LexerTemplate
    # Fast path: template already cached (read-only access, thread-safe)
    return @@lexer_templates[lexer_file_name] if @@lexer_templates.has_key?(lexer_file_name)

    # Slow path: need to parse XML and create template (requires lock)
    @@template_mutex.synchronize do
      # Double-check in case another thread created it while we waited
      return @@lexer_templates[lexer_file_name] if @@lexer_templates.has_key?(lexer_file_name)

      # Parse XML and extract only the static data
      xml = LexerFiles.get("/#{lexer_file_name}.xml").gets_to_end
      template = parse_xml_to_template(xml)
      @@lexer_templates[lexer_file_name] = template
      template
    end
  end

  # Parse XML and extract only static data (no stateful objects)
  private def self.parse_xml_to_template(xml : String) : LexerTemplate
    lexer_node = XML.parse(xml).first_element_child
    raise Exception.new("Invalid lexer XML") unless lexer_node

    # Extract config
    config = extract_config(lexer_node)

    # Extract states and rules (static data only)
    states = extract_states(lexer_node, config)

    LexerTemplate.new(config, states)
  end

  # Extract configuration from XML node
  private def self.extract_config(lexer_node : XML::Node) : Hash(Symbol, String | Bool | Float64)
    config_node = lexer_node.children.find { |node| node.name == "config" }
    return {
      :name             => "",
      :priority         => 0.0,
      :not_multiline    => false,
      :dot_all          => false,
      :case_insensitive => false,
      :ensure_nl        => false,
    } unless config_node

    {
      :name             => xml_to_s(config_node, name) || "",
      :priority         => xml_to_f(config_node, priority) || 0.0,
      :not_multiline    => xml_to_s(config_node, not_multiline) == "true",
      :dot_all          => xml_to_s(config_node, dot_all) == "true",
      :case_insensitive => xml_to_s(config_node, case_insensitive) == "true",
      :ensure_nl        => xml_to_s(config_node, ensure_nl) == "true",
    }
  end

  # Extract states and rules from XML node
  private def self.extract_states(lexer_node : XML::Node, config : Hash(Symbol, String | Bool | Float64)) : Hash(String, State)
    states = {} of String => State

    rules_node = lexer_node.children.find { |node| node.name == "rules" }
    return states unless rules_node

    rules_node.children.select { |node| node.name == "state" }.each do |state_node|
      state = State.new
      state.name = state_node["name"]

      if states.has_key?(state.name)
        raise Exception.new("Duplicate state: #{state.name}")
      end

      # Extract rules from this state
      state_node.children.select { |node| node.name == "rule" }.each do |rule_node|
        rule = create_rule_from_node(rule_node, config)
        state.rules << rule if rule
      end

      states[state.name] = state
    end

    states
  end

  # Create a rule from XML node (factory method)
  private def self.create_rule_from_node(rule_node : XML::Node, config : Hash(Symbol, String | Bool | Float64)) : BaseRule?
    pattern = rule_node["pattern"]?

    if pattern
      Rule.new(rule_node,
        multiline: !config[:not_multiline],
        dotall: config[:dot_all],
        ignorecase: config[:case_insensitive])
    else
      if rule_node.first_element_child.try &.name == "include"
        IncludeStateRule.new(rule_node)
      else
        UnconditionalRule.new(rule_node)
      end
    end
  end

  # Return a list of all lexer names accepted by Tartrazine.lexer
  def self.lexers : Array(String)
    LexerFiles.files.map(&.path)
      .select(&.ends_with?(".xml"))
      .map { |path| File.basename(path, ".xml") }
      .push("crystal")
      .sort!
  end

  # Return file extensions for a specific lexer by name
  def self.lexer_extensions(lexer_name : String) : Array(String)
    lexer = lexer(lexer_name)
    lexer.extensions
  end

  # A token, the output of the tokenizer
  alias Token = NamedTuple(type: String, value: String)

  abstract class BaseTokenizer
  end

  class Tokenizer < BaseTokenizer
    include Iterator(Token)
    property lexer : BaseLexer
    property text : Bytes
    property pos : Int32 = 0
    @dq = Deque(Token).new
    property state_stack = ["root"]

    # States created on the fly for this tokenization only (Combined),
    # kept off the shared lexer template to avoid unbounded growth
    @local_states = {} of String => State

    # Memoized Combined states for this tokenization, keyed by the
    # combined state names, so repeated Combined actions with the
    # same states reuse the merged rules
    @combined_states = {} of Array(String) => State

    # Get (or create once) the merged state for a Combined action
    def combined_state(names : Array(String)) : State
      cached = @combined_states[names]?
      return cached if cached
      new_state = names.map { |name| state_for(name) }.reduce { |state1, state2| state1 + state2 }
      remember_state(new_state)
      @combined_states[names] = new_state
      new_state
    end

    # Resolve a state by name, preferring locally created states.
    # Results are cached because lookups happen on every step.
    def state_for(name : String) : State
      cached = @local_states[name]?
      return cached if cached
      state = @lexer.states[name]?
      raise Exception.new("Unknown state: #{name}") if state.nil?
      @local_states[name] = state
      state
    end

    # Keep a tokenization-local state so it does not leak into the
    # shared lexer template
    def remember_state(state : State)
      @local_states[state.name] = state
    end

    def initialize(@lexer : BaseLexer, text : String, secondary = false)
      # Rule regexes are compiled with UTF mode and NO_UTF_CHECK, which
      # is undefined behavior on invalid UTF-8: scrub it once so
      # matching is always valid
      text = text.scrub
      # Respect the `ensure_nl` config option
      if text.size > 0 && text[-1] != '\n' && @lexer.config[:ensure_nl] && !secondary
        text += "\n"
      end
      @text = text.to_slice
    end

    def next : Iterator::Stop | Token
      while @dq.size == 0
        return stop if pos == @text.size
        step
      end
      @dq.shift
    end

    private def step : Nil
      matched = false
      rules = state_for(@state_stack.last).rules
      rules.each do |rule|
        matched, new_pos, new_tokens = rule.match(@text, @pos, self)
        if matched
          @pos = new_pos
          split_tokens(new_tokens).each { |token| @dq << token }
          break
        end
      end
      if !matched
        if @text[@pos] == 10u8
          @dq << {type: "Text", value: "\n"}
          @state_stack = ["root"]
          @pos += 1
        else
          # Consume a whole UTF-8 codepoint so multi-byte characters
          # don't get split into invalid single-byte Error tokens.
          char_size = utf8_char_size(@text[@pos])
          char_bytes = @text[@pos, char_size]
          # Malformed sequences are never split, invalid bytes are just dropped
          error_value = String.new(char_bytes, "UTF-8", invalid: :skip)
          @dq << {type: "Error", value: error_value}
          @pos += char_size
        end
      end
    end

    # Number of bytes of the UTF-8 codepoint that starts with the given byte.
    # Malformed lead bytes are treated as single-byte sequences.
    private def utf8_char_size(lead_byte : UInt8) : Int32
      size = case lead_byte
             when 0x00..0x7f then 1
             when 0xc0..0xdf then 2
             when 0xe0..0xef then 3
             when 0xf0..0xf7 then 4
             else                 1
             end
      Math.min(size, @text.size - pos)
    end

    # If a token contains a newline, split it into two tokens
    def split_tokens(tokens : Array(Token)) : Array(Token)
      needs_split = tokens.any?(&.[:value].byte_index('\n'.ord))
      return tokens unless needs_split

      split_tokens = [] of Token
      tokens.each do |token|
        bytes = token[:value].to_slice
        start = 0
        # Each newline ends a token that includes it; a final
        # (possibly empty) token always follows, matching the
        # previous value.split("\n") behavior
        while index = bytes.index('\n'.ord, start)
          split_tokens << {type: token[:type], value: String.new(bytes[start, index + 1 - start])}
          start = index + 1
        end
        split_tokens << {type: token[:type], value: String.new(bytes[start, bytes.size - start])}
      end
      split_tokens
    end
  end

  alias BaseLexer = Lexer

  abstract class Lexer
    property config = {
      name:             "",
      priority:         0.0,
      case_insensitive: false,
      dot_all:          false,
      not_multiline:    false,
      ensure_nl:        false,
    }
    property states = {} of String => State

    def tokenizer(text : String, secondary = false) : BaseTokenizer
      Tokenizer.new(self, text, secondary)
    end

    # Return the file extensions supported by this lexer
    # Override in subclasses to provide specific extensions
    def extensions : Array(String)
      [] of String
    end
  end

  # This implements a lexer for Pygments RegexLexers as expressed
  # in Chroma's XML serialization.
  #
  # For explanations on what actions and states do
  # the Pygments documentation is a good place to start.
  # https://pygments.org/docs/lexerdevelopment/
  class RegexLexer < BaseLexer
    # Collapse consecutive tokens of the same type for easier comparison
    # and smaller output
    def self.collapse_tokens(tokens : Array(Tartrazine::Token)) : Array(Tartrazine::Token)
      result = [] of Tartrazine::Token
      # Merge same-type runs via a builder so long runs don't
      # reallocate a concatenated string per token
      accumulated = String::Builder.new
      accumulating = false
      accumulated_type = ""
      tokens.each do |token|
        next if token[:value] == ""
        if accumulating && accumulated_type == token[:type]
          accumulated << token[:value]
          next
        end
        result << {type: accumulated_type, value: accumulated.to_s} if accumulating
        accumulated = String::Builder.new
        accumulated_type = token[:type]
        accumulated << token[:value]
        accumulating = true
      end
      result << {type: accumulated_type, value: accumulated.to_s} if accumulating
      result
    end

    # Return file extensions for this XML lexer. The XML parse is
    # memoized per lexer name since extensions never change.
    @@extensions_cache = {} of String => Array(String)

    def extensions : Array(String)
      return [] of String unless @config[:name]?

      cached = @@extensions_cache[@config[:name]]?
      return cached if cached
      @@extensions_cache[@config[:name]] = parse_extensions
    end

    private def parse_extensions : Array(String)
      # Try to find the XML file for this lexer

      lexer_file_name = LEXERS_BY_NAME[@config[:name]]?
      return [] of String unless lexer_file_name

      xml_content = LexerFiles.get("/#{lexer_file_name}.xml").gets_to_end
      xml = XML.parse(xml_content)

      xml.first_element_child.try do |root|
        root.children.find { |node| node.name == "config" }.try do |config|
          config.children.select { |node| node.name == "filename" }.map(&.content.to_s)
        end
      end || [] of String
    rescue
      [] of String
    end

    def self.from_xml(xml : String) : Lexer
      l = RegexLexer.new
      lexer = XML.parse(xml).first_element_child
      if lexer
        config = lexer.children.find do |node|
          node.name == "config"
        end
        if config
          l.config = {
            name:             xml_to_s(config, name) || "",
            priority:         xml_to_f(config, priority) || 0.0,
            not_multiline:    xml_to_s(config, not_multiline) == "true",
            dot_all:          xml_to_s(config, dot_all) == "true",
            case_insensitive: xml_to_s(config, case_insensitive) == "true",
            ensure_nl:        xml_to_s(config, ensure_nl) == "true",
          }
        end

        rules = lexer.children.find do |node|
          node.name == "rules"
        end
        if rules
          # Rules contains states 🤷
          rules.children.select do |node|
            node.name == "state"
          end.each do |state_node|
            state = State.new
            state.name = state_node["name"]
            if l.states.has_key?(state.name)
              raise Exception.new("Duplicate state: #{state.name}")
            else
              l.states[state.name] = state
            end
            # And states contain rules 🤷
            state_node.children.select do |node|
              node.name == "rule"
            end.each do |rule_node|
              case rule_node["pattern"]?
              when nil
                if rule_node.first_element_child.try &.name == "include"
                  rule = IncludeStateRule.new(rule_node)
                else
                  rule = UnconditionalRule.new(rule_node)
                end
              else
                rule = Rule.new(rule_node,
                  multiline: !l.config[:not_multiline],
                  dotall: l.config[:dot_all],
                  ignorecase: l.config[:case_insensitive])
              end
              state.rules << rule
            end
          end
        end
      end
      l
    end
  end

  # A lexer that takes two lexers as arguments. A root lexer
  # and a language lexer. Everything is scalled using the
  # language lexer, afterwards all `Other` tokens are lexed
  # using the root lexer.
  #
  # This is useful for things like template languages, where
  # you have Jinja + HTML or Jinja + CSS and so on.
  class DelegatingLexer < Lexer
    property language_lexer : BaseLexer
    property root_lexer : BaseLexer

    def initialize(@language_lexer : BaseLexer, @root_lexer : BaseLexer)
    end

    def tokenizer(text : String, secondary = false) : DelegatingTokenizer
      DelegatingTokenizer.new(self, text, secondary)
    end
  end

  # This Tokenizer works with a DelegatingLexer. It first tokenizes
  # using the language lexer, and "Other" tokens are tokenized using
  # the root lexer.
  class DelegatingTokenizer < BaseTokenizer
    include Iterator(Token)
    @dq = Deque(Token).new
    @language_tokenizer : BaseTokenizer

    def initialize(@lexer : DelegatingLexer, text : String, secondary = false)
      # Respect the `ensure_nl` config option
      if text.size > 0 && text[-1] != '\n' && @lexer.config[:ensure_nl] && !secondary
        text += "\n"
      end
      @language_tokenizer = @lexer.language_lexer.tokenizer(text, true)
    end

    def next : Iterator::Stop | Token
      loop do
        return @dq.shift if @dq.size > 0
        token = @language_tokenizer.next
        if token.is_a? Iterator::Stop
          return stop
        elsif token.as(Token).[:type] == "Other"
          root_tokenizer = @lexer.root_lexer.tokenizer(token.as(Token).[:value], true)
          root_tokenizer.each do |root_token|
            @dq << root_token
          end
        else
          @dq << token.as(Token)
        end
      end
    end
  end

  # A Lexer state. A state has a name and a list of rules.
  # The state machine has a state stack containing references
  # to states to decide which rules to apply.
  struct State
    property name : String = ""
    property rules = [] of BaseRule

    def +(other : State)
      new_state = State.new
      new_state.name = Random.base58(8)
      new_state.rules = rules + other.rules
      new_state
    end
  end

  class CustomCrystalHighlighter < Crystal::SyntaxHighlighter
    @tokens = [] of Token

    def highlight(text)
      super
    rescue Crystal::SyntaxException
      # Fallback to Ruby highlighting
      @tokens = Tartrazine.lexer("ruby").tokenizer(text).to_a
    end

    def render_delimiter(&block)
      @tokens << {type: "LiteralString", value: block.call.to_s}
    end

    def render_interpolation(&block)
      @tokens << {type: "LiteralStringInterpol", value: "\#{"}
      @tokens << {type: "Text", value: block.call.to_s}
      @tokens << {type: "LiteralStringInterpol", value: "}"}
    end

    def render_string_array(&block)
      @tokens << {type: "LiteralString", value: block.call.to_s}
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def render(type : TokenType, value : String)
      case type
      when .comment?
        @tokens << {type: "Comment", value: value}
      when .number?
        @tokens << {type: "LiteralNumber", value: value}
      when .char?
        @tokens << {type: "LiteralStringChar", value: value}
      when .symbol?
        @tokens << {type: "LiteralStringSymbol", value: value}
      when .const?
        @tokens << {type: "NameConstant", value: value}
      when .string?
        @tokens << {type: "LiteralString", value: value}
      when .ident?
        @tokens << {type: "NameVariable", value: value}
      when .keyword?, .self?
        @tokens << {type: "NameKeyword", value: value}
      when .primitive_literal?
        @tokens << {type: "Literal", value: value}
      when .operator?
        @tokens << {type: "Operator", value: value}
      when Crystal::SyntaxHighlighter::TokenType::DELIMITED_TOKEN, Crystal::SyntaxHighlighter::TokenType::DELIMITER_START, Crystal::SyntaxHighlighter::TokenType::DELIMITER_END
        @tokens << {type: "LiteralString", value: value}
      else
        @tokens << {type: "Text", value: value}
      end
    end
  end

  class CrystalTokenizer < Tartrazine::BaseTokenizer
    include Iterator(Token)
    @hl = CustomCrystalHighlighter.new
    @lexer : BaseLexer
    @iter : Iterator(Token)

    # delegate next, to: @iter

    def initialize(@lexer : BaseLexer, text : String, secondary = false)
      # Rule regexes are compiled with UTF mode and NO_UTF_CHECK, which
      # is undefined behavior on invalid UTF-8: scrub it once so
      # matching is always valid
      text = text.scrub
      # Respect the `ensure_nl` config option
      if text.size > 0 && text[-1] != '\n' && @lexer.config[:ensure_nl] && !secondary
        text += "\n"
      end
      # Just do the tokenizing
      @hl.highlight(text)
      @iter = @hl.@tokens.each
    end

    def next : Iterator::Stop | Token
      @iter.next
    end
  end

  class CrystalLexer < BaseLexer
    def tokenizer(text : String, secondary = false) : BaseTokenizer
      CrystalTokenizer.new(self, text, secondary)
    end

    # Return file extensions for Crystal lexer
    def extensions : Array(String)
      ["*.cr"]
    end
  end
end
