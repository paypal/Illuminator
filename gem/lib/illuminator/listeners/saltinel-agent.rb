
require_relative './saltinel-listener'

module SaltinelAgentEventSink

  def saltinel_agent_got_scenario_list jsonPath
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

  def saltinel_agent_got_scenario_definitions jsonPath
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

  def saltinel_agent_got_stacktrace_hint
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

  def saltinel_agent_got_restart_request
    puts "  +++ If you're seeing this, #{self.class.name}.#{__method__} was not overridden"
  end

end

# Saltinel Agent handles all known saltinel messages and runs callbacks
class SaltinelAgent < SaltinelListener

  attr_accessor :event_sink

  def on_init
    @recognizers = {
      "recognize_test_list"       => /Saved intended test list to: (.*)/,
      "recognize_test_defs"       => /Saved scenario definitions to: (.*)/,
      "recognize_stacktrace"      => /Stack trace follows:/,
      "recognize_restart_request" => /Request instruments restart/,
    }
  end

  def recognize_test_list regexResult
    # assume developer has set event_sink already
    @event_sink.saltinel_agent_got_scenario_list(regexResult.to_a[1])
  end

  def recognize_test_defs regexResult
    # assume developer has set event_sink already
    @event_sink.saltinel_agent_got_scenario_definitions(regexResult.to_a[1])
  end

  def recognize_stacktrace _
    @event_sink.saltinel_agent_got_stacktrace_hint
  end

  def recognize_restart_request _
    @event_sink.saltinel_agent_got_restart_request
  end

  def on_saltinel inner_message
    @recognizers.each do |fn, regex|
      result = regex.match(inner_message)
      send(fn, result) unless result.nil?
    end
  end

  def on_automation_finished
  end

end
