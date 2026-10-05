# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Sources::ObsClient do
  let(:server) { ::HttpStubServer.new }
  let(:dir) { ::Dir.mktmpdir('packman-nova-obs-') }
  let(:workdir) { ::PackmanNova::Workdir.new(root: dir) }
  let(:xml) { ::File.read(fixture_path('sync', 'obs_directory.xml')) }

  def client(offline: false, api: server.url('/public'))
    http = ::PackmanNova::Utils::Http.new(logger: null_logger, timeout_sec: 5, retries: 0, offline:)
    downloader = ::PackmanNova::Sources::Downloader.new(http:, logger: null_logger)
    ::PackmanNova::Sources::ObsClient.new(api:, downloader:, workdir:)
  end

  after do
    server.stop
    ::FileUtils.rm_rf(dir)
  end

  it 'builds expanded directory urls with an optional rev' do
    obs = client(api: 'https://api.opensuse.org/public/')

    assert_equal 'https://api.opensuse.org/public/source/openSUSE:Factory/ffmpeg-8?expand=1', obs.directory_url(project: 'openSUSE:Factory', package: 'ffmpeg-8')
    assert_equal 'https://api.opensuse.org/public/source/multimedia:xine/xine-lib?expand=1&rev=abc',
                 obs.directory_url(project: 'multimedia:xine', package: 'xine-lib', rev: 'abc')
  end

  it 'builds file urls pinned to the srcmd5 and escapes unsafe characters' do
    url = client(api: 'https://api.opensuse.org/public').file_url(project: 'openSUSE:Factory', package: 'vlc', name: 'a b#c.patch', rev: 'f00')

    assert_equal 'https://api.opensuse.org/public/source/openSUSE:Factory/vlc/a%20b%23c.patch?rev=f00', url
  end

  it 'fetches the listing and caches it by srcmd5' do
    server.on('/public/source/openSUSE:Factory/demo?expand=1', body: xml)
    listing = client.directory(project: 'openSUSE:Factory', package: 'demo')

    assert_equal 'fac92e8502a9b282a0616cfba699d9d2', listing.srcmd5
    assert ::File.file?(::File.join(workdir.obs_cache_dir(project: 'openSUSE:Factory', package: 'demo'), "#{listing.srcmd5}.xml"))
  end

  it 'parses entries sorted by name with md5 and size' do
    server.on('/public/source/openSUSE:Factory/demo?expand=1', body: xml)
    listing = client.directory(project: 'openSUSE:Factory', package: 'demo')
    entry = listing.entry('demo-1.0.tar.gz')

    assert_equal %w[_multibuild demo-1.0.tar.gz demo.changes demo.spec], listing.entries.map(&:name)
    assert_equal ['034956cbb1e3629e7cade3d311ffd06a', 5_004_148], [entry.md5, entry.size]
    assert_nil listing.entry('nope')
  end

  it 'raises SyncError with the OBS status summary' do
    server.on('/public/source/openSUSE:Factory/nope?expand=1', body: ::File.read(fixture_path('sync', 'obs_not_found.xml')))
    error = assert_raises(::PackmanNova::SyncError) { client.directory(project: 'openSUSE:Factory', package: 'nope') }

    assert_equal 'openSUSE:Factory/nope: Package not found: openSUSE:Factory/nope', error.message
  end

  it 'serves the newest cached listing when offline' do
    server.on('/public/source/openSUSE:Factory/demo?expand=1', body: xml)
    client.directory(project: 'openSUSE:Factory', package: 'demo')
    listing = client(offline: true).directory(project: 'openSUSE:Factory', package: 'demo')

    assert_equal 'fac92e8502a9b282a0616cfba699d9d2', listing.srcmd5
    assert_equal 1, server.requests.size
  end

  it 'reuses a cached listing for a pinned rev without asking the server' do
    server.on('/public/source/openSUSE:Factory/demo?expand=1&rev=pin1', body: xml)
    2.times { client.directory(project: 'openSUSE:Factory', package: 'demo', rev: 'pin1') }

    assert_equal 1, server.requests.size
  end

  it 'raises SyncError when offline without a cached listing' do
    assert_raises(::PackmanNova::SyncError) { client(offline: true).directory(project: 'openSUSE:Factory', package: 'nope') }
  end
end
