
# Convenience functions for command-line actions done in Xcode
class XcodeUtils

  # Get the path to Xcode as configured previously by xcode-select
  def self.getXcodePath
    `/usr/bin/xcode-select -print-path`.chomp.sub(/^\s+/, '')
  end

  # Get the path to the SDK
  def self.getSdkPath
    `/usr/bin/xcodebuild -version -sdk iphoneos | grep PlatformPath`.split(':')[1].chomp.sub(/^\s+/, '')
  end

  # Get the path to the instruments bundle
  def self.getInstrumentsPath (xcodePath)
    if File.directory? "#{xcodePath}/../Applications/Instruments.app/Contents/PlugIns/AutomationInstrument.xrplugin/"
      return "AutomationInstrument.xrplugin";
    else
    #fallback to old instruments bundle (pre Xcode6)
      return "AutomationInstrument.bundle";
    end
  end

  # Get the path to the instruments template
  def self.getInstrumentsTemplatePath (xcodePath)
    sdkPath = self.getSdkPath
    instrumentsFolder = self.getInstrumentsPath(xcodePath)

    xcode5TemplatePath = "#{xcodePath}/../Applications/Instruments.app/Contents/PlugIns/#{instrumentsFolder}/Contents/Resources/Automation.tracetemplate"
    xcode6TemplatePath = "#{sdkPath}/Developer/Library/Instruments/PlugIns/#{instrumentsFolder}/Contents/Resources/Automation.tracetemplate"

    if File.exist? xcode6TemplatePath
      return xcode6TemplatePath
    else
      return xcode5TemplatePath
    end
  end

  # Based on the desired device and version, get the ID of the simulator that will be passed to instruments
  def self.getSimulatorID (simDevice, simVersion)
    devices = `instruments -s devices`
    needle = simDevice + ' \(' + simVersion + ' Simulator\) \[(.*)\]'
    match = devices.match(needle)
    if match
      puts "Found device match: #{match}".green
      return match.captures[0]
    else

    #fallback to old device name behavior (pre Xcode6)
      puts "Did not found UDID of device running by given name: #{@simDevice}".green
      return "#{simDevice} - Simulator - iOS #{simVersion}"
    end

  end
end
