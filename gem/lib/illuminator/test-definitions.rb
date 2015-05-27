require 'json'

# A class to hold the defintions of all automator tests, as defined in the (generated) automatorScenarios.json
class TestDefinitions

  def initialize automator_settings_json_path
    raw_defs = JSON.parse( IO.read(automator_settings_json_path) )
    @in_order = raw_defs["scenarios"].dup

    # save test defs for use later (as lookups)
    @by_name = {}
    @in_order.each { |scen| @by_name[scen["title"]] = scen }
  end

  def by_name name
    @by_name[name].dup
  end

  def by_index idx
    @in_order[idx].dup
  end

end
