
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

class IlluminatorSettings < RecursiveOpenStruct

  def initialize(hash=nil)
    super
    return unless hash.nil?

    # stub out all the branches
    self.xcode       = RecursiveOpenStruct.new
    self.instruments = RecursiveOpenStruct.new
    self.simulator   = RecursiveOpenStruct.new
    self.javascript  = RecursiveOpenStruct.new
    self.illuminator = RecursiveOpenStruct.new
    self.appSpecific = nil    # all unknown settings will go here

    self.illuminator.clean     = RecursiveOpenStruct.new
    self.illuminator.task      = RecursiveOpenStruct.new
    self.illuminator.test      = RecursiveOpenStruct.new
    self.illuminator.test.tags = RecursiveOpenStruct.new

    # name all the keys (just for visibiilty)
    self.xcode.appName = nil
    self.xcode.sdk = nil
    self.xcode.scheme = nil
    self.xcode.environmentVars = nil

    self.illuminator.entryPoint = nil
    self.illuminator.test.randomSeed = nil
    self.illuminator.test.tags.any = nil
    self.illuminator.test.tags.all = nil
    self.illuminator.test.tags.none = nil
    self.illuminator.test.names = nil
    self.illuminator.clean.xcode = nil
    self.illuminator.clean.derived = nil
    self.illuminator.clean.artifacts = nil
    self.illuminator.clean.noDelay = nil
    self.illuminator.task.build = nil
    self.illuminator.task.setSim = nil
    self.illuminator.task.coverage = nil
    self.illuminator.task.report = nil
    self.illuminator.hardwareID = nil

    self.simulator.device = nil
    self.simulator.version = nil
    self.simulator.language = nil
    self.simulator.killAfter = nil

    self.instruments.doVerbose = nil
    self.instruments.timeout = nil
    self.instruments.attempts = nil
    self.instruments.appLocation = nil  # normally, this is where we build to

    self.javascript.testPath = nil
    self.javascript.customConfigPath = nil
    self.javascript.implementation = nil

  end

end
