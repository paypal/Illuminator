require 'date'

require File.join(File.expand_path(File.dirname(__FILE__)), 'InstrumentsListener.rb')

module TestListenerEventSink

  def testListenerGotTestStart name
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

  def testListenerGotTestPass name
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

  def testListenerGotTestFail message
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

  def testListenerGotLine(status, message)
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

end


class TestListener < InstrumentsListener

  attr_accessor :eventSink

  def reset
  end

  def receive(message)
    # assume developer has set eventSink already
    case message.status
    when :start
      @eventSink.testListenerGotTestStart message.message
    when :pass
      @eventSink.testListenerGotTestPass message.message
    when :fail
      @eventSink.testListenerGotTestFail message.message
    when :unknown
      @eventSink.testListenerGotLine nil, message.fullLine
    else
      @eventSink.testListenerGotLine message.status, message.message
    end
  end

  def onAutomationFinished
  end

end
