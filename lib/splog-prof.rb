require 'splog'
require 'ruby-prof'

# Profile the code
RubyProf.start
parser = Splog::LogParser.new
parser.cli(ARGV)
result = RubyProf.stop

# Print a flat profile to text
printer = RubyProf::FlatPrinter.new(result)
printer.print(STDOUT)
