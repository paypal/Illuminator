
require 'ostruct'

class RecursiveOpenStruct < OpenStruct

  def initialize(hash=nil)
    # preprocess hash objects into openstruct objects
    unless hash.nil?
      hash.each do |k, v|
        hash[k] = RecursiveOpenStruct.new(v) if v.is_a? Hash
      end
    end

    super
  end

  # recursively translate the openstruct hierarchy to a hash hierarchy
  def to_h
    ret = super

    ret.each do |k, v|
      ret[k] = v.to_h if v.is_a? RecursiveOpenStruct
    end

    return ret
  end
end

module Illuminator
  class Options < RecursiveOpenStruct

    def initialize(hash=nil)
      super
      return unless hash.nil?

      # stub out all the branches
      @xcode        = RecursiveOpenStruct.new
      @instruments  = RecursiveOpenStruct.new
      @simulator    = RecursiveOpenStruct.new
      @javascript   = RecursiveOpenStruct.new
      @illuminator  = RecursiveOpenStruct.new
      @app_specific = nil    # all unknown options will go here
      @build_artifacts_dir = nil

      @illuminator.clean  = RecursiveOpenStruct.new
      @illuminator.task   = RecursiveOpenStruct.new
      @illuminator.test   = RecursiveOpenStruct.new

      @illuminator.test.tags   = RecursiveOpenStruct.new
      @illuminator.test.retest = RecursiveOpenStruct.new

      # name all the keys (just for visibiilty)
      @xcode.project_dir = nil
      @xcode.project = nil
      @xcode.app_name = nil
      @xcode.sdk = nil
      @xcode.workspace = nil
      @xcode.scheme = nil
      @xcode.environment_vars = nil

      @illuminator.entry_point = nil
      @illuminator.test.random_seed = nil
      @illuminator.test.tags.any = nil
      @illuminator.test.tags.all = nil
      @illuminator.test.tags.none = nil
      @illuminator.test.names = nil
      @illuminator.test.retest.attempts = nil
      @illuminator.test.retest.solo = nil
      @illuminator.clean.xcode = nil
      @illuminator.clean.derived = nil
      @illuminator.clean.artifacts = nil
      @illuminator.clean.no_delay = nil
      @illuminator.task.build = nil
      @illuminator.task.automate = nil
      @illuminator.task.set_sim = nil
      @illuminator.task.coverage = nil
      @illuminator.hardware_id = nil

      @simulator.device = nil
      @simulator.version = nil
      @simulator.language = nil
      @simulator.kill_after = nil

      @instruments.do_verbose = nil
      @instruments.timeout = nil
      @instruments.attempts = nil
      @instruments.app_location = nil  # normally, this is where we build to

      @javascript.test_path = nil
      @javascript.implementation = nil
      @javascript.app_specific_config = nil
    end

  end
end
