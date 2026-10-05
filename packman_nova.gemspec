# frozen_string_literal: true

require_relative 'lib/packman_nova/version'

::Gem::Specification.new do |spec|
  spec.name = 'packman-nova'
  spec.version = ::PackmanNova::VERSION
  spec.authors = ['Oleg Antonyan']
  spec.email = ['oleg.b.antonyan@gmail.com']

  spec.summary = 'Rebuilds Packman Essentials for openSUSE Tumbleweed with pbuild and publishes a signed rpm-md repo'
  spec.homepage = 'https://packman.omnipackage.org'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 4.0'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = ::Dir.glob('{exe,lib,config,container,prjconf}/**/*', base: __dir__).select { |f| ::File.file?(::File.join(__dir__, f)) }
  spec.bindir = 'exe'
  spec.executables = ['packman-nova']
  spec.require_paths = ['lib']

  spec.add_dependency 'aws-sdk-s3', '~> 1'
  spec.add_dependency 'base64'
  spec.add_dependency 'dotenv'
  spec.add_dependency 'logger'
  spec.add_dependency 'rexml'
end
