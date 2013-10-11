lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'splog/version'
require 'date'
require 'optparse'
require 'yaml'
require 'json'
require 'enumerator'
require 'mongo'

include Mongo

module Splog

  class LogParser
    attr_accessor :config, :pattern_name, :options

    # Define the accessors to mongo, all db writes happen to the configured @coll
    attr_reader :client, :coll

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

      # Define the mongo client, nil by default until first persist to log entry
      @client = nil

    end

    # http://stackoverflow.com/questions/6461812/creating-an-md5-hash-of-a-number-string-array-or-hash-in-ruby
    def createsig(body)
      Digest::MD5.hexdigest( sigflat body )
    end

    def sigflat(body)
      if body.class == Hash
        arr = []
        body.each do |key, value|
          arr << "#{sigflat key}=>#{sigflat value}"
        end
        body = arr
      end
      if body.class == Array
        str = ''
        body.map! do |value|
          sigflat value
        end.sort!.each do |value|
          str << value
        end
      end
      if body.class != String
        body = body.to_s << body.class.to_s
      end
      body
    end

    def persist_log_entry(parsed_line)
      begin
        if @client.nil? and @options[:db_ref_name]
          db_ref_name = @options[:db_ref_name]
          host = @config['db_refs'][db_ref_name]['host'] || '127.0.0.1'
          port = @config['db_refs'][db_ref_name]['port'] || 27107
          user = @config['db_refs'][db_ref_name]['user'] || nil
          pass = @config['db_refs'][db_ref_name]['pass'] || nil
          db = @options[:mongo_db] || @config['db_refs'][db_ref_name]['db']
          coll = @options[:mongo_coll] || @config['db_refs'][db_ref_name]['collection']

          @client = MongoClient.new(host, port, :pool_size => 1)
          db = @client.db(db)
          auth = nil
          if user and user != '' && pass
            auth = db.authenticate(user, pass)
            #p "Authentication to mongo returned: #{auth}"
          end
          @coll = db[coll]
        end

        # Assuming the above is successfull write to the collection, otherwise silently do nothing
        if @client and @coll
          # If an _id exists upsert the doc
          if parsed_line.has_key?('_id')
            @coll.update({:_id => parsed_line['_id']}, parsed_line, opts = {:upsert => true})
          # Otherwise insert the parsed_line which will cause a Mongo specific _id to be generated
          else
            @coll.insert(parsed_line)
          end
        end
      rescue => detail
        $stderr.puts $!
      end
    end

    def load_dot_file
      # yml config
      dot_file = @options[:dot_file_name] || '~/.splog.yml'
      #puts "Loading dot_file from #{dot_file}"
      begin
        prop_list = YAML.load_file(File.expand_path(dot_file))
        prop_list.each do |key, value|
          @config[key] = value
        end
      rescue => detail
        $stderr.puts "Unable to find or read #{dot_file}\n"
        $stderr.puts $!
        exit
      end
    end

    def set_pattern(options)
      @pattern_name = options[:pattern_name]
      begin
        @pattern = @config[options[:pattern_name]]['regex']
      rescue => detail
        puts "No pattern matching '#{options[:pattern_name]}' found.  Please choose another name or define this pattern in the your .splog.yaml"
        exit
      end
    end

    def set_mapping(options)
      begin
        tmp = {}
        @config[options[:pattern_name]]['mapping'].each { |x| tmp[x['name']] = x } unless @config[options[:pattern_name]]['mapping'].nil?
        @mapping = tmp
      rescue => detail
        puts 'Unable to read the mapping in your .splog.yaml configuration.  Please reference https://github.com/engineersamuel/splog for proper formatting.'
        $stderr.puts $!
        exit
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
        # Convert the time to utc for mongo
        output = output.nil? ? nil : output.to_time.utc
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

      # If a key exists add the key to the parsed_line, This can help differentiate the log if not putting each
      # Log into a unique collection, or even then helps differentiate the logs within a collection.  Ex. if you had
      # access_log and error_log in the same collection you may want a specific key for each of those
      if @options[:key] && res && res.length != 0
        res['key'] = @options[:key]
      end

      if @options[:md5] && res && res.length != 0
        res['_id'] = createsig(res)
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
            # Pass in the 'match_forward_regex' if it exists so the next line can be evaluated in this context
            parsed_next_line = @config[@pattern_name]['match_forward_regex'].nil? ? parse_line(next_line) : parse_line(next_line, {:parts => @config[@pattern_name]['match_forward_regex']})

            ############################################################################################################
            # If the next line matches the match_forward_regex
            ############################################################################################################
            if parsed_next_line and @config[@pattern_name]['match_forward_regex']

              # If the current_working_line does not yet exist, set it to the latest parsed line
              if current_working_line.nil? and parsed_line
                current_working_line = parsed_line
              end

              # Add to the match_forward_keyname_source from the match_forward_keyname_dest
              current_working_line[@config[@pattern_name]['match_forward_keyname_source']] << parsed_next_line[@config[@pattern_name]['match_forward_keyname_source']]

              # fast forward the enum one click to account for the peek
              enum_ref.next

              # Read until StopIteration or the match_forward_regex no longer matches
              while true
                # Only peek here to not advance the enum unnecessarily
                sub_line = enum_ref.peek
                parsed_sub_line = @config[@pattern_name]['match_forward_regex'].nil? ? nil : parse_line(sub_line, {:parts => @config[@pattern_name]['match_forward_regex']})
                if parsed_sub_line
                  # if matched advance the enum and add the data to the current working line
                  enum_ref.next
                  current_working_line[@config[@pattern_name]['match_forward_keyname_source']] << parsed_sub_line[@config[@pattern_name]['match_forward_keyname_source']]
                else
                  # Otherwise we've reached the end of the matched pattern yield this match out
                  y << current_working_line

                  # Since that is yielded, set the current_working_line to nil so it has a fresh start for the next iter
                  current_working_line = nil
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
                # Only peek here to not advance the enum unnecessarily
                sub_line = enum_ref.peek
                parsed_sub_line = parse_line(sub_line)
                if parsed_sub_line.nil? and @config[@pattern_name]['unmatched_append_key_name']
                  # if unmatched advance the enum and add the data to the current working line
                  enum_ref.next
                  current_working_line[@config[@pattern_name]['unmatched_append_key_name']] << sub_line
                else
                  # Otherwise we've reached the end of the matched pattern yield this match out
                  y << current_working_line

                  # Since that is yielded, set the current_working_line to nil so it has a fresh start for the next iter
                  current_working_line = nil
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
          if current_working_line and parsed_line and current_working_line != parsed_line
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
        :append => true,
        :output => 'stdout',
        :md5 => true  # By defualt md5 the hash as the unique identifier
      }
      opts = OptionParser.new do |parser|
        parser.banner = 'Usage: splog [options]'

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

        parser.on('-o', '--output [stdout|filename]', 'Defaults to stdout, if specifying just -o then defaults to no standard output.') do |setting|
          options[:output] = setting ? setting : nil
        end

        parser.on('--no-append', "When a line doesn't match the regex, don't append it to the previously matched line. The default is to append.") do |setting|
          options[:append] = setting.nil?
        end

        parser.on('-k', '--key STR', 'The unique business key to use as the database id.  If none specified an automatic id will be generated.') do |setting|
          options[:key] = setting
        end

        parser.on('-d', '--database STR', 'Specify a database reference defined in ~/.splog.yml to write to') do |ext|
          options[:db_ref_name] = ext || nil
        end

        parser.on('--db STR', 'Override the Mongo database defined in ~/.splog.yml') do |ext|
          options[:mongo_db] = ext || nil
        end

        parser.on('--coll STR', 'Override the Mongo collection defined in ~/.splog.yml') do |ext|
          options[:mongo_coll] = ext || nil
        end

        parser.on('--[no-]md5', 'When saving to mongo md5 the hash and set that to the _id.  This means repeated parses of the same log file should be idempotent.  Otherwise there will be duplicated lines in the database.') do |ext|
          p ext
          options[:md5] = ext  # if -m then == true
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

      begin
        if args and not args.length == 0
          opts.parse!(args)
        else
          ARGV << '-h' if ARGV.size == 0
          opts.parse!(ARGV)
        end
      rescue OptionParser::ParseError
        $stderr.print "Error: #{$!}\n"
        exit
      end

      if (options[:file_name] and options[:pattern_name]) or not $stdin.tty?
        @options = options

        # At this point the options are loaded so load the dot file before continuing so the config can be properly
        # Loaded from the dot file and further options determined
        load_dot_file

        set_pattern(options)
        set_mapping(options)

        # Get the enum from the file
        e = nil
        if options[:file_name] and options[:pattern_name]
          e = read_log_file(options[:file_name])
        # Or stdin otherwise
        elsif not $stdin.tty?
          e = $stdin.to_enum
        else
          $stderr.print 'Please either specify a -f FILENAME or pipe content to splog.'
          exit
        end

        # outputting to stdout simply prints 1 parsed line per line
        if options[:output] == 'stdout'
          # Parse each line of the file through the log parser
          parse(e).each do |parsed_line|
            if options[:db_ref_name]
              persist_log_entry(parsed_line)
            end

            # Then write to stdout
            $stdout.write parsed_line.to_s
            $stdout.write "\n"
          end

        # outputting to json will construct a valid json array so you can do something like splog ... | prettyjson
        elsif options[:output] == 'json'
          # Parse each line of the file through the log parser
          $stdout.write '['
          pe = parse(e)
          begin
            while true
              parsed_line = pe.next

              if options[:db_ref_name]
                persist_log_entry(parsed_line)
              end

              # Then write to stdout
              $stdout.write parsed_line.to_json
              $stdout.write ',' unless pe.peek.nil?
            end
          rescue => detail
            nil
          end
          # If a \n is not written a % shows on the console output thus breaking the json array
          $stdout.write "]\n"

        # outputting nothing if -o given with no value.  Useful for perf testing mainly
        elsif options[:output] == nil
          pe = parse(e)
          begin
            while true
              parsed_line = pe.next
              if options[:db_ref_name]
                persist_log_entry(parsed_line)
              end
            end
          rescue => detail
            nil
          end
        # Otherwise return the enumerator back up to be iterated over either in testing or in a program requiring this code
        else
          return read_log_file(options[:file_name])
        end
      else
        $stderr.print "Please either specify a -f FILENAME or pipe in content\n"
      end
    end
  end
end
