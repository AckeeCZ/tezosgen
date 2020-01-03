Pod::Spec.new do |s|
    s.name             = 'TezosGen'
    s.version          = '1.1.1'
    s.summary          = 'Generate code from abi.json'
  
    s.description      = "Generate code from abi.json using Swift tool."
  
    s.homepage         = 'https://github.com/AckeeCZ/tezosgen.git'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'Ackee' => 'info@ackee.cz' }
    s.source = { http: "https://github.com/AckeeCZ/tezosgen/releases/download/#{s.version}/tezosgen-#{s.version}.zip" }
    s.preserve_paths = '*'
    s.ios.deployment_target = "13.0"
    s.swift_version = "5.1"
    s.dependency 'TezosSwift', '~> 1.1.1'
  end
  
