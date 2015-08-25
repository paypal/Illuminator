
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
      self.xcode        = RecursiveOpenStruct.new
      self.instruments  = RecursiveOpenStruct.new
      self.simulator    = RecursiveOpenStruct.new
      self.javascript   = RecursiveOpenStruct.new
      self.illuminator  = RecursiveOpenStruct.new
      self.app_specific = nil    # all unknown options will go here
      self.build_artifacts_dir = nil

      self.illuminator.clean  = RecursiveOpenStruct.new
      self.illuminator.task   = RecursiveOpenStruct.new
      self.illuminator.test   = RecursiveOpenStruct.new

      self.illuminator.test.tags   = RecursiveOpenStruct.new
      self.illuminator.test.retest = RecursiveOpenStruct.new

      # name all the keys (just for visibiilty)
      self.xcode.project_dir = nil
      self.xcode.project = nil
      self.xcode.app_name = nil
      self.xcode.sdk = nil
      self.xcode.workspace = nil
      self.xcode.scheme = nil
      self.xcode.environment_vars = nil

      self.illuminator.entry_point = nil
      self.illuminator.test.random_seed = nil
      self.illuminator.test.tags.any = nil
      self.illuminator.test.tags.all = nil
      self.illuminator.test.tags.none = nil
      self.illuminator.test.names = nil
      self.illuminator.test.retest.attempts = nil
      self.illuminator.test.retest.solo = nil
      self.illuminator.clean.xcode = nil
      self.illuminator.clean.derived = nil
      self.illuminator.clean.artifacts = nil
      self.illuminator.clean.no_delay = nil
      self.illuminator.task.build = nil
      self.illuminator.task.automate = nil
      self.illuminator.task.set_sim = nil
      self.illuminator.task.coverage = nil
      self.illuminator.hardware_id = nil

      self.simulator.device = nil
      self.simulator.version = nil
      self.simulator.language = nil
      self.simulator.locale = nil
      self.simulator.kill_after = nil

      self.instruments.do_verbose = nil
      self.instruments.timeout = nil
      self.instruments.max_silence = nil
      self.instruments.attempts = nil
      self.instruments.app_location = nil  # normally, this is where we build to

      self.javascript.test_path = nil
      self.javascript.implementation = nil
      self.javascript.app_specific_config = nil
    end

  end
end
