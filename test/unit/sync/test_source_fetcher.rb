# frozen_string_literal: true

require 'test_helper'
require_relative 'sync_fixture'

describe ::PackmanNova::Sync::SourceFetcher do
  include ::SyncFixture

  let(:server) { ::HttpStubServer.new }
  let(:dir) { ::Dir.mktmpdir('packman-nova-fetcher-') }
  let(:config) { sync_config(dir, server) }
  let(:services) do
    http = ::PackmanNova::Utils::Http.new(logger: null_logger, timeout_sec: 5, retries: 0)
    downloader = ::PackmanNova::Sources::Downloader.new(http: http, logger: null_logger)
    ::PackmanNova::Sync::Services.new(config: config, logger: null_logger, workdir: config.workdir, downloader: downloader)
  end

  def source(urls, sha256: sha256_of(tarball))
    ::PackmanNova::Manifest::Source.new(file: 'hello-1.0.tar.gz', urls: urls, sha256: sha256, size: tarball.bytesize)
  end

  after do
    server.stop
    ::FileUtils.rm_rf(dir)
  end

  it 'downloads plain urls with the packman-nova User-Agent' do
    server.on('/hello-1.0.tar.gz', body: tarball)
    blob = services.fetcher.fetch(source([server.url('/hello-1.0.tar.gz')]), package: 'hello')

    assert_equal tarball, ::File.binread(blob.path)
  end

  it 'moves on to the next url after a failure or a checksum mismatch' do
    server.on('/a', status: 404).on('/b', body: 'wrong content').on('/c', body: tarball)
    blob = services.fetcher.fetch(source([server.url('/a'), server.url('/b'), server.url('/c')]), package: 'hello')

    assert_equal sha256_of(tarball), blob.sha256
  end

  it 'falls back to the source archive by sha256' do
    server.on('/gone', status: 404).on("/pub/_sources/sha256/#{sha256_of(tarball)}", body: tarball)
    blob = services.fetcher.fetch(source([server.url('/gone')]), package: 'hello')

    assert_equal tarball, ::File.binread(blob.path)
  end

  it 'fetches archive-only sources from the archive' do
    server.on("/pub/_sources/sha256/#{sha256_of(tarball)}", body: tarball)

    assert_equal sha256_of(tarball), services.fetcher.fetch(source([]), package: 'hello').sha256
  end

  it 'uses the cache without any request' do
    server.on('/hello-1.0.tar.gz', body: tarball)
    2.times { services.fetcher.fetch(source([server.url('/hello-1.0.tar.gz')]), package: 'hello') }

    assert_equal 1, server.requests.size
  end

  it 'raises SyncError naming every failed url' do
    error = assert_raises(::PackmanNova::SyncError) { services.fetcher.fetch(source([server.url('/gone')]), package: 'hello') }

    assert_match(%r{/gone: HTTP 404}, error.message)
    assert_match(%r{/pub/_sources/sha256/#{sha256_of(tarball)}: HTTP 404}, error.message)
  end
end
