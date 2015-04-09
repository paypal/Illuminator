require 'singleton'
require 'fileutils'

# Convenience functions for command-line actions done in Xcode
class BuildArtifacts
  include Singleton

  def initialize
    @_root = nil
    @artifactsHaveBeenCreated = false
  end

  def setRoot(dir)
    if @_root != dir and @artifactsHaveBeenCreated
      puts "Warning: changing BuildArtifacts root to '#{dir}' after creating artifacts in '#{@_root}'".red
    end
    @_root = dir
  end

  def _setupAndUse(dir, skipSetup)
    raise TypeError, "The buildArtifact root directory is nil; perhaps it was not set" if @_root.nil?
    unless skipSetup or File.directory?(dir)
      FileUtils.mkdir_p dir
      @artifactsHaveBeenCreated = true
    end
    dir
  end

  ################## Directories

  def root(skipSetup = false)
    self._setupAndUse @_root, skipSetup
  end

  def xcode(skipSetup = false)
    self._setupAndUse "#{@_root}/xcode", skipSetup
  end

  def instruments(skipSetup = false)
    self._setupAndUse "#{@_root}/instruments", skipSetup
  end

  def crashReports(skipSetup = false)
    self._setupAndUse "#{@_root}/crashReports", skipSetup
  end

  def objectFiles(skipSetup = false)
    self._setupAndUse "#{@_root}/objectFiles", skipSetup
  end

  def console(skipSetup = false)
    self._setupAndUse "#{@_root}/console", skipSetup
  end

  def UIAutomation(skipSetup = false)
    self._setupAndUse "#{@_root}/UIAutomation-outputs", skipSetup
  end

  def state(skipSetup = false)
    self._setupAndUse "#{@_root}/Illuminator-state", skipSetup
  end


  ################## FILES

  def appLocation(appName = nil)
    appOutputDirectory = self.xcode
    if appName.nil?
      # assume that only one app exists and use that
      return Dir["#{appOutputDirectory}/*.app"][0]
    else
      return "#{appOutputDirectory}/#{appName}.app"
    end
  end

  def coverageReportFile(skipSetup = false)
    self._setupAndUse @_root, skipSetup
    "#{@_root}/coverage.xml"
  end

  def illuminatorJsRunner(skipSetup = false)
    self._setupAndUse @_root, skipSetup
    "#{@_root}/IlluminatorGeneratedRunnerForInstruments.js"
  end

  def illuminatorJsEnvironment(skipSetup = false)
    self._setupAndUse @_root, skipSetup
    "#{@_root}/IlluminatorGeneratedEnvironment.js"
  end

  def illuminatorConfigFile(skipSetup = false)
    self._setupAndUse @_root, skipSetup
    "#{@_root}/IlluminatorGeneratedConfig.json"
  end

  def junitReportFile(skipSetup = false)
    self._setupAndUse @_root, skipSetup
    "#{@_root}/IlluminatorJUnitReport.xml"
  end

  def illuminatorRerunFailedTestsSettings(skipSetup = false)
    self._setupAndUse @_root, skipSetup
    "#{@_root}/IlluminatorRerunFailedTestsSettings.json"
  end

end
