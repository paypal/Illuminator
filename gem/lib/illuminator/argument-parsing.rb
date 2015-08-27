require 'optparse'
require 'ostruct'

require_relative './options'
require_relative './host-utils'

module Illuminator

  class Parser < OptionParser
    attr_reader :positional_args

    def initialize options
      super
      @_options = options
    end

    def check_retest_args
      known_retests = ["solo"]

      @_options["retest"] = [] if @_options["retest"].nil?

      @_options["retest"].each do |r|
        if known_retests.include? r
          # ok
        elsif /^\d+x$/.match(r)
          # ok (1x, 2x, 3x...)
        else
          puts "Got unknown --retest specifier '#{r}'".yellow
        end
      end
    end

    def get_max_retests
      ret = 0
      @_options["retest"].each do |r|
        matches = /^(\d+)x$/.match(r)
        unless matches.nil?
          ret = [ret, matches[1].to_i].max
        end
      end
      ret
    end

    def check_clean_args
      known_cleans = ["xcode", "buildArtifacts", "derivedData", "noDelay"]

      @_options["clean"] = [] if @_options["clean"].nil?

      @_options["clean"].each do |c|
        unless known_cleans.include? c
          puts "Got unknown --clean specifier '#{c}'".yellow
        end
      end
    end

    # stupid refactor to make rubocop happy.  ARE YOU HAPPY NOW?
    def _copy_xcode_options_into(illuminatorOptions)
      illuminatorOptions.xcode.app_name       = @_options["app_name"] unless @_options["app_name"].nil?
      illuminatorOptions.xcode.sdk            = @_options["sdk"] unless @_options["sdk"].nil?
      illuminatorOptions.xcode.scheme         = @_options["scheme"] unless @_options["scheme"].nil?
      illuminatorOptions.xcode.workspace      = @_options["xcodeWorkspace"] unless @_options["xcodeWorkspace"].nil?
      illuminatorOptions.xcode.xcconfig       = @_options["xcconfig"] unless @_options["xcconfig"].nil?
    end

    # stupid refactor to make rubocop happy.  ARE YOU HAPPY NOW?
    def _copy_illuminator_options_into(illuminatorOptions)
      illuminatorOptions.illuminator.entry_point      = @_options["entry_point"] unless @_options["entry_point"].nil?
      illuminatorOptions.illuminator.test.random_seed = @_options["random_seed"].to_i unless @_options["random_seed"].nil?
      illuminatorOptions.illuminator.test.tags.any    = @_options["tags_any"] unless @_options["tags_any"].nil?
      illuminatorOptions.illuminator.test.tags.all    = @_options["tags_all"] unless @_options["tags_all"].nil?
      illuminatorOptions.illuminator.test.tags.none   = @_options["tags_none"] unless @_options["tags_none"].nil?

      illuminatorOptions.illuminator.test.retest.attempts = get_max_retests
      illuminatorOptions.illuminator.test.retest.solo     = @_options["retest"].include? "solo"

      illuminatorOptions.illuminator.clean.xcode     = @_options["clean"].include? "xcode"
      illuminatorOptions.illuminator.clean.derived   = @_options["clean"].include? "derivedData"
      illuminatorOptions.illuminator.clean.artifacts = @_options["clean"].include? "buildArtifacts"
      illuminatorOptions.illuminator.clean.noDelay   = @_options["clean"].include? "noDelay"

      illuminatorOptions.illuminator.task.build     = (not @_options["skipBuild"]) unless @_options["skipBuild"].nil?
      illuminatorOptions.illuminator.task.automate  = (not @_options["skipAutomate"]) unless @_options["skipAutomate"].nil?
      illuminatorOptions.illuminator.task.set_sim   = (not @_options["skipSetSim"]) unless @_options["skipSetSim"].nil?
      illuminatorOptions.illuminator.task.coverage  = @_options["coverage"] unless @_options["coverage"].nil?
      illuminatorOptions.illuminator.hardware_id    = @_options["hardware_id"] unless @_options["hardware_id"].nil?
    end

    # stupid refactor to make rubocop happy.  ARE YOU HAPPY NOW?
    def _copy_simulator_options_into(illuminatorOptions)
      illuminatorOptions.simulator.device     = @_options["sim_device"] unless @_options["sim_device"].nil?
      illuminatorOptions.simulator.version    = @_options["sim_version"] unless @_options["sim_version"].nil?
      illuminatorOptions.simulator.language   = @_options["sim_language"] unless @_options["sim_language"].nil?
      illuminatorOptions.simulator.locale     = @_options["sim_locale"] unless @_options["sim_locale"].nil?
      illuminatorOptions.simulator.kill_after = (not @_options["skipKillAfter"]) unless @_options["skipKillAfter"].nil?
    end

    # copy internal options storage into a options object
    def copy_parsed_options_into(illuminatorOptions)
      check_clean_args
      check_retest_args

      # load up known illuminatorOptions
      # we only load non-nil options, just in case there was already something in the illuminatorOptions obj
      illuminatorOptions.build_artifacts_dir = @_options["buildArtifacts"] unless @_options["buildArtifacts"].nil?

      _copy_illuminator_options_into(illuminatorOptions)
      _copy_xcode_options_into(illuminatorOptions)
      _copy_simulator_options_into(illuminatorOptions)

      illuminatorOptions.instruments.app_location = @_options["app_location"] unless @_options["app_location"].nil?
      illuminatorOptions.instruments.do_verbose   = @_options["verbose"] unless @_options["verbose"].nil?
      illuminatorOptions.instruments.timeout      = @_options["timeout"].to_i unless @_options["timeout"].nil?

      illuminatorOptions.javascript.test_path       = @_options["test_path"] unless @_options["test_path"].nil?
      illuminatorOptions.javascript.implementation  = @_options["implementation"] unless @_options["implementation"].nil?

      known_keys = Illuminator::ParserFactory.new.letter_map.values # get option keynames from a plain vanilla factory

      # load up unknown illuminatorOptions
      illuminatorOptions.app_specific = @_options.select { |keyname, _| not (known_keys.include? keyname) }

      return illuminatorOptions
    end

    def parse args
      @positional_args = super(args)
      return copy_parsed_options_into(Illuminator::Options.new)
    end

  end



  class ParserFactory

    attr_reader :letter_map

    # the currency of this parser factory is the "short" single-letter argument switch
    def initialize()
      @options = nil
      @switches = {}

      # build the list of how each parameter will be saved in the output
      @letter_map = {
        'A' => 'buildArtifacts',
        'x' => 'entry_point',
        'p' => 'test_path',
        'a' => 'app_name',
        'D' => 'xcodeProjectDir',
        'P' => 'xcodeProject',
        'W' => 'xcodeWorkspace',
        'X' => 'xcconfig',
        't' => 'tags_any',
        'o' => 'tags_all',
        'n' => 'tags_none',
        'q' => 'sdk',
        's' => 'scheme',
        'd' => 'hardware_id',
        'i' => 'implementation',
        'E' => 'app_location',
        'b' => 'sim_device',
        'z' => 'sim_version',
        'l' => 'sim_language',
        'L' => 'sim_locale',
        'f' => 'skipBuild',
        'B' => 'skipAutomate',
        'e' => 'skipSetSim',
        'k' => 'skipKillAfter',
        'c' => 'coverage',
        'r' => 'retest',
        'v' => 'verbose',
        'm' => 'timeout',
        'w' => 'random_seed',
        'y' => 'clean',
      }

      @letter_processing = {
        'p' => lambda {|p| Illuminator::HostUtils.realpath(p) },     # get real path to tests file
        'E' => lambda {|p| Illuminator::HostUtils.realpath(p) },     # get real path to app
        'y' => lambda {|p| p.split(',')},                            # split comma-separated string into array
        'r' => lambda {|p| p.split(',')},                            # split comma-separated string into array
        't' => lambda {|p| p.split(',')},                            # split comma-separated string into array
        'o' => lambda {|p| p.split(',')},                            # split comma-separated string into array
        'n' => lambda {|p| p.split(',')},                            # split comma-separated string into array
      }

      @default_values = {
        # 'D' => Dir.pwd,   # Since this effectively happens in xcode-builder, DON'T do it here too
        'A' => File.join(Dir.pwd, "buildArtifacts"),
        'b' => 'iPhone 5',
        'z' => '8.2',
        'q' => 'iphonesimulator',
        'l' => 'en',
        'L' => 'en_US',
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
    def prepare(default_values = nil, letter_map_updates = nil, letter_processing_updates = nil)
      @letter_map = @letter_map.merge(letter_map_updates) unless letter_map_updates.nil?
      @letter_processing = @letter_processing.merge(letter_processing_updates) unless letter_processing_updates.nil?
      @default_values = @default_values.merge default_values unless default_values.nil?

      add_switch('A', ['-A', '--buildArtifacts PATH', 'The directory in which to store build artifacts'])
      add_switch('x', ['-x', '--entryPoint LABEL', 'The execution entry point {runTestsByTag, runTestsByName, describe}'])
      add_switch('p', ['-p', '--test_path PATH', 'Path to js file with all tests imported'])
      add_switch('a', ['-a', '--app_name APPNAME', "Name of the app to build / run"])
      add_switch('D', ['-D', '--xcodeProjectDirectory PATH', "Directory containing the Xcode project to build"])
      add_switch('P', ['-P', '--xcodeProject PROJECTNAME', "Project to build -- required if there are 2 in the same directory"])
      add_switch('W', ['-W', '--xcodeWorkspace WORKSPACENAME', "Workspace to build"])
      add_switch('X', ['-X', '--xcconfig PATH', "Path to a custom .xcconfig file"])
      add_switch('t', ['-t', '--tags-any TAGSANY', 'Run tests with any of the given tags'])
      add_switch('o', ['-o', '--tags-all TAGSALL', 'Run tests with all of the given tags'])
      add_switch('n', ['-n', '--tags-none TAGSNONE', 'Run tests with none of the given tags'])
      add_switch('q', ['-q', '--sdk SDK', 'SDK to build against'])
      add_switch('s', ['-s', '--scheme SCHEME', 'Build and run specific tests on given workspace scheme'])
      add_switch('d', ['-d', '--hardware_id ID', 'hardware id of device to run on instead of simulator'])
      add_switch('i', ['-i', '--implementation IMPL', 'Device tests implementation'])
      add_switch('E', ['-E', '--app_location LOCATION', 'Location of app executable, if pre-built'])
      add_switch('b', ['-b', '--simDevice DEVICE', 'Run on given simulated device'])
      add_switch('z', ['-z', '--simVersion VERSION', 'Run on given simulated iOS version'])
      add_switch('l', ['-l', '--simLanguage LANGUAGE', 'Use the given language in the simulator'])
      add_switch('L', ['-L', '--simLocale LOCALE', 'Use the given locale in the simulator'])
      add_switch('f', ['-f', '--skip-build', 'Just automate; assume already built'])
      add_switch('B', ['-B', '--skip-automate', "Don't automate; build only"])
      add_switch('e', ['-e', '--skip-set-sim', 'Assume that simulator has already been chosen and properly reset'])
      add_switch('k', ['-k', '--skip-kill-after', 'Leave the simulator open after the run'])
      add_switch('y', ['-y', '--clean PLACES', 'Comma-separated list of places to clean {xcode, buildArtifacts, derivedData}'])
      add_switch('c', ['-c', '--coverage', 'Generate coverage files'])
      add_switch('r', ['-r', '--retest OPTIONS', 'Immediately retest failed tests with comma-separated options {1x, solo}'])
      add_switch('v', ['-v', '--verbose', 'Show verbose output from instruments'])
      add_switch('m', ['-m', '--timeout TIMEOUT', 'Seconds to wait for instruments tool to start tests'])
      add_switch('w', ['-w', '--random-seed SEED', 'Randomize test order based on given integer seed'])
    end

    # add a parse switch for the given letter key, using the given options.
    #   the parse action is defined by the existence of letter_processing for the letter key,
    #   which by default is simple assignment
    def add_switch(letter, opts)
      dest = get_letter_destination(letter)

      # alter opts to include the default values
      altered = false
      if @default_values[letter].nil?
        opts_with_default = opts
      else
        opts_with_default = opts.map do |item|
          if (!altered and item.chars.first != '-')
            item += "   ::   Defaults to \"#{@default_values[letter]}\""
            altered = true
          end
          item
        end
      end

      @switches[letter] = OpenStruct.new(:opts => opts_with_default,
                                         :block => lambda do |newval|
                                           # assign the parsed value to the output, processing it if necessary
                                           if @letter_processing[letter]
                                             @options[dest] = @letter_processing[letter].call(newval)
                                           else
                                             @options[dest] = newval
                                           end
                                         end)
    end


    # letter destination defaults to the letter itself, but can be overwritten by letter_map
    def get_letter_destination(letter)
      return @letter_map[letter]? @letter_map[letter] : letter
    end


    # factory function
    def build_parser(options, letters = nil)
      @options = options

      if letters.nil?
        letters = switches.keys.join('')
      end

      # helpful error message for bad chars
      bad_chars = letters.chars.to_a.select{|c| c != "#" and @switches[c].nil?}
      unless bad_chars.empty?
        raise ArgumentError, "build_parser got letters (#{letters}) containing unknown option characters: #{bad_chars.to_s}"
      end

      retval = Illuminator::Parser.new options

      # build a parser as specified by the user
      letters.each_char do |c|
        options[get_letter_destination(c)] = @default_values[c] unless @default_values[c].nil?

        if c == '#'
          retval.separator('  ---------------------------------------------------------------------------------')
        else
          retval.on(*(@switches[c].send(:opts))) {|foo| @switches[c].send(:block).call(foo)}
        end
      end

      # help message is hard coded!
      retval.on_tail('-h', '--help', 'Show this help message') {|foo| puts retval.help(); exit  }

      retval.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options]"

      #puts retval
      return retval
    end

  end

end
