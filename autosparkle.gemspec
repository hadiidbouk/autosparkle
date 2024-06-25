# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name                   = 'autosparkle'
  spec.version                = '0.0.2'
  spec.authors                = ['Hadi Dbouk']
  spec.email                  = ['hadiidbouk@gmail.com']
  spec.summary                = 'Automate macOS app delivery outside the App Store'
  spec.description            = 'Autosparkle is a command-line tool that automates the delivery of macOS apps outside the App Store. It is designed to be used in CI/CD pipelines to automate the process of archiving, signing, notarizing, and distributing macOS apps.'
  spec.homepage               = 'https://github.com/hadiidbouk/autosparkle'
  spec.license                = 'MIT'
  spec.required_ruby_version  = '>= 2.5.0'

  spec.files         = Dir['lib/**/*', 'bin/*', 'README.md', 'LICENSE.txt']
  spec.bindir        = 'bin'
  spec.executables   = ['autosparkle']

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.add_development_dependency 'rake', '~> 10.0'

  spec.add_runtime_dependency 'aws-sdk-s3', '~> 1.152.3'
  spec.add_runtime_dependency 'colorize', '~> 1.1.0'
  spec.add_runtime_dependency 'dotenv', '~> 3.1.2'
  spec.add_runtime_dependency 'nokogiri', '~> 1.16.6'
  spec.add_runtime_dependency 'xcodeproj', '~> 1.24.0'

  spec.post_install_message = <<~MESSAGE
    ###################################### AUTOSPAKRLE ######################################

    Thank you for installing AutoSparkle!

    To use AutoSparkle in your terminal, you need to update your shell configuration files.
    Add the following line to your shell configuration file (e.g., ~/.bashrc, ~/.zshrc):
      export PATH="<<YOUR_GEMS_DIR>>/autosparkle-x.x.x/bin:$PATH"

    After updating your shell configuration file, run the following command:
      source ~/.bashrc or source ~/.zshrc

    For more information, visit the AutoSparkle GitHub repository:
      #{spec.homepage}

    Enjoy using AutoSparkle!

    #########################################################################################

  MESSAGE

  spec.metadata['rubygems_mfa_required'] = 'true'
end
