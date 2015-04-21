require 'erb'
require 'pathname'
require 'json'
require 'socket'
require 'digest/sha1'

require_relative './build-artifacts'
require_relative './host-utils'
require_relative './xcode-utils'

# Class to handle all configuration relating to the javascript environment
# "runner" is a bit of a misnomer (this runs as part of instruments) but without this code, nothing runs
class JavascriptRunner

  attr_reader   :saltinel # the salted sentinel
  attr_accessor :targetDeviceID
  attr_accessor :isHardware
  attr_accessor :entryPoint
  attr_accessor :testPath
  attr_accessor :implementation
  attr_accessor :simDevice
  attr_accessor :simVersion
  attr_accessor :randomSeed
  attr_accessor :tagsAny
  attr_accessor :tagsAll
  attr_accessor :tagsNone
  attr_accessor :scenarioList
  attr_accessor :scenarioNumberOffset # for consistent numbering after restarts
  attr_accessor :appSpecificConfig

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
      'targetDeviceID'               => @targetDeviceID,
      'isHardware'                   => @isHardware,
      'xcodePath'                    => Illuminator::XcodeUtils.instance.getXcodePath,
      'automatorSequenceRandomSeed'  => @randomSeed,
      'automatorTagsAny'             => @tagsAny,
      'automatorTagsAll'             => @tagsAll,
      'automatorTagsNone'            => @tagsNone,
      'automatorScenarioNames'       => @scenarioList,
      'automatorScenarioOffset'      => @scenarioNumberOffset,
      'customConfig'                 => (@appSpecificConfig.is_a? Hash) ? @appSpecificConfig : @appSpecificConfig.to_h,
    }

    keyDefs.each do |key, value|
        @fullConfig[key] = value unless value.nil?
    end

  end


  def writeConfiguration()
    # instance variables required for renderTemplate
    @saltinel                   = Digest::SHA1.hexdigest (Time.now.to_i.to_s + Socket.gethostname)
    @illuminatorRoot            = Illuminator::HostUtils.realpath(File.join(File.dirname(__FILE__), "../../resources/js/"))
    @illuminatorScripts         = Illuminator::HostUtils.realpath(File.join(File.dirname(__FILE__), "../../resources/scripts/"))
    @artifactsRoot              = Illuminator::BuildArtifacts.instance.root
    @illuminatorInstrumentsRoot = Illuminator::BuildArtifacts.instance.instruments
    @environmentFile            = Illuminator::BuildArtifacts.instance.illuminatorJsEnvironment

    # prepare @fullConfig
    self.assembleConfig

    self.renderTemplate '/resources/IlluminatorGeneratedRunnerForInstruments.erb', Illuminator::BuildArtifacts.instance.illuminatorJsRunner
    self.renderTemplate '/resources/IlluminatorGeneratedEnvironment.erb', Illuminator::BuildArtifacts.instance.illuminatorJsEnvironment

    Illuminator::HostUtils.saveJSON(@fullConfig, Illuminator::BuildArtifacts.instance.illuminatorConfigFile)
  end


  def renderTemplate sourceFile, destinationFile
    contents = File.open(File.dirname(__FILE__) + sourceFile, 'r') { |f| f.read }

    renderer = ERB.new(contents)
    newFile = File.open(destinationFile, 'w')
    newFile.write(renderer.result(binding))
    newFile.close
  end

end
