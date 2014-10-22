require 'singleton'
require 'fileutils'
require 'pathname'

# Convenience functions for command-line actions done in Xcode
class BuildArtifacts
  include Singleton

  def initialize
    # use a default root directory location that's inside this project
    @_root = Pathname.new(File.dirname(__FILE__) + '/../../buildArtifacts').realpath.to_s
  end

  def _setupAndUse(dir, skipSetup)
    FileUtils.mkdir_p dir unless skipSetup or File.directory?(dir)
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


  ################## FILES

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
    instDir = self.instruments skipSetup
    "#{instDir}/IlluminatorJUnitReport.xml"
  end

end
