The ILLUMINATOR Command Line
============================

Illuminator employs a Ruby script wrapper to Instruments, which imposes some order on the somewhat-unreliable Instruments binary and provides other capabilities such as simulator selection and JUnit reporting.

The Basic, Quick-Start Instant-Gratification Command
----------------------------------------------------

Included in the gem's `bin/` directory is `bin/illuminatorTestRunner.rb` -- a script that exposes Illuminator's core options on the command line.

```
$ gem/bin/illuminatorTestRunner.rb --help
Usage: illuminatorTestRunner.rb [options]
    -A, --buildArtifacts PATH        The directory in which to store build artifacts   ::   Defaults to "/Users/iakatz/Code Base/ios-here-newgen/libs/ios-automator/buildArtifacts"
    -y, --clean PLACES               Comma-separated list of places to clean {xcode, buildArtifacts, derivedData}
    -f, --skip-build                 Just automate; assume already built   ::   Defaults to "false"
    -E, --appLocation LOCATION       Location of app executable, if pre-built
    -B, --skip-automate              Don't automate; build only   ::   Defaults to "false"
    -r, --retest OPTIONS             Immediately retest failed tests with comma-separated options {1x, solo}
    -c, --coverage                   Generate coverage files   ::   Defaults to "false"
  ---------------------------------------------------------------------------------
    -a, --appName APPNAME            Name of the app to build / run
    -D, --xcodeProjectDirectory PATH Directory containing the Xcode project to build
    -P, --xcodeProject PROJECTNAME   Project to build -- required if there are 2 in the same directory
    -W WORKSPACENAME,                Workspace to build
        --xcodeWorkspace
    -q, --sdk SDK                    SDK to build against   ::   Defaults to "iphonesimulator"
    -s, --scheme SCHEME              Build and run specific tests on given workspace scheme
  ---------------------------------------------------------------------------------
    -d, --hardwareID ID              hardware id of device to run on instead of simulator
    -b, --simDevice DEVICE           Run on given simulated device   ::   Defaults to "iPhone 5"
    -z, --simVersion VERSION         Run on given simulated iOS version   ::   Defaults to "8.2"
    -l, --simLanguage LANGUAGE       Run on given simulated iOS language   ::   Defaults to "en"
    -e, --skip-set-sim               Assume that simulator has already been chosen and properly reset   ::   Defaults to "false"
    -k, --skip-kill-after            Leave the simulator open after the run   ::   Defaults to "false"
  ---------------------------------------------------------------------------------
    -v, --verbose                    Show verbose output from instruments
    -m, --timeout TIMEOUT            Seconds to wait for instruments tool to start tests   ::   Defaults to "30"
    -p, --testPath PATH              Path to js file with all tests imported
  ---------------------------------------------------------------------------------
    -x, --entryPoint LABEL           The execution entry point {runTestsByTag, runTestsByName, describe}   ::   Defaults to "runTestsByTag"
    -t, --tags-any TAGSANY           Run tests with any of the given tags
    -o, --tags-all TAGSALL           Run tests with all of the given tags
    -n, --tags-none TAGSNONE         Run tests with none of the given tags
    -i, --implementation IMPL        Device tests implementation
    -w, --random-seed SEED           Randomize test order based on given integer seed
  ---------------------------------------------------------------------------------
    -h, --help                       Show this help message
```

By simply pointing to your top-level Javascript file, this script can serve your needs for testing.

> Note: All the `Illuminator::Options` options that are exposed by the parser are referred to by their single-character switches as shown here. See "Using and Extending the Illuminator Argument Parser" below.


A Better Command-Line Script
----------------------------

Many of the options you want to send to Illuminator will be the same every time.  It would make sense to simply hard-code these values into your own command-line ruby script.

For example, the Illuminator Sample App [`smokeTests.rb`](../SampleApp/smokeTests.rb) script:

```ruby
require 'bundler/setup'
require 'illuminator'

# Change directory to sample app and use that for the project dir
Dir.chdir File.expand_path(File.dirname(__FILE__))

all_test_path = 'SampleTests/tests/AllTests.js'
all_test_path = Illuminator::HostUtils.realpath(all_test_path)

# Hard-coded options

options = Illuminator::Options.new
options.build_artifacts_dir = File.join(Dir.pwd, "buildArtifacts")
options.xcode.app_name = 'AutomatorSampleApp'
options.xcode.scheme = 'AutomatorSampleApp'
options.xcode.workspace = 'AutomatorSampleApp.xcworkspace'
options.xcode.project_dir = Dir.pwd


options.illuminator.entry_point = 'runTestsByTag'
options.illuminator.test.tags.any = ['smoke']
options.illuminator.clean.xcode = true
options.illuminator.clean.artifacts = true
options.illuminator.clean.no_delay = true
options.illuminator.task.build = true
options.illuminator.task.automate = true
options.illuminator.task.set_sim = true
options.simulator.device = 'iPhone 5'
options.simulator.language = 'en'
options.simulator.kill_after = true

options.instruments.do_verbose = false
options.instruments.timeout = 30

options.javascript.test_path = all_test_path
options.javascript.implementation = 'iPhone'

if Illuminator::XcodeUtils.instance.is_xcode_major_version 5
  options.simulator.device = 'iPhone Retina (4-inch)'
end

options.simulator.version = '8.1'
success8 = Illuminator::run_with_options options

options.illuminator.clean.xcode = false
options.illuminator.clean.artifacts = false
options.illuminator.task.build = false
options.simulator.version = '7.1'
success7 = Illuminator::run_with_options options

exit 1 unless success7 and success8
```

In short:
1. the options object is created with `Illuminator::Options.new`
2. the object is filled in with values _(see below)_
3. the framework is run with those options: `Illuminator::run_with_options options'
4. the framework returns a result which in turn is returned to the shell


Illuminator Options
--------------------

The following options are defined in Illuminator (assuming `options = Illuminator::Options.new`).

#### `options.build_artifacts_dir`

The output directory for all Xcode, Instruments, Illuminator, and app-specific javascript artifacts.  This directory will be automatically created if it does not exist.


### Xcode options

#### `options.xcode.project_dir` (string)
The path containing the Xcode project to build.

#### `options.xcode.project` (string)
The project name to build, available in the directory identified by the `project_dir` parameter.  This argument is optional unless you have more than one project in that directory.

#### `options.xcode.app_name` (string)
The name of the application that will be built by Xcode (and run by Instruments)

#### `options.xcode.workspace` (string)
The Xcode workspace directory to use (e.g. a path typically ending in `.xcworkspace`).

#### `options.xcode.sdk` (string)
The SDK that will be used by Xcode.  This defaults to `iphonesimulator` for simulator runs, and `iphoneos` for real hardware runs, so there should be no reason to supply it manually.

#### `options.xcode.scheme` (string)
The scheme to build, corresponding to a scheme in the given Xcode project.

#### `options.xcode.environment_vars` (hash)
A hash of any project-specific environment variables that should be specified on the `xcodebuild` command line.


### Illuminator options

#### `options.illuminator.entry_point` (string)
The major function that will be performed by Illuminator -- can be one of `runTestsByTag`, `runTestsByName`, `describe`.
* `runTestsByTag` parses the three `.test.tags.*` options (below) to decide which set of tests should be run
* `runTestsByName` uses the `.test.names` option for the list of tests to run
* `describe` simply prints out descriptions of the test environment for documentation or debugging purposes.

#### `options.illuminator.test.random_seed` (integer)
If provided, Illuminator uses this value as a seed to randomize the order of the test runs.

#### `options.illuminator.test.tags.any` (string array)
Under the `runTestsByTag` entry point, this option specifies that any tests with a tag in this list will be selected to run, unless overridden by one of the other two `.test.tags.*` options.

#### `options.illuminator.test.tags.all` (string array)
Under the `runTestsByTag` entry point, this option specifies that only tests that include _all_ tags in this list will be selected to run.

#### `options.illuminator.test.tags.none` (string array)
Under the `runTestsByTag` entry point, this option specifies that any tests that include _any_ tags in this list will **not** be selected to run.

#### `options.illuminator.test.names` (string array)
Under the `runTestsByName` entry point, this option specifies the list of tests (in order) that should be run.

#### `options.illuminator.test.retest.attempts` (integer)
Under the `runTestsByTag` and `runTestsByName` entry point, this specifies the number of times that failed tests will be re-tested.

#### `options.illuminator.test.retest.solo` (boolean)
When retesting failed tests, this option specifies that they should be run in their own individual Instruments instance, without any other tests.

#### `options.illuminator.clean.xcode` (boolean)
This option specfies that `xcodebuild` should clean the project before building.

#### `options.illuminator.clean.derived` (boolean)
This option specifies that the `DerivedData` directory should be deleted before building.

#### `options.illuminator.clean.artifacts` (boolean)
This option specifies that the entire Illuminator `build_artifacts_dir` should be deleted before building.

#### `options.illuminator.clean.no_delay` (boolean)
This option specifes that the default 3-second command-line countdown (giving you a chance to abort any directory deletions) will be skipped.

#### `options.illuminator.task.build` (boolean)
This option specifies that the Xcode project should be built before automating, even if it has already been built.

#### `options.illuminator.task.automate` (boolean)
This option specifies that the Instruments automation should run.

#### `options.illuminator.task.set_sim` (boolean)
This option specifies that Illuminator should select and reset the simulator from the command line.

#### `options.illuminator.task.coverage` (boolean)
This option specifies that `gcovr` should be run after the automation completes, to determine coverage.  This coverage report will only include the last set of tests that ran without crashing.

#### `options.illuminator.hardware_id` (string)
This option specifies that the automation should run on physical hardware, specified by the ID.


### Simulator options

#### `options.simulator.device` (string)
This option selects the simulator device that should be run.

#### `options.simulator.version` (string)
This option selects the iOS version of the simulator.

#### `options.simulator.language` (string)
This option selects the language of the simulator (currently unsupported).

#### `options.simulator.kill_after` (boolean)
This option specifies whether to close the simulator after automation is complete.


### Instruments options

#### `options.instruments.do_verbose` (boolean)
This option specifies whether verbose output (vs pretty output) of Instruments is sent to the console.  Full output of Instruments is logged to disk regardless.

#### `options.instruments.timeout` (integer)
The number of seconds to spend waiting for Instruments to start up and begin executing the Javascript code, before simply killing it and starting again.

#### `options.instruments.attempts` (integer)
The number of times to attempt starting and restarting Instruments before giving up.
> Under Xcode 5, this number needed to be set as high as 30.  No joke.


#### `options.instruments.app_location` (string)
The location of the compiled application that Instruments will automate.  This option should be specified if you are automating a pre-built binary; otherwise, Illuminator defaults to using the application that it built itself and will expect to find it in `options.build_artifacts_dir`.

### Javascript options

#### `options.javascript.test_path` (string)
The location of the Javascript file containing your top-level entry point.  This file should define (or import) all the tests that you have defined.  The specific tests to run will be determined by the `entry_point`.

#### `options.javascript.app_specific_config` (hash)
A hash of values that will be passed into the Javascript environment, made available under `config.customConfig`.  Yes, **Illuminator can pass structured values directly from Ruby, through Instruments, into Javascript**.

#### `options.javascript.implementation` (string)
The implementation to use when automating.  This should match one of the implementations you defined in your [`AppMap`](AppMap.md).



Using and Extending the Illuminator Argument Parser
---------------------------------------------------

Here is an example of how to mix hard-coded values with Illuminator command-line options, as well as custom command-line options.

```ruby
require 'bundler/setup'
require 'illuminator'
require 'pathname'

options = {}

# Set up the default parser
parser_factory = Illuminator::ParserFactory.new

# Prepare the parser.  We will add the switch -g, aka --word-starting-with-g
#   and override -p, aka --ipad to be a simple switch for iPad testing

                       # default values for all the named switches
parser_factory.prepare({"g" => "gundalow", "i" => "myImplementation", "s" => "iPhone", "a" => "My App", "b" => 'iPhone Retina (4-inch)'},
                       # the keys in the output array that will store the values for these command line switches
                      {"g" => "word-starting-with-g", "p" => "do-ipad"},
                       # Custom processing for any switches.  Since we're overriding 'p', we need to nil-out any processing function for it
                      {"p" => nil})
# Add our custom switch, and the replacement switch
parser_factory.add_switch("g", ["-g", "--word-starting-with-g WORD", "A word starting with G, for fun"])
parser_factory.add_switch("p", ["-p", "--do-ipad", "Run ipad implementation"])

# build the parser using letters from IlluminatorArgumentParsing plus our custom ones
parser = parser_factory.build_parser({}, "xtondispaE#bzl#fBeky#crvmw#g")

# Now use the parser to get input arguments
options = parser.parse ARGV


options.javascript.test_path = Illuminator::HostUtils.realpath("path/to/my/AllTests.js")

# Storing our custom value in custom javascript config
storage = {}
storage["gWord"] = options.app_specific["word-starting-with-g"]
options.javascript.app_specific_config = storage

# Setting up several settings at once if iPad was specfied ##########################################

if options.app_specific["do-ipad"]
  options.xcode.app_name = "My App HD"
  options.xcode.scheme = "iPad"
  options.javascript.implementation = "iPad"
  unless options.simulator.device.start_with? "iPad"
    options.simulator.device = 'iPad'
    if XcodeUtils.instance.is_xcode_major_version 6
      options.simulator.device = "iPad 2"
    end
  end
end

# Run it
success = Illuminator::run_with_options options
exit 1 unless success
```

The strangest piece of this code is probably the `"xtondispaE#bzl#fBeky#crvmw#g"`.  This tells the Parser Factor which command line switches to use (by their single-letter code), and the order in which to list them in the help file (`#` indicating separators).

The second-strangest piece of code is probably the `parser_factory.prepare` line.  If you're reading this far, you should [make contact via one of the Help channels listed in the README](../README.md) and ask for help, so that I can improve this documentation based on your questions.  But the comments in [IlluminatorArgumentParsing.rb](../scripts/classes/IlluminatorArgumentParsing.rb) should help somewhat.
