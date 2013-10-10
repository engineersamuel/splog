# Splog

TODO: Write a gem description


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

## Dependencies

Splog has been tested on ruby 1.9 but is probably compatible with 1.8+
