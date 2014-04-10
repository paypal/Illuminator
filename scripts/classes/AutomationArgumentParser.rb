require File.join(File.expand_path(File.dirname(__FILE__)), 'PlistEditor.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'AutomationArgumentParserFactory.rb')

class AutomationArgumentParser
  def parse args

    options = {}
    parserFactory = AutomationParserFactory.new({
                                                  "x" => "defaultXcode",
                                                  "p" => "testPath",
                                                  "a" => "appName",
                                                  "t" => "tagsAny",
                                                  "o" => "tagsAll",
                                                  "n" => "tagsNone",
                                                  "s" => "scheme",
                                                  "j" => "plistSettingsPath",
                                                  "d" => "hardwareID",
                                                  "i" => "implementation",
                                                  "b" => "simdevice",
                                                  "z" => "simversion",
                                                  "l" => "simlanguage",
                                                  "f" => "skipBuild",
                                                  "e" => "skipSetSim",
                                                  "k" => "skipKillAfter",
                                                  "c" => "coverage",
                                                  "r" => "report",
                                                  "v" => "verbose",
                                                  "m" => "timeout",
                                                  "w" => "randomSeed",
                                                },
                                                {
                                                  "j" => lambda {|p| (Pathname.new p).realpath().to_s },
                                                  "y" => lambda {|p| self.readFromPath p },
                                                })
    parser = parserFactory.buildParser(options, "xpatonsjdi#bzl#fek#crvmw")

    parser.parse! args
    return options
  end


  def readFromPath path
    storage = PLISTStorage.new
    return storage.readFromStorageAtPath path
  end


end
