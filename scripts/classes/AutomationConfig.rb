require 'erb'
require 'pathname'
require File.join(File.expand_path(File.dirname(__FILE__)), '/ParameterStorage.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), '/BuildArtifacts.rb')


class AutomationConfig

  def initialize(implementation, testPath)
    # instance variables required for renderTemplate
    @testPath = testPath
    @illuminatorRoot = Pathname.new(File.dirname(__FILE__) + '/../..').realpath.to_s
    @artifactsRoot = BuildArtifacts.instance.root
    @illuminatorInstrumentsRoot = BuildArtifacts.instance.instruments
    @environmentFile = BuildArtifacts.instance.illuminatorJsEnvironment

    self.renderTemplate '/../resources/IlluminatorGeneratedRunnerForInstruments.erb', BuildArtifacts.instance.illuminatorJsRunner
    self.renderTemplate '/../resources/IlluminatorGeneratedEnvironment.erb', BuildArtifacts.instance.illuminatorJsEnvironment

    @plistStorage = PLISTStorage.new
    @plistStorage.clearAtPath(BuildArtifacts.instance.illuminatorConfigFile)

    #implementation
    @plistStorage.addParameterToStorage('implementation', implementation)

  end

  def setSimDevice simDevice
    @plistStorage.addParameterToStorage('automatorDesiredSimDevice', simDevice)
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

  def setEntryPoint entryPoint
    @plistStorage.addParameterToStorage 'entryPoint', entryPoint
  end

  def defineTags  tagsAny, tagsAll, tagsNone
    self.setEntryPoint 'runTestsByTag'

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

  def defineTests testList
    self.setEntryPoint 'runTestsByName'
    @plistStorage.addParameterToStorage('automatorScenarioNames', testList)
  end

  def defineDescribe
    self.setEntryPoint 'describe'
  end

  def renderTemplate sourceFile, destinationFile

    file = File.open(File.dirname(__FILE__) + sourceFile)
    contents = ''
    file.each {|line|
      contents << line
    }

    renderer = ERB.new(contents)
    newFile = File.open(destinationFile, 'w')
    newFile.write(renderer.result(binding))
    newFile.close

  end

  def save
    @plistStorage.saveToPath(BuildArtifacts.instance.illuminatorConfigFile)
  end

end
