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

If you want to persist to mongo make sure you have mongo installed: http://www.mongodb.org/downloads

## Usage

#### Getting started

* Install splog
* Create a ~/.splog.yml -- The quickest approach here is to copy from https://github.com/engineersamuel/splog/blob/master/examples/.splog.yml which has several patterns to get you started.
* Run splog on a log file!  See the the Example section below.

#### Pretty printing json

There are many libraries out there to pretty print json.  I happen to be partial to https://github.com/rafeca/prettyjson

#### Examples

If you want to test a pattern on a large log file just head that file and pipe it to splog
    
    head -n 2 path_to/some_log | splog -p pattern_name -o json | prettyjson

Parsing an Apache access log to stdout by specifying the filename directly.  The default output is stdout so no need to specify that directly

    splog -p apache_common -f path_to/access_log

Same command with piping

    cat path_to/apache_log | splog -p apache_common

And if you just want to test that the pattern is working with the log file and the log file is huge, head the results and pipe them

    head -n 10 examples/access_log | splog -p apache_common

Of course it isn't so easy to tell from stdout if the logs were parsed, I recommend json for that.  This will give you a clear visual that all logs were parsed as you expected them to be parsed

    head -n 10 examples/access_log  | splog -p apache_common -o json | prettyjson

Setting a custom key on each parsed line

    head -n 10 examples/access_log | splog -p apache_common -o json -k server_1 

Disabling the md5 on the hash

    head -n 10 examples/access_log | splog -p apache_common -o json -k server_1 --no-md5

Persisting the log to mongo.  Set -o with no arg so that no output to stdout.  The -d mongo says look in yaml for a `db_refs` key of mongo and read the database infomration to persist to.  Since the default is to hash the parsed log entry to `_id` then repeated executions of the command will result in no duplicated mongo entries.

    head -n 2 examplese/access_log | splog -p apache_common -o -k server_1 -d mongo
    monogo; use splog; db.logs.find().pretty()
    {
        "_id" : "e2304358eb62489fae8beb78d90a39a8",
        "Host" : "127.0.0.103",
        "Identity" : "-",
        "User" : "-",
        "Time" : ISODate("2013-10-03T16:31:00Z"),
        "Request" : "STATUS / HTTP/1.0",
        "Status" : 200,
        "Size" : 86,
        "Referer" : "-",
        "UserAgent" : "ClusterListener/1.0",
        "key" : "server1"
    }
    {
        "_id" : "1507c52901c51ea2cc7ca687187c82e5",
        "Host" : "127.0.0.224",
        "Identity" : "-",
        "User" : "-",
        "Time" : ISODate("2013-10-03T16:31:03Z"),
        "Request" : "STATUS / HTTP/1.0",
        "Status" : 200,
        "Size" : 86,
        "Referer" : "-",
        "UserAgent" : "ClusterListener/1.0",
        "key" : "server1"
    }



## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Building Splog in Development

`rake build`
`rake release` or `gem push`

#### Examples of executing the bin/splog in development

    ruby -Ilib ./bin/splog
    ruby -Ilib ./bin/splog -p apache_common -f test/examples/apache/simple_access_log -o json
    ruby -Ilib ./bin/splog -p apache_common -f test/examples/apache/simple_access_log -o json | prettyjson
    ruby -Ilib ./bin/splog -p jboss_log4j_common -f test/examples/jboss/multiline_match_server.log -c test/examples/jboss/.splog.yml -o json | prettyjson

#### Executing the spec tests in dev

    bundle exec rspec test

#### Profiling in dev

    head -n 10000 path_to/server.log | ruby lib/splog-prof.rb -p apache_common -o -v

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

Splog is compatible with Ruby 1.9+

## Changelog

#### 0.0.4 -- Oct 11th 2013

* Implemented a massive speed increase by transpiling the ruby regex to egrep regex and filtering all match forward regexs through open3 to perform pattern matching on.  The main regex for the current line is still ruby since egrep has no such thing as matching groups which are core to my design.  This change resulted in around a 1200% speed improvement!

#### 0.0.3 -- Oct 11th 2013

* Added verbose logging using the ruby progress bar to give clear visual progress

#### 0.0.2 -- Oct 11th 2013

* Initial release
