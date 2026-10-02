# frozen_string_literal: true

require 'test_helper'
require_relative 'sync_fixture'

describe ::PackmanNova::Sync::SourceFetcher do
  include ::SyncFixture

  let(:server) { ::HttpStubServer.new }
  let(:dir) { ::Dir.mktmpdir('packman-nova-fetcher-') }
  let(:config) { sync_config(dir, server) }
  let(:mirror_calls) { [] }
  let(:extractor) do
    calls = mirror_calls
    content = tarball
    ::Object.new.tap do |fake|
      fake.define_singleton_method(:extract) do |srpm:, member:, target:|
        calls << [::File.basename(srpm), member]
        ::File.binwrite(target, content)
      end
    end
  end
  let(:services) do
    http = ::PackmanNova::Utils::Http.new(logger: null_logger, timeout_sec: 5, retries: 0)
    downloader = ::PackmanNova::Sources::Downloader.new(http: http, logger: null_logger)
    ::PackmanNova::Sync::Services.new(config: config, logger: null_logger, workdir: config.workdir, downloader: downloader, extractor: extractor)
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

  it 'extracts mirror-src members from the newest src.rpm' do
    server.on('/mirror/', body: '<a href="hello-1.0-1699.1.pm.2.src.rpm">x</a> <a href="hello-1.0-1699.1.pm.10.src.rpm">y</a>')
    server.on('/mirror/hello-1.0-1699.1.pm.10.src.rpm', body: 'rpm')
    services.fetcher.fetch(source(['mirror-src:hello']), package: 'hello')

    assert_equal [['hello-1.0-1699.1.pm.10.src.rpm', 'hello-1.0.tar.gz']], mirror_calls
  end

  it 'uses the cache without any request' do
    server.on('/hello-1.0.tar.gz', body: tarball)
    2.times { services.fetcher.fetch(source([server.url('/hello-1.0.tar.gz')]), package: 'hello') }

    assert_equal 1, server.requests.size
  end

  it 'raises SyncError naming every failed url' do
    server.on('/pmbs/hello?expand=1', body: obs_listing('b' * 32, 'other.tar.gz' => 'x'))
    error = assert_raises(::PackmanNova::SyncError) { services.fetcher.fetch(source([server.url('/gone'), 'pmbs:hello']), package: 'hello') }

    assert_match(%r{/gone: HTTP 404}, error.message)
    assert_match(/pmbs:hello: PMBS hello has no file hello-1.0.tar.gz/, error.message)
  end
end
