require 'erb'
require File.join(File.expand_path(File.dirname(__FILE__)), '/ParameterStorage.rb')


class AutomationConfig

  def initialize(implementation, testPath)
    @testPath = testPath
    @automatorRoot = File.dirname(__FILE__) + "/../.."

    FileUtils.mkdir_p(File.dirname(__FILE__) + "/../../buildArtifacts")
    self.renderTemplate "/../resources/testAutomatically.erb", "/../../buildArtifacts/testAutomatically.js"
    self.renderTemplate "/../resources/environment.erb", "/../../buildArtifacts/environment.js"

    @plistStorage = PLISTStorage.new
    @plistStorage.clearAtPath(self.configPath())


    #implementation
    @plistStorage.addParameterToStorage('implementation', implementation)

  end

  def setSimVersion simVersion
    @plistStorage.addParameterToStorage('automatorDesiredSimVersion', simVersion)
  end

  def setHardwareID hardwareID
    @plistStorage.addParameterToStorage('hardwareID', hardwareID)
  end

  def setRandomSeed randomSeed
    @plistStorage.addParameterToStorage('automatorSequenceRandomSeed', randomSeed)
  end

  def setCustomConfig customConfig
    @plistStorage.addParameterToStorage 'customConfig', customConfig
  end

  def defineTags  tagsAny, tagsAll, tagsNone,
    # tags
    tagDefs = {'automatorTagsAny' => tagsAny, 'automatorTagsAll' => tagsAll, 'automatorTagsNone' => tagsNone}
    tagDefs.each do |name, value|
      unless value.nil?
        @plistStorage.addParameterToStorage(name, value)
      else
        @plistStorage.addParameterToStorage(name, Array.new(0))
      end
    end
  end

  def configPath
    return @automatorRoot + '/buildArtifacts/generatedConfig.plist'
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
    puts "path" + self.configPath()
    @plistStorage.saveToPath(self.configPath())
  end

end
