lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'splog/version'
require 'date'
require 'optparse'
require 'awesome_print'
require 'yaml'
require 'json'
require 'enumerator'

module Splog

  class LogParser
    attr_accessor :config, :pattern_name, :options

    def initialize
      # Yaml config options
      @config = {}

      # Command line options
      @options = {
        :append => true
      }

      # Defines how each line is split apart with the array of regex
      @pattern_name = nil
      @pattern = nil

      # Defines how each regex group is mapped to a data type
      @mapping_name = nil
      @mapping = nil

    end

    def load_dot_file
      # yml config
      dot_file = @options[:dot_file_name] || '~/.splog.yml'
      puts "Loading dot_file from #{dot_file}"
      begin
        prop_list = YAML.load_file(File.expand_path(dot_file))
        prop_list.each do |key, value|
          @config[key] = value
        end
      rescue => detail
        #$stderr.puts $!
        #detail.backtrace.each { |e| $stderr.puts e}
        $stderr.puts 'Unable to find ~/.splog.yml'
      end
    end

    # Attempt to parse an int or return 0
    def parse_int(the_input)
      output = 0
      begin
        output = the_input.to_i
      rescue => detail
        nil
      end
      output
    end

    # Attempt to parse a float or return 0
    def parse_float(the_input)
      output = 0
      begin
        output = the_input.to_f
      rescue => detail
        nil
      end
      output
    end

    # Attempt to parse a datetime or return None
    def parse_datetime(the_input, the_format=nil)
      output = the_input
      begin
        output = the_format ? DateTime.strptime(the_input, the_format) : DateTime.parse(the_input)
      rescue => detail
        nil
      end
      output
    end

    def parse_line(line, opts={})
      res = {}
      parts = opts[:parts] || @config[@pattern_name]['regex']
      begin
        #pattern = re.compile(r'\s+'.join(parts)+r'\s*\Z')
        pattern = @config[@pattern_name].has_key?('delim') ? "\\s*#{parts.join(@config[@pattern_name]['delim'])}\\s*" : "\\s*#{parts.join()}\\s*"
        #ap pattern
        # MULTILINE to match the \n chars
        #Regexp::MULTILINE | Regexp::IGNORECASE
        r = Regexp.new(pattern, Regexp::MULTILINE)
        m = r.match(line)
        res = {}
        if m
          m.names.each do |group_name|
            k = group_name
            v = m[k]
            # print("k: {}, v: {}".format(k, v))
            if @mapping and @mapping.has_key?(k)
              # print("self.mapping[k]: %s" % self.mapping[k])
              if ['Int', 'Integer'].include? @mapping[k]['data_type']
                res[k] = parse_int(m[k])
              elsif ['Float'].include? @mapping[k]['data_type']
                res[k] = parse_float(m[k])
              elsif ['DateTime'].include? @mapping[k]['data_type']
                res[k] = parse_datetime(m[k], @mapping[k]['format'])
              end
            else
              res[k] = v
            end
          end
        end
      rescue => detail
        $stderr.puts $!
        detail.backtrace.each { |e| $stderr.puts e}
      end
      # Return nil if the hash hasn't been populated
      res.length == 0 ? nil : res
    end

    # Takes an enum and iterates over it with logic to parse the log lines based on the configuration
    def parse(enum_ref)
      e = Enumerator.new do |y|
        # Defines the current parsed line.  Next linese can be added to this one potentially based on a key
        current_working_line = nil
        parsed_line = nil
        begin
          while enum_ref
            line = enum_ref.next
            parsed_line = parse_line(line)

            next_line = enum_ref.peek
            # Pass in the 'matched_append_regex' if it exists so the next line can be evaluated in this context
            parsed_next_line = @config[@pattern_name]['matched_append_regex'].nil? ? parse_line(next_line) : parse_line(next_line, {:parts => @config[@pattern_name]['matched_append_regex']})

            ############################################################################################################
            # If the next line matches the matched_append_regex
            ############################################################################################################
            if parsed_next_line and @config[@pattern_name]['matched_append_regex']

              # If the current_working_line does not yet exist, set it to the latest parsed line
              if current_working_line.nil? and parsed_line
                current_working_line = parsed_line
              end

              # Add to the matched_append_keyname_source from the matched_append_keyname_dest
              current_working_line[@config[@pattern_name]['matched_append_keyname_source']] << parsed_next_line[@config[@pattern_name]['matched_append_keyname_source']]

              # fast forward the enum one click to account for the peek
              enum_ref.next

              # Read until StopIteration or the matched_append_regex no longer matches
              while true
                line = enum_ref.next
                parsed_line = @config[@pattern_name]['matched_append_regex'].nil? ? nil : parse_line(line, {:parts => @config[@pattern_name]['matched_append_regex']})
                if parsed_line
                  current_working_line[@config[@pattern_name]['matched_append_keyname_source']] << parsed_line[@config[@pattern_name]['matched_append_keyname_source']]
                else
                  break
                end
              end
            ############################################################################################################
            # Otherwise if the next line is nil but the parsed line matched and we are appending
            ############################################################################################################
            elsif parsed_line and parsed_next_line.nil? and @options[:append]
              # If the current_working_line does not yet exist, set it to the latest parsed line
              if current_working_line.nil? and parsed_line
                current_working_line = parsed_line
              end

              # Read until StopIteration or a new parsed line is found
              while true
                line = enum_ref.next
                parsed_line = parse_line(line)
                if parsed_line.nil? and @config[@pattern_name]['unmatched_append_key_name']
                  current_working_line[@config[@pattern_name]['unmatched_append_key_name']] << line
                else
                  break
                end
              end
            ############################################################################################################
            # Otherwise just your average joe matched line
            ############################################################################################################
            elsif parsed_line
              y << parsed_line
            end
          end
        rescue StopIteration => e
          #if both current_working_line and parsed line yield them both as this situation can happen when peeking forward
          # After an unmatched line
          if current_working_line and parsed_line
            y << current_working_line
            y << parsed_line
          # Yield point for a successfully parsed line
          elsif current_working_line
            y << current_working_line
          else
            y << parsed_line
          end
        end
      end
    end

    def read_input(the_input)
      # Split the input by lines, chomp them, and return an enum
      #the_input.lines.map(&:chomp).to_enum
      the_input.lines.to_enum
    end

    def read_log_file(file_name)
      File.open(file_name).to_enum
    end

    def cli(args=nil)
      options = {
          :append => true
      }
      opts = OptionParser.new do |parser|

        parser.separator ''
        parser.separator 'Parse logs in arbitrary formats defined in ~/.splog.yml:'

        parser.on('-p', '--pattern STR', 'Mapping name defined in ~/.splog.yml') do |setting|
          options[:pattern_name] = setting
        end

        parser.on('-f', '--file PATH', 'File to parse') do |setting|
          options[:file_name] = setting ? File.expand_path(setting) : setting
        end

        parser.on('-c', '--config PATH', 'Optional dot file path.  Defaults to ~/.splog.yml') do |setting|
          options[:dot_file_name] = setting ? File.expand_path(setting) : setting
        end

        parser.on('--no-append', "When a line doesn't match the regex, don't append it to the previously matched line. The default is to append.") do |setting|
          options[:append] = setting.nil?
        end

        parser.on('-k', '--key [STR]', 'The unique business key to use as the database id.  If none specified an automatic id will be generated.') do |setting|
          options[:key] = setting
        end

        parser.on("-d", "--database [STR]", "Specify a database reference defined in ~/.splog.yml to write to") do |ext|
          options[:db_ref_name] = ext || nil
        end

        parser.on_tail('-h', '--help', '--usage', 'Show this usage message and quit.') do |setting|
          puts parser.help
          exit
        end


        #parser.on_tail("-v", "--version", "Show version information about this program and quit.") do
        #  puts "Splog v1.0.0"
        #  exit
        #end
      end

      opts.parse!(args || ARGV)
      @options = options
      #ap options

      # At this point the options are loaded so load the dot file before continuing so the config can be properly
      # Loaded from the dot file and further options determined
      load_dot_file

      set_pattern(options)
      set_mapping(options)

      #ap @mapping
      read_log_file(options[:file_name])
    end

    def set_pattern(options)
      @pattern_name = options[:pattern_name]
      @pattern = @config[options[:pattern_name]]['regex']
      #@pattern_name = options['pattern_name']
      #@pattern = @config[options['pattern_name']]['regex']
    end

    def set_mapping(options)
      tmp = {}
      @config[options[:pattern_name]]['mapping'].each { |x| tmp[x['name']] = x } unless @config[options[:pattern_name]]['mapping'].nil?
      @mapping = tmp
    end
  end
end
