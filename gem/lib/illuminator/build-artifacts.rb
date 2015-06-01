require 'singleton'
require 'fileutils'

# Convenience functions for command-line actions done in Xcode
module Illuminator
  class BuildArtifacts
    include Singleton

    def initialize
      @_root = nil
      @artifacts_have_been_created = false
    end

    def set_root(dir_raw)
      dir = Illuminator::HostUtils.realpath(dir_raw)
      if @_root != dir and @artifacts_have_been_created
        puts "Warning: changing BuildArtifacts root to '#{dir}' after creating artifacts in '#{@_root}'".red
      end
      @_root = dir
    end

    def _setup_and_use(dir, skip_setup)
      raise TypeError, "The buildArtifact root directory is nil; perhaps it was not set" if @_root.nil?
      unless skip_setup or File.directory?(dir)
        FileUtils.mkdir_p dir
        @artifacts_have_been_created = true
      end
      dir
    end

    ################## Directories

    def root(skip_setup = false)
      _setup_and_use @_root, skip_setup
    end

    def xcode(skip_setup = false)
      _setup_and_use "#{@_root}/xcode", skip_setup
    end

    def derived_data(skip_setup = false)
      _setup_and_use "#{@_root}/xcodeDerivedData", skip_setup
    end

    def instruments(skip_setup = false)
      _setup_and_use "#{@_root}/instruments", skip_setup
    end

    def crash_reports(skip_setup = false)
      _setup_and_use "#{@_root}/crashReports", skip_setup
    end

    def object_files(skip_setup = false)
      _setup_and_use "#{@_root}/objectFiles", skip_setup
    end

    def console(skip_setup = false)
      _setup_and_use "#{@_root}/console", skip_setup
    end

    def ui_automation(skip_setup = false)
      _setup_and_use "#{@_root}/UIAutomation-outputs", skip_setup
    end

    def state(skip_setup = false)
      _setup_and_use "#{@_root}/Illuminator-state", skip_setup
    end


    ################## FILES

    def app_location(app_name = nil)
      app_output_directory = xcode
      if app_name.nil?
        # assume that only one app exists and use that
        return Dir["#{app_output_directory}/*.app"][0]
      else
        return "#{app_output_directory}/#{app_name}.app"
      end
    end

    def xcpretty_report_file(skip_setup = false)
      _setup_and_use "#{@_root}/xcpretty", skip_setup
      "#{@_root}/xcpretty/report.xml"
    end

    def coverage_report_file(skip_setup = false)
      _setup_and_use @_root, skip_setup
      "#{@_root}/coverage.xml"
    end

    def illuminator_js_runner(skip_setup = false)
      _setup_and_use @_root, skip_setup
      "#{@_root}/IlluminatorGeneratedRunnerForInstruments.js"
    end

    def illuminator_js_environment(skip_setup = false)
      _setup_and_use @_root, skip_setup
      "#{@_root}/IlluminatorGeneratedEnvironment.js"
    end

    def illuminator_config_file(skip_setup = false)
      _setup_and_use @_root, skip_setup
      "#{@_root}/IlluminatorGeneratedConfig.json"
    end

    def junit_report_file(skip_setup = false)
      _setup_and_use @_root, skip_setup
      "#{@_root}/IlluminatorJUnitReport.xml"
    end

    def illuminator_rerun_failed_tests_settings(skip_setup = false)
      _setup_and_use @_root, skip_setup
      "#{@_root}/IlluminatorRerunFailedTestsSettings.json"
    end

  end
end
