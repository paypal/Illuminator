require 'date'

class TestSuite

  attr_reader :testCases
  attr_reader :implementation

  def initialize(implementation)
    @implementation = implementation
    @testCases      = []
    @caseLookup     = {}
  end

  def addTestCase(className, name)
    test = TestCase.new(@implementation, className, name)
    @testCases << test
    @caseLookup[name] = test
  end

  def [](testCaseName)
    @caseLookup[testCaseName]
  end

  def unStartedTests
    ret = Array.new
    @testCases.each { |t| ret << t.name unless t.ran? }
    ret
  end

  def finishedTests
    ret = Array.new
    @testCases.each { |t| ret << t.name if t.ran? }
    ret
  end

  def allTests
    @testCases.dup
  end

  def passedTests
    @testCases.select { |t| t.passed? }
  end

  def failedTests
    @testCases.select { |t| not t.passed? }
  end

  def to_xml
    output = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' << "\n"

    output << "<testsuite>\n"
    @testCases.each { |test| output << test.to_xml }
    output << "</testsuite>" << "\n"
    output
  end
end

class TestCase
  attr_reader :name
  attr_reader :className
  attr_reader :implementation

  attr_accessor :stacktrace

  def initialize(implementation, className, name)
    @implementation = implementation
    @className      = className
    @name           = name
    self.reset!
  end

  def <<(stdoutLine)
    @stdout << stdoutLine
  end

  def reset!
    @stdout       = []
    @stacktrace   = ""
    @failMessage  = ""
    @failTag      = nil
    @timeStart    = nil
    @timeFinish   = nil
  end

  def start!
    @timeStart = Time.now
  end

  def pass!
    @timeFinish = Time.now
  end

  def fail message
    @timeFinish  = Time.now
    @failTag     = "failure"
    @failMessage = message
  end

  def error message
    @timeFinish  = Time.now
    @failTag     = "error"
    @failMessage = message
  end

  def ran?
    not (@timeStart.nil? or @timeFinish.nil?)
  end

  def passed?
    @failTag.nil?
  end

  # this is NOT the opposite of passed!  this does not count errored tests
  def failed?
    @failTag == "failure"
  end

  def errored?
    @failTag == "error"
  end

  def time
    return 0 if @timeFinish.nil?
    @timeFinish - @timeStart
  end

  def to_xml
    attrs = {
      "name"      => @name,
      "classname" => "#{@implementation}.#{@className}",
      "time"      => self.time,
    }

    output = "  <testcase"
    attrs.each { |key, value| output << " #{key}=#{value.to_s.encode(:xml => :attr)}" }
    output << ">\n"

    if not self.ran?
      output << "    <skipped />\n"
    elsif (not @failTag.nil?)
      fattrs = {
        "message" => @failMessage,
      }

      output << "    <#{@failTag}"
      fattrs.each { |key, value| output << " #{key}=#{value.to_s.encode(:xml => :attr)}" }
      output << ">#{@stacktrace.to_s.encode(:xml => :text)}" << "\n"
      output << "    </#{@failTag}>" << "\n"
    end

    output << "    <system-out>#{@stdout.map { |m| m.encode(:xml => :text) }.join("\n")}" << "\n"
    output << "    </system-out>" << "\n"

    output << "  </testcase>" << "\n"

  end
end
