
require_relative './saltinel-listener'

module SaltinelAgentEventSink

  def saltinelAgentGotScenarioList jsonPath
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

  def saltinelAgentGotScenarioDefinitions jsonPath
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

  def saltinelAgentGotStacktraceHint
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

  def saltinelAgentGotRestartRequest
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

end

# Saltinel Agent handles all known saltinel messages and runs callbacks
class SaltinelAgent < SaltinelListener

  attr_accessor :eventSink

  def onInit
    @recognizers = {
      "recognizeTestList"       => /Saved intended test list to: (.*)/,
      "recognizeTestDefs"       => /Saved scenario definitions to: (.*)/,
      "recognizeStacktrace"     => /Stack trace follows:/,
      "recognizeRestartRequest" => /Request instruments restart/,
    }
  end

  def recognizeTestList regexResult
    # assume developer has set eventSink already
    @eventSink.saltinelAgentGotScenarioList(regexResult.to_a[1])
  end

  def recognizeTestDefs regexResult
    # assume developer has set eventSink already
    @eventSink.saltinelAgentGotScenarioDefinitions(regexResult.to_a[1])
  end

  def recognizeStacktrace _
    @eventSink.saltinelAgentGotStacktraceHint
  end

  def recognizeRestartRequest _
    @eventSink.saltinelAgentGotRestartRequest
  end

  def onSaltinel innerMessage
    @recognizers.each do |fn, regex|
      result = regex.match(innerMessage)
      self.send(fn, result) unless result.nil?
    end
  end

  def onAutomationFinished
  end

end
