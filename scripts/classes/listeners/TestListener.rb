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

  def receive(message)
    # assume developer has set eventSink already

    # signal test starts before general logging
    @eventSink.testListenerGotTestStart message.message if message.status == :start

    # log all lines
    if message.status == :unknown
      @eventSink.testListenerGotLine nil, message.fullLine
    else
      @eventSink.testListenerGotLine message.status, message.message
    end

    # signal test ends after logs
    @eventSink.testListenerGotTestPass message.message if message.status == :pass
    @eventSink.testListenerGotTestFail message.message if message.status == :fail

  end

  def onAutomationFinished
  end

end
