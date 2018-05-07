
Pod::Spec.new do |s|
  s.name             = "IlluminatorBridge"
  s.version          = "1.0.0"
  s.summary          = "Automation bridge for ILLUMINATOR"
  s.description      = <<-DESC
                        Provides a backend channel for interacting with an app during UIAutomation
                       DESC




  s.homepage         = "https://github.com/paypal/Illuminator"
  s.license          = 'Apache License, Version 2.0'
  s.author           = ["Boris Erceg", "Ian Katz"]
  s.source           = { :git => "https://github.com/paypal/Illuminator.git", :tag => s.version.to_s }
  s.platform         = :ios, '9.0'
  s.requires_arc     = true

  s.source_files     = 'Pod/Bridge/*.{c,h,hh,m,mm,swift}'


end
