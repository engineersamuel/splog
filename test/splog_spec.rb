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
              'data_type' => 'DateTime',
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
    options = {:pattern_name => 'apache_common', :output => 'test'}
    parser.set_pattern(options)
    parser.set_mapping(options)
    # Get an enumerable from the string, ie enumerate the lines
    e = parser.read_input(log_example)
    # Get an enumerable from the parser
    pe = parser.parse(e)
    log_entry_one = pe.next

    log_entry_one['Host'].should eql('127.0.0.1')
    log_entry_one['Identity'].should eql('-')
    log_entry_one['User'].should eql('-')
    log_entry_one['Time'].to_s.should eql('2013-09-25 19:41:55 UTC')
    log_entry_one['Time'].should be_a(Time)
    log_entry_one['Request'].should eql('ENABLE-APP / HTTP/1.0')
    log_entry_one['Status'].should eql(200)
    log_entry_one['Status'].should be_a(Integer)
    log_entry_one['Size'].should eql(0)
    log_entry_one['Size'].should be_a(Integer)
    log_entry_one['Referer'].should eql('-')
    log_entry_one['UserAgent'].should eql('ClusterListener/1.0')

    log_entry_two = pe.next
    log_entry_two['Host'].should eql('127.0.0.2')
    log_entry_two['Identity'].should eql('-')
    log_entry_two['User'].should eql('-')
    log_entry_two['Time'].to_s.should eql('2013-09-25 19:42:30 UTC')
    log_entry_two['Time'].should be_a(Time)
    log_entry_two['Request'].should eql('GET /mod_cluster-manager/ HTTP/1.1')
    log_entry_two['Status'].should eql(200)
    log_entry_two['Status'].should be_a(Integer)
    log_entry_two['Size'].should eql(1360)
    log_entry_two['Size'].should be_a(Integer)
    log_entry_two['Referer'].should eql('-')
    log_entry_two['UserAgent'].should eql('Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; WOW64; Trident/5.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C; .NET4.0E; InfoPath.3; MS-RTC LM 8)')
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
    options = {:pattern_name => 'jboss_log4j_common', :output => 'test'}
    parser.set_pattern(options)
    parser.set_mapping(options)
    # Get an enumerable from the string, ie enumerate the lines
    e = parser.read_input(log_example)
    # Get an enumerable from the parser
    pe = parser.parse(e)
    log_entry_one = pe.next
    log_entry_one['Category'].should eql('org.jboss.as.security')
    log_entry_one['Date'].should eql('03 Oct 2013 18:33:00,380')
    log_entry_one['Message'].should eql("JBAS013171: Activating Security Subsystem\n")
    log_entry_one['Priority'].should eql('INFO')
    log_entry_one['Thread'].should eql('ServerService Thread Pool -- 36')

    log_entry_two = pe.next
    log_entry_two.should include(
     'Category' => 'org.jboss.as.webservices',
     'Date' => '03 Oct 2013 18:33:00,419',
     'Message' => "JBAS015537: Activating WebServices Extension\n",
     'Priority' => 'DEBUG',
     'Thread' => 'ServerService Thread Pool -- 32',
    )
  end
  it 'jboss server.log log4j default unmatched multiline log lines' do
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
        'unmatched_append_key_name' => 'Message',
        'mapping' => [
          {
            'name' => 'Date',
            'data_type' => 'DateTime',
            'format' => '%d %b %Y %H:%M:%S,%L'
          }
        ]
      }
    }
    log_example = <<-LOG
03 Oct 2013 20:19:42,591 INFO  [org.jboss.as.ejb3.deployment.processors.EjbJndiBindingsDeploymentUnitProcessor] (MSC service thread 1-12) JNDI bindings for session bean named Z are as follows:
	java:global/a/b/c!com.a.b.c.D
	java:app/x/y!com.x.y.Z
    LOG
    parser = Splog::LogParser.new
    parser.config = config
    options = {:pattern_name => 'jboss_log4j_common', :output => 'test'}
    parser.set_pattern(options)
    parser.set_mapping(options)
    # Get an enumerable from the string, ie enumerate the lines
    e = parser.read_input(log_example)
    # Get an enumerable from the parser
    pe = parser.parse(e)
    log_entry_one = pe.next

    log_entry_one['Category'].should eql('org.jboss.as.ejb3.deployment.processors.EjbJndiBindingsDeploymentUnitProcessor')
    log_entry_one['Date'].to_s.should eql('2013-10-03 20:19:42 UTC')
    log_entry_one['Date'].should be_a(Time)
    log_entry_one['Message'].should eql("JNDI bindings for session bean named Z are as follows:\n\tjava:global/a/b/c!com.a.b.c.D\n\tjava:app/x/y!com.x.y.Z\n")
    log_entry_one['Priority'].should eql('INFO')
    log_entry_one['Thread'].should eql('MSC service thread 1-12')
  end

  # Match subsequent lines and add them to a previous line
  it 'jboss server.log log4j default multiline matched log lines' do
    test_dir = Dir.pwd.match(/.*?splog$/) ? 'test/' : ''
    dot_file_path = File.expand_path("./#{test_dir}examples/jboss/.splog.yml")
    server_log_name = File.expand_path("./#{test_dir}examples/jboss/multiline_match_server.log")

    p "pwd: #{Dir.pwd}, test_dir: #{test_dir}, dot_file_path: #{dot_file_path}"
    parser = Splog::LogParser.new
    parser.cli(['-p', 'jboss_log4j_common','-f', server_log_name, '-c', dot_file_path, '-o', 'test'])
    e = parser.read_log_file(parser.options[:file_name])
    # Get an enumerable from the parser
    pe = parser.parse(e)
    log_entry_one = pe.next
    log_entry_one['Category'].should eql('stderr')
    log_entry_one['Date'].to_s.should eql('2013-10-03 20:16:55 UTC')
    log_entry_one['Date'].should be_a(Time)
    log_entry_one['Message'].should eql("java.lang.IllegalStateException: EJBCLIENT000025: No EJB receiver available for handling\n\tat org.jboss.ejb.client.EJBClientContext\n\tat org.jboss.ejb.client.ReceiverInterceptor\n")
    log_entry_one['Priority'].should eql('ERROR')
    log_entry_one['Thread'].should eql('MSC service thread 1-3')

    #03 Oct 2013 18:33:00,427 INFO  [org.jboss.as.connector.subsystems.datasources] (ServerService Thread Pool -- 57) JBAS010403: Deploying JDBC-compliant driver class org.h2.Driver (version 1.3)
    log_entry_two = pe.next
    log_entry_two['Category'].should eql('org.jboss.as.connector.subsystems.datasources')
    log_entry_two['Date'].to_s.should eql('2013-10-03 18:33:00 UTC')
    log_entry_two['Date'].should be_a(Time)
    log_entry_two['Message'].should eql("JBAS010403: Deploying JDBC-compliant driver class org.h2.Driver (version 1.3)\n\n")
    log_entry_two['Priority'].should eql('INFO')
    log_entry_two['Thread'].should eql('ServerService Thread Pool -- 57')
  end

  # Match subsequent lines and add them to a previous line
  it 'jboss server.log matched and unmatched lines' do
    test_dir = Dir.pwd.match(/.*?splog$/) ? 'test/' : ''
    dot_file_path = File.expand_path("./#{test_dir}examples/jboss/.splog.yml")
    server_log_name = File.expand_path("./#{test_dir}examples/jboss/multiline_match_unmatch_server.log")

    p "pwd: #{Dir.pwd}, test_dir: #{test_dir}, dot_file_path: #{dot_file_path}"
    parser = Splog::LogParser.new
    parser.cli(['-p', 'jboss_log4j_common','-f', server_log_name, '-c', dot_file_path, '-o', 'test'])
    e = parser.read_log_file(parser.options[:file_name])
    # Get an enumerable from the parser
    pe = parser.parse(e)
    parsed_lines = pe.to_a
    parsed_lines.length.should eql(4)
  end


  it 'should properly hash the 50 lines in the sample access log' do
    # Match subsequent lines and add them to a previous line
    test_dir = Dir.pwd.match(/.*?splog$/) ? 'test/' : ''
    dot_file_path = File.expand_path("#{test_dir}examples/apache/.splog.yml")
    server_log_name = File.expand_path("#{test_dir}examples/apache/access_log")

    parser = Splog::LogParser.new
    parser.cli(['-p', 'apache_common','-f', server_log_name, '-c', dot_file_path, '-o', 'test'])
    e = parser.read_log_file(parser.options[:file_name])
    # Get an enumerable from the parser
    pe = parser.parse(e)
    parsed_lines = pe.to_a
    parsed_lines.length.should eql(50)
  end

  it 'should properly parse a debug debug_error_log' do
    # Match subsequent lines and add them to a previous line
    test_dir = Dir.pwd.match(/.*?splog$/) ? 'test/' : ''
    dot_file_path = File.expand_path("#{test_dir}examples/apache/.splog.yml")
    server_log_name = File.expand_path("#{test_dir}examples/apache/debug_error_log")

    parser = Splog::LogParser.new
    parser.cli(['-p', 'apache_error','-f', server_log_name, '-c', dot_file_path, '-o', 'test'])
    e = parser.read_log_file(parser.options[:file_name])
    # Get an enumerable from the parser
    pe = parser.parse(e)
    parsed_lines = pe.to_a
    parsed_lines.length.should eql(14)

    #[Wed Oct 02 19:24:09 2013] [info] APR LDAP: Built with OpenLDAP LDAP SDK
    log_entry_one = parsed_lines[0]
    log_entry_one['Date'].to_s.should eql('2013-10-02 19:24:09 UTC')
    log_entry_one['Date'].should be_a(Time)
    log_entry_one['Severity'].should eql('info')
    log_entry_one['Module'].should eql('APR LDAP:')
    log_entry_one['Message'].should eql("Built with OpenLDAP LDAP SDK\n")

    #[Wed Oct 02 19:27:10 2013] [debug] ajp_header.c(290): ajp_marshal_into_msgb: Header[30] [Connection] = [Keep-Alive]
    log_entry_ten = parsed_lines[9]
    log_entry_ten['Date'].to_s.should eql('2013-10-02 19:27:10 UTC')
    log_entry_ten['Date'].should be_a(Time)
    log_entry_ten['Severity'].should eql('debug')
    log_entry_ten['Module'].should eql('ajp_header.c(290):')
    log_entry_ten['Message'].should eql("ajp_marshal_into_msgb: Header[30] [Connection] = [Keep-Alive]\n")
  end

  it 'should output a json array' do
    # Match subsequent lines and add them to a previous line
    test_dir = Dir.pwd.match(/.*?splog$/) ? 'test/' : ''
    dot_file_path = File.expand_path("#{test_dir}examples/apache/.splog.yml")
    server_log_name = File.expand_path("#{test_dir}examples/apache/simple_access_log")

    parser = Splog::LogParser.new
    parser.cli(['-p', 'apache_common','-f', server_log_name, '-c', dot_file_path, '-o', 'json'])
    e = parser.read_log_file(parser.options[:file_name])
    # Get an enumerable from the parser
    pe = parser.parse(e)
    parsed_lines = pe.to_a
    parsed_lines.length.should eql(2)
  end

  it 'should output verbose logging' do
    # Match subsequent lines and add them to a previous line
    test_dir = Dir.pwd.match(/.*?splog$/) ? 'test/' : ''
    dot_file_path = File.expand_path("#{test_dir}examples/apache/.splog.yml")
    server_log_name = File.expand_path("#{test_dir}examples/apache/simple_access_log")

    parser = Splog::LogParser.new
    parser.cli(['-p', 'apache_common','-f', server_log_name, '-c', dot_file_path, '-o', '-v'])
    e = parser.read_log_file(parser.options[:file_name])
    # Get an enumerable from the parser
    pe = parser.parse(e)
    parsed_lines = pe.to_a
  end
end
