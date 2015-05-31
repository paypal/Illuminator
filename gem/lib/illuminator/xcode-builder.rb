require 'colorize'

require_relative './build-artifacts'
require_relative './host-utils'

module Illuminator
  class XcodeBuilder
    attr_accessor :project
    attr_accessor :configuration
    attr_accessor :sdk
    attr_accessor :arch
    attr_accessor :scheme
    attr_accessor :project_dir
    attr_accessor :workspace
    attr_accessor :destination
    attr_accessor :xcconfig
    attr_accessor :do_clean
    attr_accessor :do_test
    attr_accessor :do_build
    attr_accessor :do_archive
    attr_accessor :derived_data_is_artifact

    attr_reader :exit_code

    def initialize
      @parameters       = Hash.new
      @environment_vars = Hash.new
      @project_dir      = nil
      @do_clean         = FALSE
      @do_test          = FALSE
      @do_build         = TRUE
      @do_archive       = FALSE
      @exit_code        = nil

      @derived_data_is_artifact = FALSE

      result_path = Illuminator::BuildArtifacts.instance.xcode
      add_environment_variable('CONFIGURATION_BUILD_DIR', "'#{result_path}'")
      add_environment_variable('CONFIGURATION_TEMP_DIR', "'#{result_path}'")
    end

    def set_build_artifacts_root root_dir
      Illuminator::BuildArtifacts.instance.set_root(root_dir)
    end

    def add_parameter(parameter_name = '',parameter_value = '')
      @parameters[parameter_name] = parameter_value
    end

    def add_environment_variable(parameter_name = '',parameter_value = '')
      @environment_vars[parameter_name] = parameter_value
    end

    def _assemble_config
      # put standard parameters into parameters
      key_defs = {
        'project'       => @project,
        'configuration' => @configuration,
        'sdk'           => @sdk,
        'arch'          => @arch,
        'scheme'        => @scheme,
        'destination'   => @destination,
        'workspace'     => @workspace,
        'xcconfig'      => @xcconfig,
      }

      # since derived data can take quite a lot of disk space, don't automatically store it
      #  in build-specific directory
      if @derived_data_is_artifact
        key_defs['derivedDataPath'] = Illuminator::BuildArtifacts.instance.derived_data
      end

      key_defs.each do |key, value|
        add_parameter(key, value) unless value.nil?
      end
    end


    def _build_command
      use_pipefail = false  # debug option
      _assemble_config

      parameters = ''
      environment_vars = ''
      tasks = ''

      @parameters.each      { |name, value| parameters << " -#{name} \"#{value}\"" }
      @environment_vars.each { |name, value| environment_vars << " #{name}=#{value}" }

      tasks << ' clean'    if @do_clean
      tasks << ' build'    if @do_build
      tasks << ' archive'  if @do_archive
      tasks << ' test'     if @do_test

      command = ''
      command << 'set -o pipefail && ' if use_pipefail
      command << 'xcodebuild'
      command << parameters << environment_vars << tasks
      command << " | tee '#{logfile_path}'"
      unless Illuminator::HostUtils.which("xcpretty").nil?  # use xcpretty if available
        command << " | xcpretty -c -r junit -o \"#{BuildArtifacts.instance.xcpretty_report_file}\""
      end
      command << ' && exit ${PIPESTATUS[0]}' unless use_pipefail

      command
    end


    def logfile_path
      log_file = File.join(Illuminator::BuildArtifacts.instance.console, 'xcodebuild.log')
    end


    def _execute_build_command command
      puts command.green
      process = IO.popen(command) do |io|
        io.each {|line| puts line}
        io.close
      end

      ec = $?
      @exit_code = ec.exitstatus
      return @exit_code == 0
    end


    def build
      command = _build_command

      # switch to a directory (if desired) and build
      directory = Dir.pwd
      retval = nil
      begin
        Dir.chdir(@project_dir) unless @project_dir.nil?
        retval = _execute_build_command command
      ensure
        Dir.chdir(directory) unless @project_dir.nil?
      end

      retval
    end

  end
end
