require 'date'

require File.join(File.expand_path(File.dirname(__FILE__)), 'InstrumentsListener.rb')

class TestSuite
  attr_reader :name, :timestamp
  attr_accessor :test_cases

  def initialize(name)
    @name = name
    @test_cases = []
    @timestamp = DateTime.now
  end

  def failures
    @test_cases.count { |test| test.failed? }
  end

  def time
    @test_cases.map { |test| test.time }.inject(:+)
  end

  def to_xml
    attrs = {
      "name"      => @name,
      "timestamp" => @timestamp,
      "time"      => self.time,
      "tests"     => @test_cases.count,
      "failures"  => self.failures,
    }

    output = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' << "\n"

    output << "<testsuite"
    "foo".encode(:xml => :attr)
    attrs.each { |key, value| output << " #{key}=#{value.to_s.encode(:xml => :attr)}" }
    output << ">\n"

    @test_cases.each { |test| output << test.to_xml }

    output << "</testsuite>" << "\n"
    output
  end
end

class TestCase
  attr_reader :name
  attr_accessor :messages

  def initialize(name)
    @name = name
    @messages = []
    @failed = true
    @start = Time.now
    @finish = nil
  end

  def <<(message)
    @messages << message
  end

  def pass!
    @failed = false;
    @finish = Time.now
  end

  def fail!
    @finish = Time.now
  end

  def failed?
    @failed
  end

  def time
    return 0 if @finish.nil?
    @finish - @start
  end

  def to_xml
    attrs = {
      "name"      => @name,
      "time"      => self.time,
    }

    output = "  <testcase"
    attrs.each { |key, value| output << " #{key}=#{value.to_s.encode(:xml => :attr)}" }
    output << ">\n"

    if self.failed?
      output << "    <failure>#{@messages.map { |m| m.encode(:xml => :text) }.join("\n")}" << "\n" << "    </failure>" << "\n"
    end
    output << "  </testcase>" << "\n"

  end
end

# Creates a XML report that conforms to # https://svn.jenkins-ci.org/trunk/hudson/dtkit/dtkit-format/dtkit-junit-model/src/main/resources/com/thalesgroup/dtkit/junit/model/xsd/junit-4.xsd
class JunitOutput < InstrumentsListener

  def initialize(filename)
    @filename = filename
    @suite = TestSuite.new(File.basename(filename, File.extname(filename)))
  end

  def add(line)
    return if @suite.test_cases.empty?
    @suite.test_cases.last << line
  end

  def receive(message)
    case message.status
    when :start
      @suite.test_cases << TestCase.new(message.message)
      @suite.test_cases.last << "#{message.message}"
    when :pass
      @suite.test_cases.last.pass! if @suite.test_cases.last != nil
    when :fail
      @suite.test_cases.last.fail! if @suite.test_cases.last != nil
    when :unknown
      if @suite.test_cases.last != nil && @suite.test_cases.last.time == 0
        @suite.test_cases.last << "#{message.fullLine}"
      end
    else
      if @suite.test_cases.last != nil && @suite.test_cases.last.time == 0
        @suite.test_cases.last << "#{message.status.to_s.capitalize}: #{message.message}"
      end
    end
  end

  def onAutomationFinished(failed)
    File.open(@filename, 'w') { |f| f.write(@suite.to_xml) }
    puts "CI report written to #{@filename}".green
  end

end
