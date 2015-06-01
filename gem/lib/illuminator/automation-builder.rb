require 'fileutils'

require_relative './xcode-builder'
require_relative './build-artifacts'

####################################################################################################
# Builder
####################################################################################################

module Illuminator
  class AutomationBuilder < XcodeBuilder

    def initialize
      super
      @configuration = 'Debug'

      add_environment_variable('UIAUTOMATION_BUILD', true)
    end


    def build_for_automation sdk, hardware_id
      @xcconfig = "#{File.dirname(__FILE__)}/../../resources/BuildConfiguration.xcconfig"

      preprocessor_definitions = '$(value) UIAUTOMATION_BUILD=1'
      if hardware_id.nil?
        @sdk = sdk || 'iphonesimulator'
        @arch = @arch || 'i386'
      else
        @sdk = sdk || 'iphoneos'
        @destination = "id=#{hardware_id}"
        preprocessor_definitions += " AUTOMATION_UDID=#{hardware_id}"
      end
      add_environment_variable('GCC_PREPROCESSOR_DEFINITIONS', "'#{preprocessor_definitions}'")

      build
    end

  end
end
