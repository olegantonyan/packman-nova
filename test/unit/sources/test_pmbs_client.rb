# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Sources::PmbsClient do
  let(:server) { ::HttpStubServer.new }
  let(:http) { ::PackmanNova::Utils::Http.new(logger: null_logger, timeout_sec: 5, retries: 0) }
  let(:pmbs) { ::PackmanNova::Sources::PmbsClient.new(api: server.url('/pmbs/'), downloader: ::PackmanNova::Sources::Downloader.new(http: http, logger: null_logger)) }

  after { server.stop }

  it 'builds expanded file urls' do
    assert_equal server.url('/pmbs/faac/_service:obs_scm:faac-1.50.obscpio?expand=1'), pmbs.file_url(package: 'faac', file: '_service:obs_scm:faac-1.50.obscpio')
    assert_equal server.url('/pmbs/rtl/a+b.tgz?rev=abc'), pmbs.file_url(package: 'rtl', file: 'a+b.tgz', rev: 'abc')
  end

  it 'resolves a file to a url pinned to the expanded srcmd5' do
    server.on('/pmbs/demo?expand=1', body: ::File.read(fixture_path('sync', 'obs_directory.xml')))
    url, entry = pmbs.resolve(package: 'demo', file: 'demo.spec')

    assert_equal server.url('/pmbs/demo/demo.spec?rev=fac92e8502a9b282a0616cfba699d9d2'), url
    assert_equal 2325, entry.size
  end

  it 'raises SyncError for files missing from the listing and lists each package once' do
    server.on('/pmbs/demo?expand=1', body: ::File.read(fixture_path('sync', 'obs_directory.xml')))
    pmbs.directory(package: 'demo')

    assert_raises(::PackmanNova::SyncError) { pmbs.resolve(package: 'demo', file: 'nope.tar.gz') }
    assert_equal 1, server.requests.size
  end
end
