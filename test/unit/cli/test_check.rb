# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Cli::Check, :sync do
  let(:server) { ::HttpStubServer.new }
  let(:dir) { ::Dir.mktmpdir('packman-nova-check-') }
  let(:out) { ::StringIO.new }

  after do
    server.stop
    ::FileUtils.rm_rf(dir)
  end

  it 'probes the prjconf and snapshot URLs' do
    server.on('/prjconf', body: 'x').on('/media', status: 503)
    check = ::PackmanNova::Cli::Check.new(config: sync_config(dir, server), logger: null_logger, out:)

    assert_equal 1, check.call
    assert_match(%r{^ok    obs api    http://.*/prjconf HTTP 200$}, out.string)
    assert_match(/^fail  tw repo    .*HTTP 503/, out.string)
  end
end
