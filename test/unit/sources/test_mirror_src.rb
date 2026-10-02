# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Sources::MirrorSrc do
  let(:server) { ::HttpStubServer.new }
  let(:dir) { ::Dir.mktmpdir('packman-nova-mirror-') }
  let(:workdir) { ::PackmanNova::Workdir.new(root: dir) }
  let(:extracted) { [] }
  let(:extractor) do
    calls = extracted
    ::Object.new.tap do |fake|
      fake.define_singleton_method(:extract) do |srpm:, member:, target:|
        calls << [::File.basename(srpm), member]
        ::File.write(target, "#{member} from #{::File.read(srpm)}")
      end
    end
  end

  def mirror(offline: false)
    http = ::PackmanNova::Utils::Http.new(logger: null_logger, timeout_sec: 5, retries: 0, offline: offline)
    downloader = ::PackmanNova::Sources::Downloader.new(http: http, logger: null_logger, offline: offline)
    ::PackmanNova::Sources::MirrorSrc.new(urls: [server.url('/src/')], downloader: downloader, workdir: workdir, extractor: extractor, logger: null_logger)
  end

  before do
    server.on('/src/', body: ::File.read(fixture_path('sync', 'mirror_index.html')))
    server.on('/src/ffmpeg-6-6.1.10-1699.1.pm.2.src.rpm', body: 'srpm')
  end

  after do
    server.stop
    ::FileUtils.rm_rf(dir)
  end

  it 'downloads the newest src.rpm once and extracts the member' do
    source = mirror
    2.times { |index| source.fetch(package: 'ffmpeg-6', file: 'ffmpeg-6-6.1.10.tar.xz', target: ::File.join(dir, "out#{index}")) }

    assert_equal 'ffmpeg-6-6.1.10.tar.xz from srpm', ::File.read(::File.join(dir, 'out1'))
    assert_equal [['ffmpeg-6-6.1.10-1699.1.pm.2.src.rpm', 'ffmpeg-6-6.1.10.tar.xz']] * 2, extracted
    assert_equal 2, server.requests.size
  end

  it 'raises SyncError when no src.rpm matches' do
    assert_raises(::PackmanNova::SyncError) { mirror.fetch(package: 'nope', file: 'x', target: ::File.join(dir, 'x')) }
  end

  it 'raises SyncError when offline' do
    assert_raises(::PackmanNova::SyncError) { mirror(offline: true).newest('ffmpeg-6') }
  end
end
