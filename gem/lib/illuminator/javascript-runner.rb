require 'erb'
require 'pathname'
require 'json'
require 'socket'
require 'digest/sha1'

require_relative './build-artifacts'
require_relative './host-utils'
require_relative './xcode-utils'

# Class to handle all configuration relating to the javascript environment
# "runner" is a bit of a misnomer (this runs as part of instruments) but without this code, nothing runs
class JavascriptRunner

  attr_reader   :saltinel # the salted sentinel
  attr_accessor :target_device_id
  attr_accessor :is_hardware
  attr_accessor :entry_point
  attr_accessor :test_path
  attr_accessor :implementation
  attr_accessor :sim_device
  attr_accessor :sim_version
  attr_accessor :random_seed
  attr_accessor :tags_any
  attr_accessor :tags_all
  attr_accessor :tags_none
  attr_accessor :scenario_list
  attr_accessor :scenario_number_offset # for consistent numbering after restarts
  attr_accessor :app_specific_config

  def initialize
    @tags_any        = Array.new(0)
    @tags_all        = Array.new(0)
    @tags_none       = Array.new(0)
    @scenario_list   = nil
  end


  def assemble_config
    @full_config = {}

    # a mapping of the full config key name to the local value that corresponds to it
    key_defs = {
      'saltinel'                     => @saltinel,
      'entryPoint'                   => @entry_point,
      'implementation'               => @implementation,
      'automatorDesiredSimDevice'    => @sim_device,
      'automatorDesiredSimVersion'   => @sim_version,
      'targetDeviceID'               => @target_device_id,
      'isHardware'                   => @is_hardware,
      'xcodePath'                    => Illuminator::XcodeUtils.instance.get_xcode_path,
      'automatorSequenceRandomSeed'  => @random_seed,
      'automatorTagsAny'             => @tags_any,
      'automatorTagsAll'             => @tags_all,
      'automatorTagsNone'            => @tags_none,
      'automatorScenarioNames'       => @scenario_list,
      'automatorScenarioOffset'      => @scenario_number_offset,
      'customConfig'                 => (@app_specific_config.is_a? Hash) ? @app_specific_config : @app_specific_config.to_h,
    }

    key_defs.each do |key, value|
        @full_config[key] = value unless value.nil?
    end

  end


  def write_configuration()
    # instance variables required for render_template
    @saltinel                     = Digest::SHA1.hexdigest (Time.now.to_i.to_s + Socket.gethostname)
    @illuminator_root             = Illuminator::HostUtils.realpath(File.join(File.dirname(__FILE__), "../../resources/js/"))
    @illuminator_scripts          = Illuminator::HostUtils.realpath(File.join(File.dirname(__FILE__), "../../resources/scripts/"))
    @artifacts_root               = Illuminator::BuildArtifacts.instance.root
    @illuminator_instruments_root = Illuminator::BuildArtifacts.instance.instruments
    @environment_file             = Illuminator::BuildArtifacts.instance.illuminator_js_environment

    # prepare @full_config
    self.assemble_config

    self.render_template '/resources/IlluminatorGeneratedRunnerForInstruments.erb', Illuminator::BuildArtifacts.instance.illuminator_js_runner
    self.render_template '/resources/IlluminatorGeneratedEnvironment.erb', Illuminator::BuildArtifacts.instance.illuminator_js_environment

    Illuminator::HostUtils.save_json(@full_config, Illuminator::BuildArtifacts.instance.illuminator_config_file)
  end


  def render_template source_file, destination_file
    contents = File.open(File.dirname(__FILE__) + source_file, 'r') { |f| f.read }

    renderer = ERB.new(contents)
    new_file = File.open(destination_file, 'w')
    new_file.write(renderer.result(binding))
    new_file.close
  end

end
