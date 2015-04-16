Installing Illuminator
======================

There are several ways that you might include Illuminator in your iOS project, depending on which features you'd like to take advantage of.


Instant Gratification: Javascript Extensions and Test Runner
------------------------------------------------------------

Illuminator is easiest to use as a complete package, so it's available in gem form for extreme ease of use.  For CI purposes, it's best to do this via [bundler](http://bundler.io/), putting this line in your `Gemfile`:

```ruby
gem 'illuminator'
```

If you'd prefer the most up-to-date Illuminator version, point it at our repository:

```ruby
gem 'illuminator', :git => 'https://github.com/paypal/Illuminator.git'
```

In the PayPal Here repository (from which Illuminator was born), we include Illuminator as a git submodule and link to it locally in the Gemfile:

```ruby
gem 'illuminator', :path => 'relative/path/to/illuminator'
```


### Javascript Extensions Only

If you're using a separate test runner (like Bwoken) and are only interested in the Javasript extensions, imply add the following 2 lines to your UIAutomation code:

```javascript
#import "/path/to/Illuminator/gem/resources/js/Extensions.js"
IlluminatorScriptsDirectory = "/path/to/Illuminator/gem/resources/scripts";
```

Additionally, if you want to use any of the functionality provided by `simctl` (such as `openURL` or `erase`), then you should define the following as well:

```javascript
config.xcodePath = "/Applications/Xcode.app/Contents/Developer";
config.targetDeviceID = "<one of the UIDs from 'simctl list'>";
config.isHardware = false; // indicate that we are on a simulator
```


Advanced Features: The [Bridge](Bridge.md)
------------------------------------------

The Illuminator automation bridge is easily installed via CocoaPods.  Add this line to your `Podfile`:

```ruby
pod 'Illuminator', :configurations => ['Debug']
```