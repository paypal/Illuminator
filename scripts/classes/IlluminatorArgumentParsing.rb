require 'optparse'
require 'ostruct'

require File.join(File.expand_path(File.dirname(__FILE__)), 'IlluminatorOptions.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'HostUtils.rb')


class IlluminatorParser < OptionParser
  def initialize options
    super
    @_options = options
  end


  def checkRetestArgs
    knownRetests = ["solo"]

    @_options["retest"] = [] if @_options["retest"].nil?

    @_options["retest"].each do |r|
      if knownRetests.include? r
        # ok
      elsif /^\d+x$/.match(r)
        # ok (1x, 2x, 3x...)
      else
        puts "Got unknown --retest specifier '#{r}'".yellow
      end
    end
  end

  def getMaxRetests
    ret = 0
    @_options["retest"].each do |r|
      matches = /^(\d+)x$/.match(r)
      unless matches.nil?
        ret = [ret, matches[1].to_i].max
      end
    end
    ret
  end

  def checkCleanArgs
    knownCleans = ["xcode", "buildArtifacts", "derivedData", "noDelay"]

    @_options["clean"] = [] if @_options["clean"].nil?

    @_options["clean"].each do |c|
      unless knownCleans.include? c
        puts "Got unknown --clean specifier '#{c}'".yellow
      end
    end
  end

  # copy internal options storage into a options object
  def copyParsedOptionsInto(illuminatorOptions)
    self.checkCleanArgs
    self.checkRetestArgs

    # load up known illuminatorOptions
    # we only load non-nil options, just in case there was already something in the illuminatorOptions obj
    illuminatorOptions.xcode.appName = @_options["appName"] unless @_options["appName"].nil?
    illuminatorOptions.xcode.sdk     = @_options["sdk"] unless @_options["sdk"].nil?
    illuminatorOptions.xcode.scheme  = @_options["scheme"] unless @_options["scheme"].nil?

    illuminatorOptions.illuminator.entryPoint      = @_options["entryPoint"] unless @_options["entryPoint"].nil?
    illuminatorOptions.illuminator.test.randomSeed = @_options["randomSeed"].to_i unless @_options["randomSeed"].nil?
    illuminatorOptions.illuminator.test.tags.any   = @_options["tagsAny"] unless @_options["tagsAny"].nil?
    illuminatorOptions.illuminator.test.tags.all   = @_options["tagsAll"] unless @_options["tagsAll"].nil?
    illuminatorOptions.illuminator.test.tags.none  = @_options["tagsNone"] unless @_options["tagsNone"].nil?

    illuminatorOptions.illuminator.test.retest.attempts = getMaxRetests
    illuminatorOptions.illuminator.test.retest.solo     = @_options["retest"].include? "solo"

    illuminatorOptions.illuminator.clean.xcode     = @_options["clean"].include? "xcode"
    illuminatorOptions.illuminator.clean.derived   = @_options["clean"].include? "derivedData"
    illuminatorOptions.illuminator.clean.artifacts = @_options["clean"].include? "buildArtifacts"
    illuminatorOptions.illuminator.clean.noDelay   = @_options["clean"].include? "noDelay"

    illuminatorOptions.illuminator.task.build    = (not @_options["skipBuild"]) unless @_options["skipBuild"].nil?
    illuminatorOptions.illuminator.task.automate = (not @_options["skipAutomate"]) unless @_options["skipAutomate"].nil?
    illuminatorOptions.illuminator.task.setSim   = (not @_options["skipSetSim"]) unless @_options["skipSetSim"].nil?
    illuminatorOptions.illuminator.task.coverage = @_options["coverage"] unless @_options["coverage"].nil?
    illuminatorOptions.illuminator.hardwareID    = @_options["hardwareID"] unless @_options["hardwareID"].nil?

    illuminatorOptions.simulator.device    = @_options["simDevice"] unless @_options["simDevice"].nil?
    illuminatorOptions.simulator.version   = @_options["simVersion"] unless @_options["simVersion"].nil?
    illuminatorOptions.simulator.language  = @_options["simLanguage"] unless @_options["simLanguage"].nil?
    illuminatorOptions.simulator.killAfter = (not @_options["skipKillAfter"]) unless @_options["skipKillAfter"].nil?

    illuminatorOptions.instruments.appLocation = @_options["appLocation"] unless @_options["appLocation"].nil?
    illuminatorOptions.instruments.doVerbose   = @_options["verbose"] unless @_options["verbose"].nil?
    illuminatorOptions.instruments.timeout     = @_options["timeout"].to_i unless @_options["timeout"].nil?

    illuminatorOptions.javascript.testPath       = @_options["testPath"] unless @_options["testPath"].nil?
    illuminatorOptions.javascript.implementation = @_options["implementation"] unless @_options["implementation"].nil?
    illuminatorOptions.javascript.customConfig   = JSON.parse(IO.read(@_options["customSettingsJSONPath"])) unless @_options["customSettingsJSONPath"].nil?

    knownKeys = IlluminatorParserFactory.new.letterMap.values # get option keynames from a plain vanilla factory

    # load up unknown illuminatorOptions
    illuminatorOptions.appSpecific = @_options.select { |keyname, _| not (knownKeys.include? keyname) }

    return illuminatorOptions
  end

  def parse args
    leftovers = super(args)
    return self.copyParsedOptionsInto(IlluminatorOptions.new)
  end

end

class IlluminatorParserFactory

  attr_reader :letterMap

  # the currency of this parser factory is the "short" single-letter argument switch
  def initialize()
    @options = nil
    @switches = {}

    # build the list of how each parameter will be saved in the output
    @letterMap = {
      'x' => 'entryPoint',
      'p' => 'testPath',
      'a' => 'appName',
      'P' => 'xcodeProject',
      't' => 'tagsAny',
      'o' => 'tagsAll',
      'n' => 'tagsNone',
      'q' => 'sdk',
      's' => 'scheme',
      'j' => 'customSettingsJSONPath',
      'd' => 'hardwareID',
      'i' => 'implementation',
      'E' => 'appLocation',
      'b' => 'simDevice',
      'z' => 'simVersion',
      'l' => 'simLanguage',
      'f' => 'skipBuild',
      'B' => 'skipAutomate',
      'e' => 'skipSetSim',
      'k' => 'skipKillAfter',
      'c' => 'coverage',
      'r' => 'retest',
      'v' => 'verbose',
      'm' => 'timeout',
      'w' => 'randomSeed',
      'y' => 'clean',
    }

    @letterProcessing = {
      'j' => lambda {|p| HostUtils.realpath(p) },     # get real path to settings file
      'p' => lambda {|p| HostUtils.realpath(p) },     # get real path to tests file
      'E' => lambda {|p| HostUtils.realpath(p) },     # get real path to app
      'y' => lambda {|p| p.split(',')},               # split comma-separated string into array
      'r' => lambda {|p| p.split(',')},               # split comma-separated string into array
      't' => lambda {|p| p.split(',')},               # split comma-separated string into array
      'o' => lambda {|p| p.split(',')},               # split comma-separated string into array
      'n' => lambda {|p| p.split(',')},               # split comma-separated string into array
    }

    @defaultValues = {
      'b' => 'iPhone',
      'z' => '7.1',
      'q' => 'iphonesimulator7.1',
      'l' => 'en',
      'x' => 'runTestsByTag',
      'm' => 30,
      'f' => false,
      'B' => false,
      'e' => false,
      'k' => false,
      'c' => false,
    }
  end

  # you must custom prepare before you can add custom switches... otherwise things get all stupid
  def prepare(defaultValues = nil, letterMapUpdates = nil, letterProcessingUpdates = nil)
    @letterMap = @letterMap.merge(letterMapUpdates) unless letterMapUpdates.nil?
    @letterProcessing = @letterProcessing.merge(letterProcessingUpdates) unless letterProcessingUpdates.nil?
    @defaultValues = @defaultValues.merge defaultValues unless defaultValues.nil?

    self.addSwitch('x', ['-x', '--entryPoint LABEL', 'The execution entry point (runTestsByTag, runTestsByName, describe)'])
    self.addSwitch('p', ['-p', '--testPath PATH', 'Path to js file with all tests imported'])
    self.addSwitch('a', ['-a', '--appName APPNAME', "Name of the app to run"])
    self.addSwitch('P', ['-P', '--xcodeProject PROJECTNAME', "Project to build -- required if there are 2 in the same directory"])
    self.addSwitch('t', ['-t', '--tags-any TAGSANY', 'Run tests with any of the given tags'])
    self.addSwitch('o', ['-o', '--tags-all TAGSALL', 'Run tests with all of the given tags'])
    self.addSwitch('n', ['-n', '--tags-none TAGSNONE', 'Run tests with none of the given tags'])
    self.addSwitch('q', ['-q', '--sdk SDK', 'SDK to build against, defaults to iphonesimulator8.1'])
    self.addSwitch('s', ['-s', '--scheme SCHEME', 'Build and run specific tests on given workspace scheme'])
    self.addSwitch('j', ['-j', '--jsonSettingsPath PATH', 'path to JSON file containing custom configuration parameters'])
    self.addSwitch('d', ['-d', '--hardwareID ID', 'hardware id of device you run on'])
    self.addSwitch('i', ['-i', '--implementation IMPL', 'Device tests implementation (iPhone|iPad)'])
    self.addSwitch('E', ['-E', '--appLocation LOCATION', 'Location of app executable, if pre-built'])
    self.addSwitch('b', ['-b', '--simDevice DEVICE', 'Run on given simulated device'])
    self.addSwitch('z', ['-z', '--simVersion VERSION', 'Run on given simulated iOS version'])
    self.addSwitch('l', ['-l', '--simLanguage LANGUAGE', 'Run on given simulated iOS language'])
    self.addSwitch('f', ['-f', '--skip-build', 'Just automate; assume already built'])
    self.addSwitch('B', ['-B', '--skip-automate', "Don't automate; build only"])
    self.addSwitch('e', ['-e', '--skip-set-sim', 'Assume that simulator has already been chosen and properly reset'])
    self.addSwitch('k', ['-k', '--skip-kill-after', 'Do not kill the simulator after the run'])
    self.addSwitch('y', ['-y', '--clean PLACES', 'Comma-separated list of places to clean {xcode, buildArtifacts, derivedData}'])
    self.addSwitch('c', ['-c', '--coverage', 'Generate coverage files'])
    self.addSwitch('r', ['-r', '--retest OPTIONS', 'Immediately retest failed tests with comma-separated options {1x, solo}'])
    self.addSwitch('v', ['-v', '--verbose', 'Show verbose output'])
    self.addSwitch('m', ['-m', '--timeout TIMEOUT', 'startup timeout'])
    self.addSwitch('w', ['-w', '--random-seed SEED', 'Randomize test order based on given integer seed'])
  end

  # add a parse switch for the given letter key, using the given options.
  #   the parse action is defined by the existence of letterProcessing for the letter key,
  #   which by default is simple assignment
  def addSwitch(letter, opts)
    dest = self.getLetterDestination(letter)

    # alter opts to include the default values
    altered = false
    if @defaultValues[letter].nil?
      opts_with_default = opts
    else
      opts_with_default = opts.map do |item|
        if (!altered and item.chars.first != '-')
          item += "        Defaults to \"#{@defaultValues[letter]}\""
          altered = true
        end
        item
      end
    end

    @switches[letter] = OpenStruct.new(:opts => opts_with_default,
                                       :block => lambda do |newval|
                                         # assign the parsed value to the output, processing it if necessary
                                         if @letterProcessing[letter]
                                           @options[dest] = @letterProcessing[letter].call(newval)
                                         else
                                           @options[dest] = newval
                                         end
                                       end)
  end


  # letter destination defaults to the letter itself, but can be overwritten by letterMap
  def getLetterDestination(letter)
    return @letterMap[letter]? @letterMap[letter] : letter
  end


  # factory function
  def buildParser(options, letters = nil)
    @options = options

    if letters.nil?
      letters = switches.keys.join('')
    end

    # helpful error message for bad chars
    bad_chars = letters.chars.to_a.select{|c| c != "#" and @switches[c].nil?}
    raise ArgumentError, "buildParser got letters (" + letters + ") containing unknown option characters: " + bad_chars.to_s unless bad_chars.empty?

    retval = IlluminatorParser.new options

    # build a parser as specified by the user
    letters.each_char do |c|
      options[self.getLetterDestination(c)] = @defaultValues[c] unless @defaultValues[c].nil?

      if c == '#'
        retval.separator('  ---------------------------------------------------------------------------------')
      else
        retval.on(*(@switches[c].send(:opts))) {|foo| @switches[c].send(:block).call(foo)}
      end
    end

    # help message is hard coded!
    retval.on_tail('-h', '--help', 'Show this help message') {|foo| puts retval.help(); exit  }

    #puts retval
    return retval
  end

end
