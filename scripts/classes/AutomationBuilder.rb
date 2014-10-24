require 'rubygems'
require 'fileutils'

require File.join(File.expand_path(File.dirname(__FILE__)), 'XcodeBuilder.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'BuildArtifacts.rb')

####################################################################################################
# Builder
####################################################################################################

class AutomationBuilder

  def initialize

    @resultPath = BuildArtifacts.instance.xcode

    @builder = XcodeBuilder.new
    @builder.configuration = 'Debug'
    @builder.addEnvironmentVariable('CONFIGURATION_BUILD_DIR', "'#{@resultPath}'")
    @builder.addEnvironmentVariable('CONFIGURATION_TEMP_DIR', "'#{@resultPath}'")
    @builder.addEnvironmentVariable('UIAUTOMATION_BUILD', true)
  end


  def removeExistingApps
    Dir["#{@resultPath}/*.app"].each do |app|
      FileUtils.rm app
    end
  end

                                                                       # TODO: forceClean = FALSE
  def buildScheme(scheme, sdk, hardwareID = nil, workspace = nil, coverage = FALSE, skipClean = FALSE)

    preprocessorDefinitions = '$(value) UIAUTOMATION_BUILD=1'

    if hardwareID.nil?
      sdk ||= 'iphonesimulator'
      @builder.arch = 'i386'
    else
      sdk ||= 'iphoneos'
      @builder.arch = 'armv7'
      @builder.destination = "id=#{hardwareID}"
      preprocessorDefinitions += " AUTOMATION_UDID=#{hardwareID}"
    end

    @builder.doClean = (not skipClean)
    @builder.sdk = sdk
    @builder.xcconfig = "'#{File.dirname(__FILE__)}/../resources/BuildConfiguration.xcconfig'"
    @builder.scheme = scheme

    @builder.addEnvironmentVariable('GCC_PREPROCESSOR_DEFINITIONS', "'#{preprocessorDefinitions}'")

    # switch to a directory (if desired) and build
    directory = Dir.pwd
    Dir.chdir(workspace) unless workspace.nil?
    @builder.run
    Dir.chdir(directory) unless workspace.nil?

  end

end
