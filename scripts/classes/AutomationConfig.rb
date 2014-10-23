require 'erb'
require 'pathname'
require 'json'
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

    @fullConfig = Hash.new

    #implementation
    @fullConfig['implementation'] = implementation

  end

  def setSimDevice simDevice
    @fullConfig['automatorDesiredSimDevice'] = simDevice
  end

  def setSimVersion simVersion
    @fullConfig['automatorDesiredSimVersion'] = simVersion
  end

  def setHardwareID hardwareID
    @fullConfig['hardwareID'] = hardwareID
  end

  def setRandomSeed randomSeed
    @fullConfig['automatorSequenceRandomSeed'] = randomSeed
  end

  def setCustomJSConfigPath customConfigJSONPath
    @fullConfig['customJSConfigPath'] = customConfigJSONPath
  end

  def setEntryPoint entryPoint
    @fullConfig['entryPoint'] = entryPoint
  end

  def defineTags  tagsAny, tagsAll, tagsNone
    self.setEntryPoint 'runTestsByTag'

    # tags
    tagDefs = {'automatorTagsAny' => tagsAny, 'automatorTagsAll' => tagsAll, 'automatorTagsNone' => tagsNone}
    tagDefs.each do |name, value|
      unless value.nil?
        @fullConfig[name] = value
      else
        @fullConfig[name] = Array.new(0)
      end
    end
  end

  def defineTests testList
    self.setEntryPoint 'runTestsByName'
    @fullConfig['automatorScenarioNames'] = testList
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
    File.open(BuildArtifacts.instance.illuminatorConfigFile, 'w') { |f| f << JSON.pretty_generate(@fullConfig) }
  end

end
