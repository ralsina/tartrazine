require "xml"
require "log"

module Tartrazine
  # Abstract base class for different lexer loading strategies
  abstract class LexerLoader
    abstract def load_lexer_xml(name : String) : String?
    abstract def available_lexers : Array(String)
    abstract def has_lexer?(name : String) : Bool

    # Default implementation for checking availability
    def has_lexer?(name : String) : Bool
      available_lexers.includes?(name)
    end
  end

  # Load lexers from the baked file system (current behavior)
  class BakedLexerLoader < LexerLoader
    def initialize(@fallback : LexerLoader? = nil)
    end

    def load_lexer_xml(name : String) : String?
      begin
        LexerFiles.get("/#{name}.xml").gets_to_end
      rescue ex : BakedFileSystem::NoSuchFileError
        @fallback.try(&.load_lexer_xml(name))
      end
    end

    def available_lexers : Array(String)
      file_map = LexerFiles.files.map(&.path)
      LEXERS_BY_NAME.keys.select { |k| file_map.includes?("/#{k}.xml") }
    end
  end

  # Load lexers from the filesystem
  class FileLexerLoader < LexerLoader
    def initialize(@lexer_paths : Array(String), @fallback : LexerLoader? = nil)
    end

    def load_lexer_xml(name : String) : String?
      @lexer_paths.each do |path|
        file_path = File.join(path, "#{name}.xml")
        if File.exists?(file_path)
          return File.read(file_path)
        end
      end
      @fallback.try(&.load_lexer_xml(name))
    end

    def available_lexers : Array(String)
      lexers = [] of String
      @lexer_paths.each do |path|
        if Dir.exists?(path)
          Dir.glob("#{path}/*.xml").each do |file|
            lexer_name = File.basename(file, ".xml")
            lexers << lexer_name
          end
        end
      end
      lexers.uniq
    end
  end

  # Load lexers from network requests (for WASM/browser usage)
  class NetworkLexerLoader < LexerLoader
    def initialize(@base_url : String, @fallback : LexerLoader? = nil)
    end

    def load_lexer_xml(name : String) : String?
      begin
        url = "#{@base_url.chomp('/')}/#{name}.xml"
        # This would need to be implemented based on the HTTP client available in WASM
        # For now, return fallback
        @fallback.try(&.load_lexer_xml(name))
      rescue ex
        Log.error { "Failed to load lexer #{name} from network: #{ex.message}" }
        @fallback.try(&.load_lexer_xml(name))
      end
    end

    def available_lexers : Array(String)
      # This would require a manifest or API call to get available lexers
      # For now, fallback to what's available
      @fallback.try(&.available_lexers) || [] of String
    end
  end

  # Try multiple loaders in sequence until one succeeds
  class HybridLexerLoader < LexerLoader
    def initialize(@loaders : Array(LexerLoader))
    end

    def load_lexer_xml(name : String) : String?
      @loaders.each do |loader|
        content = loader.load_lexer_xml(name)
        return content if content
      end
      nil
    end

    def available_lexers : Array(String)
      all_lexers = @loaders.flat_map(&.available_lexers)
      all_lexers.uniq
    end

    def has_lexer?(name : String) : Bool
      @loaders.any?(&.has_lexer?(name))
    end
  end

  # Simple LRU cache for parsed lexer objects
  class LexerCache
    @cache = {} of String => BaseLexer
    @access_order = [] of String
    @max_size : Int32

    def initialize(@max_size = 20)
    end

    def get(name : String, loader : LexerLoader) : BaseLexer?
      if @cache.has_key?(name)
        # Move to end (most recently used)
        @access_order.delete(name)
        @access_order << name
        return @cache[name]
      end

      # Load and parse the lexer
      xml_content = loader.load_lexer_xml(name)
      return nil unless xml_content

      lexer = RegexLexer.from_xml(xml_content)
      cache_put(name, lexer)
      lexer
    end

    private def cache_put(name : String, lexer : BaseLexer)
      # Remove oldest if cache is full
      if @access_order.size >= @max_size
        oldest = @access_order.shift
        @cache.delete(oldest)
      end

      @cache[name] = lexer
      @access_order << name
    end

    def clear
      @cache.clear
      @access_order.clear
    end

    def size
      @cache.size
    end
  end

  # Global lexer cache instance
  LEXER_CACHE = LexerCache.new

  # Global lexer loader instance - can be configured at runtime
  class_property lexer_loader : LexerLoader = BakedLexerLoader.new

  # Configure the lexer loading system
  def self.configure_lexer_loader(
    file_paths : Array(String)? = nil,
    network_url : String? = nil,
    fallback : LexerLoader? = nil
  )
    loaders = [] of LexerLoader

    # Always start with baked files as primary for performance
    base_loader = BakedLexerLoader.new(fallback)

    if file_paths && !file_paths.empty?
      file_loader = FileLexerLoader.new(file_paths, base_loader)
      loaders << file_loader
    else
      loaders << base_loader
    end

    if network_url
      network_loader = NetworkLexerLoader.new(network_url, loaders.last)
      loaders << network_loader
    end

    if loaders.size == 1
      self.lexer_loader = loaders.first
    else
      self.lexer_loader = HybridLexerLoader.new(loaders)
    end
  end
end
