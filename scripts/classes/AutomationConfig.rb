require File.join(File.expand_path(File.dirname(__FILE__)), '/ParameterStorage.rb')


class AutomationConfig

  def initialize(device, stage, simVersion, tagsAny, tagsAll, tagsNone, randomSeed, hardwareID = nil, testPath)
    FileUtils.ln_s testPath, File.dirname(__FILE__)+"/../../buildArtifacts/testDefinitions.js"
    
    @jsStorage = PLISTStorage.new
    @jsStorage.clearAtPath(self.configPath())
    @jsStorage.addParameterToStorage('device', device)
    unless hardwareID.nil?
      @jsStorage.addParameterToStorage('hardwareID', hardwareID)
    end
    @jsStorage.addParameterToStorage('stage', stage)
    @jsStorage.addParameterToStorage('automatorDesiredSimVersion', simVersion)

    tagDefs = {'automatorTagsAny' => tagsAny, 'automatorTagsAll' => tagsAll, 'automatorTagsNone' => tagsNone}
    tagDefs.each do |name, value|
      unless value.nil?
        @jsStorage.addParameterToStorage(name, value)
      else
        @jsStorage.addParameterToStorage(name, Array.new(0))
      end
    end

    unless randomSeed.nil?
      @jsStorage.addParameterToStorage('automatorSequenceRandomSeed', randomSeed)
    end

  end

  def configPath
    return 'buildArtifacts/generatedConfig.plist'
  end

  def save
    @jsStorage.saveToPath(self.configPath())
  end

end
