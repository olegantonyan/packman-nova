# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Sources::SnapshotRevisions do
  let(:server) { ::HttpStubServer.new }
  let(:dir) { ::Dir.mktmpdir('packman-nova-snapshot-') }
  let(:srcmd5) { 'b0f6b7724151a2852b04eea36cd5e39b' }
  let(:src_rpm) { ::SrcRpmFixture.src_rpm("obs://build.opensuse.org/openSUSE:Factory/standard/#{srcmd5}-ffmpeg-8") }
  let(:rpm_location) { 'src/ffmpeg-8-8.1.3-3.2.src.rpm' }

  def revisions
    http = ::PackmanNova::Utils::Http.new(logger: null_logger, timeout_sec: 5, retries: 0)
    downloader = ::PackmanNova::Sources::Downloader.new(http:, logger: null_logger)
    ::PackmanNova::Sources::SnapshotRevisions.new(
      repo: server.url('/src-oss/'), project: 'openSUSE:Factory', downloader:,
      subprocess: ::PackmanNova::Utils::Subprocess.new(logger: null_logger), workdir: ::PackmanNova::Workdir.new(root: dir)
    )
  end

  def stub_snapshot(packages, body: src_rpm.first, ranges: true)
    primary = ::SrcRpmFixture.primary(packages)
    server.on('/src-oss/repodata/repomd.xml', body: ::SrcRpmFixture.repomd('repodata/abc-primary.xml.gz'))
    server.on('/src-oss/repodata/abc-primary.xml.gz', body: ::SrcRpmFixture.gzip(primary))
    server.on("/src-oss/#{rpm_location}", body:, ranges:)
  end

  after do
    server.stop
    ::FileUtils.rm_rf(dir)
  end

  it 'covers only its project' do
    assert revisions.covers?('openSUSE:Factory')
    refute revisions.covers?('multimedia:libs')
  end

  it 'resolves the Factory srcmd5 from the src.rpm DISTURL, fetching the metadata once' do
    stub_snapshot({ 'ffmpeg-8' => [rpm_location, src_rpm.last], 'vlc' => [rpm_location, src_rpm.last] })
    subject = revisions

    assert_equal srcmd5, subject.srcmd5('ffmpeg-8')
    assert_raises(::PackmanNova::SyncError) { subject.srcmd5('vlc') }
    paths = ::Array.new(server.requests.size) { server.requests.pop.last }

    assert_equal(1, paths.count { |path| path.end_with?('repomd.xml') })
  end

  it 'slices the header when the server ignores the range' do
    stub_snapshot({ 'ffmpeg-8' => [rpm_location, src_rpm.last] }, ranges: false)

    assert_equal srcmd5, revisions.srcmd5('ffmpeg-8')
  end

  it 'rejects a package missing from the snapshot' do
    stub_snapshot({ 'vlc' => [rpm_location, src_rpm.last] })
    error = assert_raises(::PackmanNova::SyncError) { revisions.srcmd5('ffmpeg-8') }

    assert_match(/ffmpeg-8: no src\.rpm/, error.message)
  end

  it 'rejects a DISTURL from another project' do
    other = ::SrcRpmFixture.src_rpm("obs://build.opensuse.org/home:someone/standard/#{srcmd5}-ffmpeg-8")
    stub_snapshot({ 'ffmpeg-8' => [rpm_location, other.last] }, body: other.first)
    error = assert_raises(::PackmanNova::SyncError) { revisions.srcmd5('ffmpeg-8') }

    assert_match(%r{is not openSUSE:Factory/ffmpeg-8}, error.message)
  end
end
