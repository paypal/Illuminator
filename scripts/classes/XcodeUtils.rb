require 'singleton'

# Convenience functions for command-line actions done in Xcode
class XcodeUtils
  include Singleton

  def initialize
    @xcodePath = `/usr/bin/xcode-select -print-path`.chomp.sub(/^\s+/, '')
    @sdkPath = nil
    @instrumentsPath = nil
    @instrumentsTemplatePath = nil
  end

  def getXcodePath
    @xcodePath
  end

  # Get the path to the SDK
  def getSdkPath
    @sdkPath ||= `/usr/bin/xcodebuild -version -sdk iphoneos | grep PlatformPath`.split(':')[1].chomp.sub(/^\s+/, '')
  end

  # Get the path to the instruments bundle
  def getInstrumentsPath
    if @instrumentsPath.nil?
      if File.directory? "#{@xcodePath}/../Applications/Instruments.app/Contents/PlugIns/AutomationInstrument.xrplugin/"
        @instrumentsPath = "AutomationInstrument.xrplugin";
      else
        #fallback to old instruments bundle (pre Xcode6)
        @instrumentsPath = "AutomationInstrument.bundle";
      end
    end
    @instrumentsPath
  end

  # Get the path to the instruments template
  def getInstrumentsTemplatePath
    if @instrumentsTemplatePath.nil?
      sdkPath = self.getSdkPath
      instrumentsFolder = self.getInstrumentsPath

      xcode5TemplatePath = "#{@xcodePath}/../Applications/Instruments.app/Contents/PlugIns/#{instrumentsFolder}/Contents/Resources/Automation.tracetemplate"
      xcode6TemplatePath = "#{sdkPath}/Developer/Library/Instruments/PlugIns/#{instrumentsFolder}/Contents/Resources/Automation.tracetemplate"

      if File.exist? xcode6TemplatePath
        @instrumentsTemplatePath = xcode6TemplatePath
      else
        @instrumentsTemplatePath = xcode5TemplatePath
      end
    end
    @instrumentsTemplatePath
  end

  # Based on the desired device and version, get the ID of the simulator that will be passed to instruments
  def getSimulatorID (simDevice, simVersion)
    devices = `instruments -s devices`
    needle = simDevice + ' \(' + simVersion + ' Simulator\) \[(.*)\]'
    match = devices.match(needle)
    if match
      puts "Found device match: #{match}".green
      return match.captures[0]
    else

    #fallback to old device name behavior (pre Xcode6)
      puts "Did not find UDID of device '#{simDevice}' for version '#{simVersion}'".green
      return "#{simDevice} - Simulator - iOS #{simVersion}"
    end

  end
end
