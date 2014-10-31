
require File.join(File.expand_path(File.dirname(__FILE__)), 'SaltinelListener.rb')

module StartDetectorEventSink

  def startDetectorTriggered
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

end

# StartDetector monitors the logs for things that indicate a successful startup of instruments
#  - the saltinel for the intended test list
#  - a javascript error
#  - etc
class StartDetector < SaltinelListener

  attr_accessor :eventSink

  def onInit
    @alreadyStarted = false
  end

  def trigger
    # assume developer has set eventSink already
    @eventSink.startDetectorTriggered unless @alreadyStarted
    @alreadyStarted = true
  end

  def receive message
    super
    self.trigger if :error == message.status and /Script threw an uncaught JavaScript error:/ =~ message.message
  end

  def onSaltinel innerMessage
    self.trigger if /Saved intended test list to/ =~ innerMessage
  end

  def onAutomationFinished
  end

end
