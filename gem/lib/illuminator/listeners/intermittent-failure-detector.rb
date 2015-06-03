
require_relative './saltinel-listener'

module IntermittentFailureDetectorEventSink

  def intermittent_failure_detector_triggered message
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

end

# IntermittentFailureDetector monitors the logs for things that indicate a transient failure to start instruments
#  - UIATargetHasGoneAWOLException
#  - etc
class IntermittentFailureDetector < SaltinelListener

  attr_accessor :event_sink

  def on_init
    @already_started = false
  end

  def trigger message
    @event_sink.intermittent_failure_detector_triggered message
  end

  def receive message
    super # run the SaltinelListener processor

    # error cases that should trigger a restart
    p = /Automation Instrument ran into an exception while trying to run the script.  UIATargetHasGoneAWOLException/
    if p =~ message.full_line
      trigger "UIATargetHasGoneAWOLException"
    end

    p = /Fail: Could not start script, target application is not frontmost./
    if p =~ message.full_line
      trigger "Could not start script, target application is not frontmost"
    end
  end

  def on_saltinel inner_message
    # no cases yet
  end

  def on_automation_finished
  end

end
