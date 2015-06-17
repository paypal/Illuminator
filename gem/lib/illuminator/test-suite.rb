require 'date'

class TestSuite

  attr_reader :test_cases
  attr_reader :implementation

  def initialize(implementation)
    @implementation = implementation
    @test_cases     = []
    @case_lookup    = {}
  end

  def add_test_case(class_name, name)
    test = TestCase.new(@implementation, class_name, name)
    @test_cases << test
    @case_lookup[name] = test
  end

  def [](test_case_name)
    @case_lookup[test_case_name]
  end

  # TODO: fix naming, some of these return test cases and some return arrays of names

  def unstarted_tests
    @test_cases.reject { |t| t.ran? }.map { |t| t.name }
  end

  def finished_tests
    @test_cases.select { |t| t.ran? } .map { |t| t.name }
  end

  def all_tests
    @test_cases.dup
  end

  def passed_tests
    @test_cases.select { |t| t.passed? }
  end

  def unpassed_tests
    @test_cases.reject { |t| t.passed? }
  end

  def to_xml
    output = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' << "\n"

    output << "<testsuite>\n"
    @test_cases.each { |test| output << test.to_xml }
    output << "</testsuite>" << "\n"
    output
  end
end

class TestCase
  attr_reader :name
  attr_reader :class_name
  attr_reader :implementation

  attr_accessor :stacktrace

  def initialize(implementation, class_name, name)
    @implementation = implementation
    @class_name     = class_name
    @name           = name
    reset!
  end

  def <<(stdoutLine)
    @stdout << stdoutLine
  end

  def reset!
    @stdout        = []
    @stacktrace    = ""
    @fail_message  = ""
    @fail_tag      = nil
    @time_start    = nil
    @time_finish   = nil
  end

  def start!
    @time_start = Time.now
  end

  def pass!
    @time_finish = Time.now
  end

  def fail message
    @time_finish  = Time.now
    @fail_tag     = "failure"
    @fail_message = message
  end

  def error message
    @time_finish  = Time.now
    @fail_tag     = "error"
    @fail_message = message
  end

  def ran?
    not (@time_start.nil? or @time_finish.nil?)
  end

  def passed?
    @fail_tag.nil?
  end

  # this is NOT the opposite of passed!  this does not count errored tests
  def failed?
    @fail_tag == "failure"
  end

  def errored?
    @fail_tag == "error"
  end

  def time
    return 0 if @time_finish.nil?
    @time_finish - @time_start
  end

  def to_xml
    attrs = {
      "name"      => @name,
      "classname" => "#{@implementation}.#{@class_name}",
      "time"      => time,
    }

    output = "  <testcase"
    attrs.each { |key, value| output << " #{key}=#{value.to_s.encode(:xml => :attr)}" }
    output << ">\n"

    if not ran?
      output << "    <skipped />\n"
    elsif (not @fail_tag.nil?)
      fattrs = {
        "message" => @fail_message,
      }

      output << "    <#{@fail_tag}"
      fattrs.each { |key, value| output << " #{key}=#{value.to_s.encode(:xml => :attr)}" }
      output << ">#{@stacktrace.to_s.encode(:xml => :text)}" << "\n"
      output << "    </#{@fail_tag}>" << "\n"
    end

    output << "    <system-out>#{@stdout.map { |m| m.encode(:xml => :text) }.join("\n")}" << "\n"
    output << "    </system-out>" << "\n"

    output << "  </testcase>" << "\n"

  end
end
