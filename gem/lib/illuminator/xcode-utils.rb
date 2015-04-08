require 'singleton'
require 'fileutils'

module Illuminator

  # Convenience functions for command-line actions done in Xcode
  class XcodeUtils
    include Singleton

    def initialize
      @xcodePath = `/usr/bin/xcode-select -print-path`.chomp.sub(/^\s+/, '')
      @xcodeVersion = nil
      @sdkPath = nil
      @instrumentsPath = nil
      @_simulatorDevicesText = nil
      @simulatorDeviceTypes = nil
      @simulatorRuntims = nil
    end

    def getXcodePath
      @xcodePath
    end

    def getXcodeAppPath
      HostUtils.realpath(File.join(@xcodePath, "../../"))
    end

    def getXcodeSimctlPath
      HostUtils.realpath(File.join(@xcodePath, "/usr/bin/simctl"))
    end

    def getXcodeVersion
      if @xcodeVersion.nil?
        xcodeVersion = `xcodebuild -version`
        needle = 'Xcode (.*)'
        match = xcodeVersion.match(needle)
        @xcodeVersion = match.captures[0]
      end
      @xcodeVersion
    end

    def isXcodeMajorVersion ver
      # should update this with 'version' gem
      needle = '(\d+)\.?(\d+)?'
      match = self.getXcodeVersion.match(needle)
      return match.captures[0].to_i == ver
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
      instrumentsFolder = self.getInstrumentsPath
      "#{@xcodePath}/../Applications/Instruments.app/Contents/PlugIns/#{instrumentsFolder}/Contents/Resources/Automation.tracetemplate"
    end

    def _getAllSimulatorInfo
      info = `#{self.getXcodeSimctlPath} list`.split("\n")

      output = {"devices" => [], "runtimes" => []}
      pointer = nil
      needle = nil

      info.each do |line|
        case line
        when "== Device Types =="
          # all data we want is followed by " (" e.g. "iPhone 5 (com.apple.C......."
          pointer = "devices"
          needle = '([^(]*) '
        when "== Runtimes =="
          # all data we want is in the form "iOS 7.0 (7.0.3 - ........." and we want the 7.0
          pointer = "runtimes"
          needle = 'iOS ([^(]*) '
        when "== Devices =="
          pointer = nil
          needle = nil
        else
          unless pointer.nil?
            match = line.match(needle)
            if match
              output[pointer] << match.captures[0]
            end
          end
        end
      end

      @simulatorDeviceTypes = output["devices"]
      @simulatorRuntimes = output["runtimes"]
    end

    def getSimulatorDeviceTypes
      if @simulatorDeviceTypes.nil?
        self._getAllSimulatorInfo
      end
      @simulatorDeviceTypes
    end

    def getSimulatorRuntimes
      if @simulatorRuntimes.nil?
        self._getAllSimulatorInfo
      end
      @simulatorRuntimes
    end

    def getSimulatorDevices
      if @_simulatorDevicesText.nil?
        @_simulatorDevicesText = `instruments -s devices`
      end
      @_simulatorDevicesText
    end

    # Based on the desired device and version, get the ID of the simulator that will be passed to instruments
    def getSimulatorID (simDevice, simVersion)
      devices = self.getSimulatorDevices
      needle = simDevice + ' \(' + simVersion + ' Simulator\) \[(.*)\]'
      match = devices.match(needle)
      if match
        puts "Found device match: #{match}".green
        return match.captures[0]
      elsif
        puts "Did not find UDID of device '#{simDevice}' for version '#{simVersion}'".green
        if XcodeUtils.instance.isXcodeMajorVersion 5
          fallbackName = "#{simDevice} - Simulator - iOS #{simVersion}"
          puts "Falling back to Xcode5 name #{fallbackName}".green
          return fallbackName
        end
      end

      return nil
    end

    def getCrashDirectory
      return "#{ENV['HOME']}/Library/Logs/DiagnosticReports"
    end

    # Create a crash report
    def createSymbolicatedCrashReport (appPath, crashPath, crashReportPath)
      # find symbolicatecrash file, which is different depending on the Xcode version (we assume either 5 or 6)
      frameworksPath = "#{@xcodePath}/Platforms/iPhoneOS.platform/Developer/Library/PrivateFrameworks"
      symbolicatorPath = "#{frameworksPath}/DTDeviceKitBase.framework/Versions/A/Resources/symbolicatecrash"
      if not File.exist?(symbolicatorPath)
        symbolicatorPath = "#{frameworksPath}/DTDeviceKit.framework/Versions/A/Resources/symbolicatecrash"
      end
      if not File.exist?(symbolicatorPath)
        symbolicatorPath = File.join(self.getXcodeAppPath, "Contents/SharedFrameworks/DTDeviceKitBase.framework/Versions/A/Resources/symbolicatecrash")
      end

      command =   "DEVELOPER_DIR='#{@xcodePath}' "
      command <<  "'#{symbolicatorPath}' "
      command <<  "-o '#{crashReportPath}' '#{crashPath}' '#{appPath}.dSYM' 2>&1"

      output = `#{command}`

      # log the output of the crash reporting if the file didn't appear
      unless File.exist?(crashReportPath)
        puts command.green
        puts output
        return false
      end
      return true
    end

    # use the provided applescript to reset the content and settings of the simulator
    def resetSimulator deviceID
      command = "#{self.getXcodeSimctlPath} erase #{deviceID}"
      puts command.green
      puts `#{command}`

    end

    # remove any apps in the specified directory
    def self.removeExistingApps xcodeOutputDir
      Dir["#{xcodeOutputDir}/*.app"].each do |app|
        puts "XcodeUtils: removing #{app}"
        FileUtils.rm_rf app
      end
    end

    def self.killAllSimulatorProcesses
      command = HostUtils.realpath(File.join(File.dirname(__FILE__), "../kill_all_sim_processes.sh"))
      puts "Running #{command}"
      puts `'#{command}'`
    end

  end

end
