require 'rubygems'
require 'fileutils'

require File.join(File.expand_path(File.dirname(__FILE__)), 'XcodeBuilder.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'ParameterStorage.rb')

####################################################################################################
# Builder
####################################################################################################

class AutomationBuilder

  def initialize

    resultPath = "'#{File.dirname(__FILE__)}/../../buildArtifacts/xcodeArtifacts'"
    @builder = XcodeBuilder.new
    @builder.addParameter('configuration','Debug')
    @builder.addEnvironmentVariable('CONFIGURATION_BUILD_DIR',resultPath)
    @builder.addEnvironmentVariable('CONFIGURATION_TEMP_DIR',resultPath)
    @builder.addEnvironmentVariable('UIAUTOMATION_BUILD',true)
    @builder.addEnvironmentVariable('GCC_PREPROCESSOR_DEFINITIONS',"'$(value) UIAUTOMATION_BUILD=1'")
    @builder.clean
    @builder.killSim
  end

  def buildScheme scheme, hardwareID = nil, workspace = nil, coverage = FALSE

    directory = Dir.pwd
    unless workspace.nil?
      Dir.chdir(workspace)
    end

    if hardwareID.nil?
      @builder.addParameter('sdk','iphonesimulator')
      @builder.addParameter('arch','i386')
    else
      @builder.addParameter('arch','armv7')
      @builder.addEnvironmentVariable("AUTOMATION_UDID",hardwareID)
    end
    
    if coverage
      @builder.addParameter('xcconfig',"'#{File.dirname(__FILE__)}/../resources/BuildConfiguration.xcconfig'")
    end

    @builder.addParameter('scheme',scheme)
    @builder.run

    Dir.chdir(directory)
  end

end
