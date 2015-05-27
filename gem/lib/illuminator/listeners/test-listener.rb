require 'date'

require_relative './instruments-listener'

module TestListenerEventSink

  def test_listener_got_test_start name
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

  def test_listener_got_test_pass name
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

  def test_listener_got_test_fail message
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

  def test_listener_got_test_error message
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end


  def test_listener_got_line(status, message)
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

end


class TestListener < InstrumentsListener

  attr_accessor :event_sink

  def receive(message)
    # assume developer has set event_sink already

    # signal test starts before general logging
    @event_sink.test_listener_got_test_start message.message if message.status == :start

    # log all lines
    if message.status == :unknown
      @event_sink.test_listener_got_line nil, message.full_line
    else
      @event_sink.test_listener_got_line message.status, message.message
    end

    # signal test ends after logs
    @event_sink.test_listener_got_test_pass message.message if message.status == :pass
    @event_sink.test_listener_got_test_fail message.message if message.status == :fail
    @event_sink.test_listener_got_test_error message.message if message.status == :error

  end

  def on_automation_finished
  end

end
