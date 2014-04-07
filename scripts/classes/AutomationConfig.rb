require 'erb'
require File.join(File.expand_path(File.dirname(__FILE__)), '/ParameterStorage.rb')


class AutomationConfig
  @testPath = nil
  def initialize(device, plistPath, simVersion, tagsAny, tagsAll, tagsNone, randomSeed, hardwareID = nil, testPath)
    @testPath = testPath
    @automatorRoot = File.dirname(__FILE__) + "/../.."
    
    self.renderTemplate "/../resources/testAutomatically.erb", "/../../buildArtifacts/testAutomatically.js"
    self.renderTemplate "/../resources/environment.erb", "/../../buildArtifacts/environment.js"
    
    @plistStorage = PLISTStorage.new
    @plistStorage.clearAtPath(self.configPath())
    @plistStorage.addParameterToStorage('device', device)
    unless hardwareID.nil?
      @plistStorage.addParameterToStorage('hardwareID', hardwareID)
    end
   # @plistStorage.addParameterToStorage('plistPath', stage)
    @plistStorage.addParameterToStorage('automatorDesiredSimVersion', simVersion)

    tagDefs = {'automatorTagsAny' => tagsAny, 'automatorTagsAll' => tagsAll, 'automatorTagsNone' => tagsNone}
    tagDefs.each do |name, value|
      unless value.nil?
        @plistStorage.addParameterToStorage(name, value)
      else
        @plistStorage.addParameterToStorage(name, Array.new(0))
      end
    end

    unless randomSeed.nil?
      @plistStorage.addParameterToStorage('automatorSequenceRandomSeed', randomSeed)
    end

  end

  def configPath
    return 'buildArtifacts/generatedConfig.plist'
  end
  
  def renderTemplate sourceFile, destinationFile
    
    file = File.open(File.dirname(__FILE__) + sourceFile)
    contents = ""
    file.each {|line|
      contents << line
    }
    
    renderer = ERB.new(contents)
    newFile = File.open(File.dirname(__FILE__) + destinationFile, "w")
    newFile.write(renderer.result(binding))
    newFile.close

  end
  
  def save
    @plistStorage.saveToPath(self.configPath())
  end

end
