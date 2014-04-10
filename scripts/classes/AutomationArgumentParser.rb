require File.join(File.expand_path(File.dirname(__FILE__)), 'PlistEditor.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'AutomationArgumentParserFactory.rb')

class AutomationArgumentParser
  def parse args

    options = {}
    parserFactory = AutomationParserFactory.new()
    parserFactory.prepare()
    parser = parserFactory.buildParser(options, "xpatonsjdi#bzl#fek#crvmw")

    parser.parse! args
    return options
  end


  def readFromPath path
    storage = PLISTStorage.new
    return storage.readFromStorageAtPath path
  end


end
