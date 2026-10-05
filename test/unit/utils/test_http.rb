# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Utils::Http do
  let(:server) { ::HttpStubServer.new }
  let(:delays) { [] }
  let(:http) { ::PackmanNova::Utils::Http.new(logger: null_logger, timeout_sec: 5, retries: 2, sleeper: ->(seconds) { delays << seconds }) }

  after { server.stop }

  it 'returns the body of a successful GET' do
    server.on('/a', body: 'hello')

    assert_equal 'hello', http.get(server.url('/a'))
  end

  it 'follows relative redirects' do
    server.on('/old', status: 302, headers: { 'Location' => '/new' }).on('/new', body: 'moved')

    assert_equal 'moved', http.get(server.url('/old'))
  end

  it 'retries server errors with exponential backoff' do
    server.on('/flaky', status: 503).on('/flaky', status: 502).on('/flaky', body: 'ok')

    assert_equal 'ok', http.get(server.url('/flaky'))
    assert_equal [1, 2], delays
  end

  it 'gives up after the configured retries' do
    server.on('/down', status: 500)
    error = assert_raises(::PackmanNova::DownloadError) { http.get(server.url('/down')) }

    assert_match(/HTTP 500/, error.message)
    assert_equal [1, 2], delays
  end

  it 'does not retry client errors' do
    server.on('/missing', status: 404)
    assert_raises(::PackmanNova::DownloadError) { http.get(server.url('/missing')) }

    assert_empty delays
  end

  it 'streams downloads through a .part file' do
    server.on('/blob', body: 'x' * 100_000)
    with_tmpdir do |dir|
      path = http.get_to_file(server.url('/blob'), ::File.join(dir, 'cache', 'blob'))

      assert_equal 100_000, ::File.size(path)
      assert_equal ['blob'], ::Dir.children(::File.join(dir, 'cache'))
    end
  end

  it 'leaves no .part file behind on failure' do
    server.on('/gone', status: 410)
    with_tmpdir do |dir|
      assert_raises(::PackmanNova::DownloadError) { http.get_to_file(server.url('/gone'), ::File.join(dir, 'blob')) }

      assert_empty ::Dir.children(dir)
    end
  end

  it 'answers HEAD requests' do
    server.on('/h', body: 'abc')

    assert_equal '3', http.head(server.url('/h'))['content-length']
  end

  it 'refuses network access when offline' do
    offline = ::PackmanNova::Utils::Http.new(logger: null_logger, offline: true)

    assert_raises(::PackmanNova::DownloadError) { offline.get(server.url('/a')) }
    assert_equal 0, server.requests.size
  end

  it 'retries connection errors' do
    probe = ::TCPServer.new('127.0.0.1', 0)
    port = probe.addr[1]
    probe.close

    assert_raises(::PackmanNova::DownloadError) { http.get("http://127.0.0.1:#{port}/") }
    assert_equal [1, 2], delays
  end
end
