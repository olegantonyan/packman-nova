# frozen_string_literal: true

require 'test_helper'
require_relative '../sync/sync_fixture'

describe ::PackmanNova::Sources::Reachability do
  include ::SyncFixture

  let(:server) { ::HttpStubServer.new }
  let(:dir) { ::Dir.mktmpdir('packman-nova-reach-') }
  let(:http) { ::PackmanNova::Utils::Http.new(logger: null_logger, timeout_sec: 5, retries: 0) }

  after do
    server.stop
    ::FileUtils.rm_rf(dir)
  end

  it 'probes the OBS API, the Tumbleweed repo and PMBS from the default config' do
    probes = ::PackmanNova::Sources::Reachability.new(config: load_config(env: { 'PACKMAN_NOVA_WORKDIR' => '/w' }), logger: null_logger).probes

    assert_equal ['obs api', 'tw repo', 'pmbs'], probes.map(&:first)
    assert_equal 'https://api.opensuse.org/public/source/openSUSE:Factory/_config', probes.first[1]
  end

  it 'fails for OBS and Tumbleweed but only warns for PMBS' do
    server.on('/obs/source/openSUSE:Factory/_config', body: 'x').on('/media', status: 503)
    results = ::PackmanNova::Sources::Reachability.new(config: sync_config(dir, server), logger: null_logger, http: http).call

    assert_equal([[:ok, 'obs api'], [:fail, 'tw repo'], [:warn, 'pmbs']], results.map { |status, name, _detail| [status, name] })
  end
end
