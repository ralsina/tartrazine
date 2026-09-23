require "./actions"
require "./bytes_regex"
require "./formatter"
require "./lexer"
require "./rules"
require "./styles"

# These are lexer rules. They match with the text being parsed
# and perform actions, either emitting tokens or changing the
# state of the lexer.
module Tartrazine
  # This rule matches via a regex pattern

  alias Regex = BytesRegex::Regex
  alias Match = BytesRegex::Match
  alias MatchData = Array(Match)

  # A view over a snapshot of the results of one match. Safe against
  # reentrant matching (eg. usingself actions) because the offsets
  # are copied at match time.
  struct MatchDataView
    getter text : Bytes

    @bounds : Slice(Int32)
    @count : Int32

    def initialize(@text : Bytes, @bounds : Slice(Int32), count : Int32 = -1)
      # The bounds slice may be a reused scratch buffer larger than
      # this match's group count; count entries are meaningful
      @count = count < 0 ? @bounds.size : count
    end

    # View over an empty match, for rules that match unconditionally
    def initialize(@text : Bytes)
      @bounds = Slice(Int32).new(0)
      @count = 0
    end

    def size : Int32
      @count // 2
    end

    def group_start(index : Int32) : Int32
      @bounds[2 * index]
    end

    def group_end(index : Int32) : Int32
      @bounds[2 * index + 1]
    end

    # Whether the group matched anything, without copying the bytes
    def group_empty?(index : Int32) : Bool
      return true if index >= size
      start = group_start(index)
      start < 0 || start >= group_end(index)
    end

    def group(index : Int32) : Bytes
      return Bytes.empty if index >= size
      start = group_start(index)
      finish = group_end(index)
      return Bytes.empty if start < 0 || start >= finish
      @text[start...finish]
    end

    def empty? : Bool
      size == 0 || group_start(0) < 0
    end
  end

  EMPTY_TOKENS = [] of Token

  abstract class BaseRule
    abstract def match(text : Bytes, pos : Int32, tokenizer : Tokenizer) : Tuple(Bool, Int32, Array(Token))

    @actions : Array(Action) = [] of Action

    def add_actions(node : XML::Node)
      node.children.each do |child|
        next unless child.element?
        @actions << Action.new(child.name, child)
      end
    end
  end

  class Rule < BaseRule
    property pattern : Regex = Regex.new ""

    def match(text : Bytes, pos, tokenizer) : Tuple(Bool, Int32, Array(Token))
      rc = pattern.match!(text, pos, tokenizer.match_data, tokenizer.match_context)

      # No match
      return false, pos, EMPTY_TOKENS if rc == 0
      # The ovector snapshot and the token accumulator are per-tokenizer
      # scratch: rules stay immutable, so lexer templates can be shared
      # freely. Reentrant tokenization (usingself/using actions) runs on
      # its own Tokenizer and cannot touch this scratch.
      bounds = tokenizer.scratch_bounds = pattern.snapshot_ovector(rc, text.bytesize, tokenizer.match_data, tokenizer.scratch_bounds)
      view = MatchDataView.new(text, bounds, rc * 2)
      tokens = tokenizer.scratch_tokens
      tokens.clear
      @actions.each(&.emit(view, tokenizer, tokens))
      return true, view.group_end(0), tokens
    end

    def initialize(node : XML::Node, multiline, dotall, ignorecase)
      pattern = node["pattern"]?
      raise Exception.new("Missing attribute: pattern") unless pattern
      pattern = "(?m)" + pattern if multiline
      @pattern = Regex.new(pattern, multiline, dotall, ignorecase, true)
      add_actions(node)
    end
  end

  # This rule includes another state. If any of the rules of the
  # included state matches, this rule matches.
  class IncludeStateRule < BaseRule
    @state : String = ""

    # Resolved on first match: states are fixed after template parse,
    # so the name lookup only needs to happen once
    @resolved : State? = nil

    def match(text : Bytes, pos : Int32, tokenizer : Tokenizer) : Tuple(Bool, Int32, Array(Token))
      state = @resolved
      unless state
        state = tokenizer.state_for(@state)
        @resolved = state
      end
      state.rules.each do |rule|
        matched, new_pos, new_tokens = rule.match(text, pos, tokenizer)
        return true, new_pos, new_tokens if matched
      end
      return false, pos, EMPTY_TOKENS
    end

    def initialize(node : XML::Node)
      include_node = node.children.find do |child|
        child.name == "include"
      end
      @state = include_node["state"] if include_node
      add_actions(node)
    end
  end

  # This rule always matches, unconditionally
  class UnconditionalRule < BaseRule
    NO_MATCH = MatchDataView.new(Bytes.empty)

    def match(text, pos, tokenizer) : Tuple(Bool, Int32, Array(Token))
      tokens = tokenizer.scratch_tokens
      tokens.clear
      @actions.each(&.emit(NO_MATCH, tokenizer, tokens))
      return true, pos, tokens
    end

    def initialize(node : XML::Node)
      add_actions(node)
    end
  end
end
