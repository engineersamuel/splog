# Splog -- Simple Log Parsing

Splog allows you to define simple regular expressions in a yaml file that determine how to parse each line of any log file.

There are many similar solutions out in the wild but no solution that was simple and concise and could be configured to work with most any logfile.  Most solutions are locked into a particular format, like Apache logs, or behind a paywall.

Splog solves this by allowing you to define regular expressions to split apart a line, any line, from any file, into a hash and even mapping the regular expression groups to various types like a DateTime or an Integer.

Splog also provides a feature that few other existing solutions do, and that is what I'll call fast forward parsing of a log.  Let's say you have a Java app server log that has exceptions.  Those exceptions should roll up into the originating log line.  That can be easily configured by setting a match forward regular expression.  

By default unmatched lines are rolled into the previously matche line.  This also passively solves the issue of multiline log files which really should be one log entry with multiple lines.


## Installation

Add this line to your application's Gemfile:

    gem 'splog'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install splog

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

#### Examples of executing the bin/splog in development

    ruby -Ilib ./bin/splog
    ruby -Ilib ./bin/splog -p apache_common -f test/examples/apache/simple_access_log -o json
    ruby -Ilib ./bin/splog -p apache_common -f test/examples/apache/simple_access_log -o json | prettyjson
    ruby -Ilib ./bin/splog -p jboss_log4j_common -f test/examples/jboss/multiline_match_server.log -c test/examples/jboss/.splog.yml -o json | prettyjson

#### Executing the spec tests in dev

    bundle exec rspec test

#### A few performance measurements

Note that everything is done in a streaming manner with Ruby Enumerators.  No file is ever read completely.  At most a file is read two lines at a time.  The memory requirements should be minimal due to this.

Parsing a 1m JBoss log to json:

    time ruby -Ilib ./bin/splog -p jboss_log4j_common -f ./server.log -o json  
    2.99s user 0.04s system 88% cpu 3.437 total

Parsing a 1m JBoss log to with no writing to stdout:

    time ruby -Ilib ./bin/splog -p jboss_log4j_common -f ./server.log -o 
    2.81s user 0.02s system 99% cpu 2.834 total

Parsing a 45m Apache access log:

    time ruby -Ilib ./bin/splog -p apache_common -f ./access_log -o
    44.49s user 0.10s system 99% cpu 44.596 total

## Dependencies

Splog has been tested on ruby 1.9 but is probably compatible with 1.8+
