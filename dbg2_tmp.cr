require "./src/tartrazine"
require "docopt"
require "docopt/color"
Docopt.use_tartrazine_color
puts "set=#{!Docopt.colorizer.nil?} tty=#{STDOUT.tty?} no_color=#{ENV.has_key?("NO_COLOR")}"
puts Docopt.colorize("Usage:\n  x [-v]\n", STDOUT).inspect[0,140]
