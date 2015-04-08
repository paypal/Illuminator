require 'fileutils'

require_relative './xcode-builder'
require_relative './build-artifacts'

####################################################################################################
# Builder
####################################################################################################

class AutomationBuilder < XcodeBuilder

  def initialize
    super
    @configuration = 'Debug'

    resultPath = BuildArtifacts.instance.xcode
    self.addEnvironmentVariable('CONFIGURATION_BUILD_DIR', "'#{resultPath}'")
    self.addEnvironmentVariable('CONFIGURATION_TEMP_DIR', "'#{resultPath}'")
    self.addEnvironmentVariable('UIAUTOMATION_BUILD', true)
  end


  def buildForAutomation sdk, hardwareID
    @xcconfig = "'#{File.dirname(__FILE__)}/../resources/BuildConfiguration.xcconfig'"

    preprocessorDefinitions = '$(value) UIAUTOMATION_BUILD=1'
    if hardwareID.nil?
      @sdk = sdk || 'iphonesimulator'
      @arch = @arch || 'i386'
    else
      @sdk = sdk || 'iphoneos'
      @arch = @arch || 'armv7'
      @destination = "id=#{hardwareID}"
      preprocessorDefinitions += " AUTOMATION_UDID=#{hardwareID}"
    end
    self.addEnvironmentVariable('GCC_PREPROCESSOR_DEFINITIONS', "'#{preprocessorDefinitions}'")

    self.build
  end

end
