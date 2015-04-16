# coding: utf-8
lib = File.expand_path('../gem/lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'illuminator/version'

Pod::Spec.new do |s|
  s.name         = "Illuminator"
  s.version      = Illuminator::VERSION
  s.summary      = "ILLUMINATOR - the iOS Automator"
  s.description  = <<-DESC
  Illuminator enables continuous integration for iOS apps. It makes it easy (well, easier) to write and debug sophisticated app tests. Additionally, it makes the entire UIAutomation apparatus more capable of handling high-volume automated testing -- providing features that are missing from Apple's "Instruments" application.
                   DESC
  s.homepage     = "https://github.com/paypal/illuminator"
  s.license      = 'Apache License, Version 2.0'
  s.authors      = ["Boris Erceg", "Ian Katz"]
  s.platform     = :ios
  s.ios.deployment_target = "6.0"
  s.source       = { :git => "https://github.com/paypal/Illuminator.git", :tag => s.version.to_s }
  s.source_files = "pod/PPAutomationBridge/*.{h,m}"
  s.public_header_files = "pod/PPAutomationBridge/*.h"
end
