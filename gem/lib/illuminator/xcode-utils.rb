require 'singleton'
require 'fileutils'

module Illuminator

  # Convenience functions for command-line actions done in Xcode
  class XcodeUtils
    include Singleton

    def initialize
      @xcode_path              = `/usr/bin/xcode-select -print-path`.chomp.sub(/^\s+/, '')
      @xcode_version           = nil
      @sdk_path                = nil
      @instruments_path        = nil
      @_simulator_devices_text = nil
      @simulator_device_types  = nil
      @simulator_runtimes      = nil
    end

    def get_xcode_path
      @xcode_path
    end

    def get_xcode_app_path
      Illuminator::HostUtils.realpath(File.join(@xcode_path, "../../"))
    end

    def get_xcode_simctl_path
      Illuminator::HostUtils.realpath(File.join(@xcode_path, "/usr/bin/simctl"))
    end

    def get_xcode_version
      if @xcode_version.nil?
        xcode_version = `xcodebuild -version`
        needle = 'Xcode (.*)'
        match = xcode_version.match(needle)
        @xcode_version = match.captures[0]
      end
      @xcode_version
    end

    def is_xcode_major_version ver
      # should update this with 'version' gem
      needle = '(\d+)\.?(\d+)?'
      match = get_xcode_version.match(needle)
      return match.captures[0].to_i == ver
    end

    # Get the path to the SDK
    def get_sdk_path
      @sdk_path ||= `/usr/bin/xcodebuild -version -sdk iphoneos | grep PlatformPath`.split(':')[1].chomp.sub(/^\s+/, '')
    end

    # Get the path to the instruments bundle
    def get_instruments_path
      if @instruments_path.nil?
        if File.directory? "#{@xcode_path}/../Applications/Instruments.app/Contents/PlugIns/AutomationInstrument.xrplugin/"
          @instruments_path = "AutomationInstrument.xrplugin";
        else
          #fallback to old instruments bundle (pre Xcode6)
          @instruments_path = "AutomationInstrument.bundle";
        end
      end
      @instruments_path
    end

    # Get the path to the instruments template
    def get_instruments_template_path
      File.join(@xcode_path,
                "../Applications/Instruments.app/Contents/PlugIns",
                get_instruments_path,
                "Contents/Resources/Automation.tracetemplate")
    end

    def _get_all_simulator_info
      info = `#{get_xcode_simctl_path} list`.split("\n")

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

      @simulator_device_types = output["devices"]
      @simulator_runtimes = output["runtimes"]
    end

    def get_simulator_device_types
      if @simulator_device_types.nil?
        _get_all_simulator_info
      end
      @simulator_device_types
    end

    def get_simulator_runtimes
      if @simulator_runtimes.nil?
        _get_all_simulator_info
      end
      @simulator_runtimes
    end

    def get_simulator_devices
      if @_simulator_devices_text.nil?
        @_simulator_devices_text = `script -t 0.1 -q /dev/null instruments -s devices`
      end
      @_simulator_devices_text
    end

    # Based on the desired device and version, get the ID of the simulator that will be passed to instruments
    def get_simulator_id (sim_device, sim_version)
      devices = get_simulator_devices
      needle = sim_device + ' \(' + sim_version + ' Simulator\) \[(.*)\]'
      match = devices.match(needle)
      if match
        puts "Found device match: #{match}".green
        return match.captures[0]
      else
        puts "Did not find UDID of device '#{sim_device}' for version '#{sim_version}'".green
        if XcodeUtils.instance.is_xcode_major_version 5
          fallback_name = "#{sim_device} - Simulator - iOS #{sim_version}"
          puts "Falling back to Xcode5 name #{fallback_name}".green
          return fallback_name
        end
      end

      return nil
    end

    def get_crash_directory
      return "#{ENV['HOME']}/Library/Logs/DiagnosticReports"
    end

    # Create a crash report
    def create_symbolicated_crash_report (app_path, crash_path, crash_report_path)
      # find symbolicatecrash file, which is different depending on the Xcode version (we assume either 5 or 6)
      frameworks_path = "#{@xcode_path}/Platforms/iPhoneOS.platform/Developer/Library/PrivateFrameworks"
      symbolicator_path = "#{frameworks_path}/DTDeviceKitBase.framework/Versions/A/Resources/symbolicatecrash"
      if not File.exist?(symbolicator_path)
        symbolicator_path = "#{frameworks_path}/DTDeviceKit.framework/Versions/A/Resources/symbolicatecrash"
      end
      if not File.exist?(symbolicator_path)
        symbolicator_path = File.join(get_xcode_app_path,
                                      "Contents/SharedFrameworks/DTDeviceKitBase.framework/Versions/A/Resources/symbolicatecrash")
      end

      command =   "DEVELOPER_DIR='#{@xcode_path}' "
      command <<  "'#{symbolicator_path}' "
      command <<  "-o '#{crash_report_path}' '#{crash_path}' '#{app_path}.dSYM' 2>&1"

      output = `#{command}`

      # log the output of the crash reporting if the file didn't appear
      unless File.exist?(crash_report_path)
        puts command.green
        puts output
        return false
      end
      return true
    end

    # use the provided applescript to reset the content and settings of the simulator
    def reset_simulator device_id
      command = "#{get_xcode_simctl_path} erase #{device_id}"
      puts command.green
      puts `#{command}`

    end

    def shutdown_simulator device_id
      command = "#{get_xcode_simctl_path} shutdown #{device_id}"
      puts command.green
      puts `#{command}`
    end

    # remove any apps in the specified directory
    def self.remove_existing_apps xcode_output_dir
      Dir["#{xcode_output_dir}/*.app"].each do |app|
        puts "XcodeUtils: removing #{app}"
        FileUtils.rm_rf app
      end
    end

    def self.kill_all_simulator_processes(device_id = nil)
      XcodeUtils.instance.shutdown_simulator(device_id) unless device_id.nil?
      command = HostUtils.realpath(File.join(File.dirname(__FILE__), "../../resources/scripts/kill_all_sim_processes.sh"))
      puts "Running #{command}"
      puts `'#{command}'`
    end

    def self.kill_all_instruments_processes
      command = "killall -9 instruments"
      puts "Running #{command}"
      puts `#{command}`
    end

  end

end
