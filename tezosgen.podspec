Pod::Spec.new do |s|
    s.name             = 'tezosgen'
    s.version          = '1.0.3'
    s.summary          = 'Generate code from abi.json'
  
  # This description is used to generate tags and improve search results.
  #   * Think: What does it do? Why did you write it? What is the focus?
  #   * Try to keep it short, snappy and to the point.
  #   * Write the description between the DESC delimiters below.
  #   * Finally, don't worry about the indent, CocoaPods strips it!
  
    s.description      = "Generate code from abi.json using Swift tool."
  
    s.homepage         = 'https://github.com/AckeeCZ/tezosgen.git'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'Ackee' => 'info@ackee.cz' }
    s.source = { http: "https://github.com/AckeeCZ/tezosgen/releases/download/#{s.version}/tezosgen-#{s.version}.zip" }
    s.preserve_paths = '*'
    s.ios.deployment_target = "13.0"
    s.swift_version = "5.1"
    s.dependency 'TezosSwift', '~> 1.1'
  end
  
