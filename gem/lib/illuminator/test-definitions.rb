require 'json'

# A class to hold the defintions of all automator tests, as defined in the (generated) automatorScenarios.json
class TestDefinitions

  def initialize automatorSettingsJsonPath
    rawDefs = JSON.parse( IO.read(automatorSettingsJsonPath) )
    @inOrder = rawDefs["scenarios"].dup

    # save test defs for use later (as lookups)
    @byName = {}
    @inOrder.each { |scen| @byName[scen["title"]] = scen }
  end

  def byName name
    @byName[name].dup
  end

  def byIndex idx
    @inOrder[idx].dup
  end

end
