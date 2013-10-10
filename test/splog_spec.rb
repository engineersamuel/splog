lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'splog'
require 'rspec'

RSpec.configure do |config|
  config.failure_color = :magenta
  config.tty = true
  config.color = true
end

# These can be executed with $ bundle exec rspec test
describe Splog::LogParser do
  it 'hello world sanity check' do
    'Hello World!'.should eql('Hello World!')
  end

  it 'should parse a access_log with the common pattern' do
    config = {
        'apache_common' => {
          'delim' => '\s*',
          'regex' => [
            '(?<Host>\S+)',
            '(?<Identity>\S+)',
            '(?<User>\S+)',
            '\[(?<Time>.+)\]',
            '"(?<Request>.+)"',
            '(?<Status>[0-9]+)',
            '(?<Size>\S+)',
            '"(?<Referer>.*)"',
            '"(?<UserAgent>.*)"',
          ],
          'mapping' => [
            {
              'name' => 'Time',
              'data_type' => 'DataTime',
              'format' => '%d/%b/%Y:%H:%M:%S %z'
            },
            {
              'name' => 'Status',
              'data_type' => 'Integer'
            },
            {
              'name' => 'Size',
              'data_type' => 'Integer'
            },
          ]
        }
    }
    log_example = <<-LOG
127.0.0.1 - - [25/Sep/2013:15:41:55 -0400] "ENABLE-APP / HTTP/1.0" 200 - "-" "ClusterListener/1.0"
127.0.0.2 - - [25/Sep/2013:15:42:30 -0400] "GET /mod_cluster-manager/ HTTP/1.1" 200 1360 "-" "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; WOW64; Trident/5.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C; .NET4.0E; InfoPath.3; MS-RTC LM 8)"
    LOG
    parser = Splog::LogParser.new
    parser.config = config
    parser.pattern_name = 'apache_common'
    # Get an enumerable from the string, ie enumerate the lines
    e = parser.read_input(log_example)
    # Get an enumerable from the parser
    pe = parser.parse(e)
    log_entry_one = pe.next
    log_entry_one.should include(
       'Host' => '127.0.0.1',
       'Identity' => '-',
       'User' => '-',
       'Time' => '25/Sep/2013:15:41:55 -0400',
       'Request' => 'ENABLE-APP / HTTP/1.0',
       'Status' => '200',
       'Size' => '-',
       'Referer' => '-',
       'UserAgent' => 'ClusterListener/1.0'
    )
    log_entry_two = pe.next
    log_entry_two.should include(
       'Host' => '127.0.0.2',
       'Identity' => '-',
       'User' => '-',
       'Time' => '25/Sep/2013:15:42:30 -0400',
       'Request' => 'GET /mod_cluster-manager/ HTTP/1.1',
       'Status' => '200',
       'Size' => '1360',
       'Referer' => '-',
       'UserAgent' => 'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; WOW64; Trident/5.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C; .NET4.0E; InfoPath.3; MS-RTC LM 8)'
     )
  end
  it 'jboss server.log log4j default, single log lines' do
    config = {
      'jboss_log4j_common' => {
        'delim' => '\s+',
        'regex' => [
          '(?<Date>.*?)',
          '(?<Priority>WARN|ERROR|INFO|TRACE|DEBUG)',
          '\[(?<Category>.*?)\]',
          '\((?<Thread>.*?)\)',
          '(?<Message>.*)'
        ]
      }
    }
    log_example = <<-LOG
03 Oct 2013 18:33:00,380 INFO  [org.jboss.as.security] (ServerService Thread Pool -- 36) JBAS013171: Activating Security Subsystem
03 Oct 2013 18:33:00,419 DEBUG  [org.jboss.as.webservices] (ServerService Thread Pool -- 32) JBAS015537: Activating WebServices Extension
    LOG
    parser = Splog::LogParser.new
    parser.config = config
    parser.pattern_name = 'jboss_log4j_common'
    # Get an enumerable from the string, ie enumerate the lines
    e = parser.read_input(log_example)
    # Get an enumerable from the parser
    pe = parser.parse(e)
    log_entry_one = pe.next
    log_entry_one.should include(
     'Category' => 'org.jboss.as.security',
     'Date' => '03 Oct 2013 18:33:00,380',
     'Message' => 'JBAS013171: Activating Security Subsystem',
     'Priority' => 'INFO',
     'Thread' => 'ServerService Thread Pool -- 36',
     )
    log_entry_two = pe.next
    log_entry_two.should include(
     'Category' => 'org.jboss.as.webservices',
     'Date' => '03 Oct 2013 18:33:00,419',
     'Message' => 'JBAS015537: Activating WebServices Extension',
     'Priority' => 'DEBUG',
     'Thread' => 'ServerService Thread Pool -- 32',
    )
  end
  it 'jboss server.log log4j default multiline no match log lines' do
    config = {
      'jboss_log4j_common' => {
        'delim' => '\s+',
        'regex' => [
          '(?<Date>.*?)',
          '(?<Priority>WARN|ERROR|INFO|TRACE|DEBUG)',
          '\[(?<Category>.*?)\]',
          '\((?<Thread>.*?)\)',
          '(?<Message>.*)'
        ],
        'unmatched_append_key_name' => 'Message'
      }
    }
    log_example = <<-LOG
03 Oct 2013 20:19:42,591 INFO  [org.jboss.as.ejb3.deployment.processors.EjbJndiBindingsDeploymentUnitProcessor] (MSC service thread 1-12) JNDI bindings for session bean named Z are as follows:
	java:global/a/b/c!com.a.b.c.D
	java:app/x/y!com.x.y.Z
    LOG
    parser = Splog::LogParser.new
    parser.config = config
    parser.pattern_name = 'jboss_log4j_common'
    # Get an enumerable from the string, ie enumerate the lines
    e = parser.read_input(log_example)
    # Get an enumerable from the parser
    pe = parser.parse(e)
    log_entry_one = pe.next
    log_entry_one.should include(
     'Category' => 'org.jboss.as.ejb3.deployment.processors.EjbJndiBindingsDeploymentUnitProcessor',
     'Date' => '03 Oct 2013 20:19:42,591',
     'Message' => "JNDI bindings for session bean named Z are as follows:\tjava:global/a/b/c!com.a.b.c.D\n\tjava:app/x/y!com.x.y.Z\n",
     'Priority' => 'INFO',
     'Thread' => 'MSC service thread 1-12',
    )
  end
  #it 'jboss server.log log4j default multiline matched log lines' do
  #  # Match subsequent lines and add them to a previous line
  #
  #  dot_file_path = File.expand_path('examples/jboss/.splog.yml')
  #  server_log_name = File.expand_path('examples/jboss/multiline_match_server.log')
  #
  #  parser = Splog::LogParser.new
  #  parser.cli(['-p', 'jboss_log4j_common','-f', server_log_name, '-c', dot_file_path])
  #  e = parser.read_log_file(parser.options[:file_name])
  #  # Get an enumerable from the parser
  #  pe = parser.parse(e)
  #  log_entry_one = pe.next
  #  log_entry_one.should include(
  #     'Category' => 'stderr',
  #     'Date' => '03 Oct 2013 20:16:55,308',
  #     'Message' => "java.lang.IllegalStateException: EJBCLIENT000025: No EJB receiver available for handling\n\tat org.jboss.ejb.client.EJBClientContext\n\tat org.jboss.ejb.client.ReceiverInterceptor",
  #     'Priority' => 'ERROR',
  #     'Thread' => 'MSC service thread 1-3',
  #   )
  #end
end
