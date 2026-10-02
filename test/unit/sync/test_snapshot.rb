# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Sync::Snapshot do
  let(:server) { ::HttpStubServer.new }

  def snapshot(offline: false)
    http = ::PackmanNova::Utils::Http.new(logger: null_logger, timeout_sec: 5, retries: 0, offline: offline)
    downloader = ::PackmanNova::Sources::Downloader.new(http: http, logger: null_logger, offline: offline)
    ::PackmanNova::Sync::Snapshot.new(url: server.url('/media'), downloader: downloader, logger: null_logger)
  end

  after { server.stop }

  it 'extracts the snapshot date from media.1/media' do
    server.on('/media', body: "openSUSE - openSUSE-20260924-x86_64-Build6.115\nopenSUSE-20260924-x86_64-Build6.115\n1\n")

    assert_equal '20260924', snapshot.call
  end

  it 'keeps the previous value when offline or unreachable' do
    server.on('/media', status: 404)

    assert_equal '20260920', snapshot(offline: true).call(previous: '20260920')
    assert_equal '20260920', snapshot.call(previous: '20260920')
  end
end
