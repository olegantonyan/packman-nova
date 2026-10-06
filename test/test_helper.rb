# frozen_string_literal: true

$LOAD_PATH.unshift(::File.expand_path('../lib', __dir__))
require 'packman_nova'

require 'minitest/autorun'
require 'minitest/fail_fast'
require 'stringio'
require 'tmpdir'

require 'support/http_stub_server'
require 'support/git_fixture'

class PackmanNovaSpec < ::Minitest::Spec
  FIXTURES_DIR = ::File.expand_path('fixtures', __dir__)

  def fixture_path(*parts)
    ::File.join(FIXTURES_DIR, *parts)
  end

  def with_tmpdir(&)
    ::Dir.mktmpdir('packman-nova-test-', &)
  end

  def with_env(vars)
    saved = ::ENV.to_h
    vars.each { |key, value| value.nil? ? ::ENV.delete(key) : ::ENV.store(key, value) }
    yield
  ensure
    ::ENV.replace(saved)
  end

  def string_logger(level: ::Logger::DEBUG, filters: [])
    io = ::StringIO.new
    [::PackmanNova::Logging::Logger.new(outputs: [io], level:, filters:), io]
  end

  def null_logger
    ::PackmanNova::Logging::Logger.new(outputs: [::StringIO.new], level: ::Logger::DEBUG)
  end

  def load_config(env: {}, cwd: nil, **)
    with_env(env) do
      cwd ? ::PackmanNova::Config.load(cwd:, **) : with_tmpdir { |dir| ::PackmanNova::Config.load(cwd: dir, **) }
    end
  end
end

::Minitest::Spec.register_spec_type(//, ::PackmanNovaSpec)

require 'support/sync_spec'
require 'support/site_spec'
