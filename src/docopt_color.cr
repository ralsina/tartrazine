require "./tartrazine"
require "docopt"

# Colored docopt help through tartrazine, in-process.
#
#     require "docopt"
#     require "tartrazine/docopt_color"
#
#     Docopt.use_tartrazine_color  # or use_tartrazine_color("gruvbox-dark")
#     options = Docopt.docopt(doc, ARGV)
#
# The gating lives in docopt (terminals only, NO_COLOR respected);
# this side just implements the hook with our docopt lexer.

module Docopt
  # Install a colorizer that runs text through tartrazine's docopt
  # lexer and terminal formatter, with *theme* (default-dark by
  # default).
  def self.use_tartrazine_color(theme : String = "default-dark") : Nil
    lexer = Tartrazine.lexer(name: "docopt")
    formatter = Tartrazine::Ansi.new
    formatter.theme = Tartrazine.theme(theme)
    self.colorizer = ->(text : String) { formatter.format(text, lexer) }
  end
end
