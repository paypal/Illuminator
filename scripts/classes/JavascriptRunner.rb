require 'erb'
require 'pathname'
require 'json'
require 'socket'
require 'digest/sha1'
require File.join(File.expand_path(File.dirname(__FILE__)), '/BuildArtifacts.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), '/HostUtils.rb')

# Class to handle all configuration relating to the javascript environment
# "runner" is a bit of a misnomer (this runs as part of instruments) but without this code, nothing runs
class JavascriptRunner

  attr_reader   :saltinel # the salted sentinel
  attr_accessor :entryPoint
  attr_accessor :testPath
  attr_accessor :implementation
  attr_accessor :simDevice
  attr_accessor :simVersion
  attr_accessor :hardwareID
  attr_accessor :randomSeed
  attr_accessor :customJSConfig
  attr_accessor :customJSConfigPath
  attr_accessor :tagsAny
  attr_accessor :tagsAll
  attr_accessor :tagsNone
  attr_accessor :scenarioList
  attr_accessor :scenarioNumberOffset # for consistent numbering after restarts

  def initialize
    @tagsAny        = Array.new(0)
    @tagsAll        = Array.new(0)
    @tagsNone       = Array.new(0)
    @scenarioList   = nil
  end


  def assembleConfig
    @fullConfig = {}

    # a mapping of the full config key name to the local value that corresponds to it
    keyDefs = {
      'saltinel'                     => @saltinel,
      'entryPoint'                   => @entryPoint,
      'implementation'               => @implementation,
      'automatorDesiredSimDevice'    => @simDevice,
      'automatorDesiredSimVersion'   => @simVersion,
      'hardwareID'                   => @hardwareID,
      'automatorSequenceRandomSeed'  => @randomSeed,
      'customJSConfigPath'           => @customJSConfigPath,
      'automatorTagsAny'             => @tagsAny,
      'automatorTagsAll'             => @tagsAll,
      'automatorTagsNone'            => @tagsNone,
      'automatorScenarioNames'       => @scenarioList,
      'automatorScenarioOffset'      => @scenarioNumberOffset,
    }

    keyDefs.each do |key, value|
        @fullConfig[key] = value unless value.nil?
    end

  end


  def writeConfiguration()
    # instance variables required for renderTemplate
    @saltinel                   = Digest::SHA1.hexdigest (Time.now.to_i.to_s + Socket.gethostname)
    @illuminatorRoot            = HostUtils.realpath(File.join(File.dirname(__FILE__), "../.."))
    @artifactsRoot              = BuildArtifacts.instance.root
    @illuminatorInstrumentsRoot = BuildArtifacts.instance.instruments
    @environmentFile            = BuildArtifacts.instance.illuminatorJsEnvironment

    # prepare @fullConfig
    self.assembleConfig

    self.renderTemplate '/../resources/IlluminatorGeneratedRunnerForInstruments.erb', BuildArtifacts.instance.illuminatorJsRunner
    self.renderTemplate '/../resources/IlluminatorGeneratedEnvironment.erb', BuildArtifacts.instance.illuminatorJsEnvironment

    if @customJSConfig.nil?
      @fullConfig["customJSConfigPath"] = nil
    else
      HostUtils.saveJSON(@customJSConfig, @customJSConfigPath)
    end


    HostUtils.saveJSON(@fullConfig, BuildArtifacts.instance.illuminatorConfigFile)
  end


  def renderTemplate sourceFile, destinationFile
    contents = File.open(File.dirname(__FILE__) + sourceFile, 'r') { |f| f.read }

    renderer = ERB.new(contents)
    newFile = File.open(destinationFile, 'w')
    newFile.write(renderer.result(binding))
    newFile.close
  end

end
