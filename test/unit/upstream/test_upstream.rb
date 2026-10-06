# frozen_string_literal: true

require 'test_helper'

class FakeArchiveBucket
  attr_accessor :failing
  attr_reader :uploaded

  def initialize
    @uploaded = []
  end

  def list(_prefix)
    uploaded.to_h { |key| [key, {}] }
  end

  def upload(_path, key, **)
    raise ::IOError, 'denied' if failing

    uploaded << key
  end
end

describe ::PackmanNova::Upstream, :sync do
  let(:server) { ::HttpStubServer.new }
  let(:dir) { ::Dir.mktmpdir('packman-nova-upstream-') }
  let(:config) { sync_config(dir, server) }
  let(:packages_dir) { ::File.join(dir, 'packages') }
  let(:clock) { -> { ::Time.utc(2026, 10, 5, 9, 8, 7) } }
  let(:upstream) { ::PackmanNova::Upstream.new(config:, logger: null_logger, packages_dir:, clock:) }
  let(:spec) { "Name:           hello\nVersion:        1.0\nRelease:        0\nSource0:        %{name}-%{version}.tar.gz\n" }

  after do
    server.stop
    ::FileUtils.rm_rf(dir)
  end

  def write_hello(watch: { 'url' => server.url('/releases'), 'pattern' => 'hello-(\d+(?:\.\d+)+)\.tar\.gz' })
    source = { 'file' => 'hello-1.0.tar.gz', 'urls' => [server.url('/dl/hello-1.0.tar.gz')], 'sha256' => 'a' * 64, 'size' => 1 }
    write_package(packages_dir, { 'name' => 'hello', 'kind' => 'native', 'sources' => [source], 'watch' => watch },
                  'hello.spec' => spec, 'hello.changes' => "#{'-' * 67}\nold entry\n")
  end

  def read(*parts)
    ::File.read(::File.join(packages_dir, *parts))
  end

  describe 'url watch' do
    before do
      write_hello
      write_package(packages_dir, { 'name' => 'plain', 'kind' => 'native' }, 'plain.spec' => "Version: 1\n")
      server.on('/releases', body: 'hello-1.0.tar.gz hello-1.2.tar.gz hello-1.10.tar.gz')
    end

    it 'reports newer versions and unwatched packages' do
      results = upstream.check.to_h { |result| [result.name, result] }

      assert_equal [:outdated, '1.0', '1.10'], results.fetch('hello').to_h.values_at(:state, :current, :latest)
      assert_equal [:skipped, 'no watch'], results.fetch('plain').to_h.values_at(:state, :detail)
    end

    it 'updates spec, manifest and changes, after which check is clean' do
      server.on('/dl/hello-1.10.tar.gz', body: tarball)
      result = upstream.update(packages: ['hello']).first

      assert_equal [:updated, '1.0', '1.10'], result.to_h.values_at(:state, :current, :latest)
      assert_includes read('hello', 'hello.spec'), "Version:        1.10\n"
      assert_includes read('hello', 'package.yml'),
                      "- file: hello-1.10.tar.gz\n  urls:\n  - #{server.url('/dl/hello-1.10.tar.gz')}\n  sha256: #{sha256_of(tarball)}\n  size: #{tarball.bytesize}\n"
      assert read('hello', 'hello.changes').start_with?("#{'-' * 67}\nMon Oct  5 09:08:07 UTC 2026 - #{config.packager}\n\n- Update to version 1.10\n\n#{'-' * 67}\nold entry\n")
      assert_equal :ok, upstream.check(packages: ['hello']).first.state
    end

    it 'leaves the package untouched when the download fails' do
      before = ::Dir.glob(::File.join(packages_dir, 'hello', '*')).to_h { |path| [path, ::File.read(path)] }
      result = upstream.update(packages: ['hello']).first

      assert_equal :failed, result.state
      assert_equal(before, before.keys.to_h { |path| [path, ::File.read(path)] })
    end

    it 'sets an explicit version even when it is not newer' do
      server.on('/dl/hello-0.9.tar.gz', body: tarball)

      assert_equal '0.9', upstream.update(packages: ['hello'], version: '0.9').first.latest
    end

    it 'needs exactly one package for --version' do
      assert_raises(::PackmanNova::UpstreamError) { upstream.update(version: '2.0') }
    end
  end

  describe 'git snapshot watch' do
    let(:repo) { ::GitFixture.new(::File.join(dir, 'repo')) }
    let(:spec) { "%define sover   1\nName:           snap\nVersion:        1.0\nSource0:        %{name}-%{version}.tar\nProvides:       weakremover(libsnap-0)\n" }

    before do
      repo.commit('lib.h' => "BUILD 1\n")
      repo.tag('v1.0')
      repo.commit('lib.h' => "BUILD 2\n")
      repo.tag('v1.1')
      watch = { 'git' => repo.url, 'tags' => '^v(\d+(?:\.\d+)+)$', 'file' => 'snap-%{version}.tar', 'sover' => { 'path' => 'lib.h', 'pattern' => 'BUILD (\d+)' } }
      write_package(packages_dir, { 'name' => 'snap', 'kind' => 'native', 'sources' => [{ 'file' => 'snap-1.0.tar', 'sha256' => 'a' * 64, 'size' => 1 }], 'watch' => watch },
                    'snap.spec' => spec, 'baselibs.conf' => "libsnap-1\n")
    end

    it 'generates the tarball, bumps sover and records the commit' do
      result = upstream.update(packages: ['snap']).first
      manifest = ::PackmanNova::Manifest.load_file(::File.join(packages_dir, 'snap', 'package.yml'))
      blob = config.workdir.cache_blob(sha256: manifest.sources.first.sha256)

      assert_equal [:updated, '1.1'], result.to_h.values_at(:state, :latest)
      assert_equal ['snap-1.1.tar', repo.head], [manifest.sources.first.file, manifest.watch.commit]
      assert_equal manifest.sources.first.size, ::File.size(blob)
      assert_includes read('snap', 'snap.spec'), "%define sover   2\nName:           snap\nVersion:        1.1\n"
      assert_includes read('snap', 'snap.spec'), "Provides:       weakremover(libsnap-1)\nProvides:       weakremover(libsnap-0)\n"
      assert_equal "libsnap-2\n", read('snap', 'baselibs.conf')
    end

    describe 'with a source archive bucket' do
      let(:bucket) { FakeArchiveBucket.new }
      let(:upstream) { ::PackmanNova::Upstream.new(config:, logger: null_logger, packages_dir:, bucket:, clock:) }

      it 'uploads the new snapshot, and a rerun uploads only what is missing' do
        upstream.update(packages: ['snap'])
        sha256 = ::PackmanNova::Manifest.load_file(::File.join(packages_dir, 'snap', 'package.yml')).sources.first.sha256

        assert_equal ["_sources/sha256/#{sha256}"], bucket.uploaded
        assert_equal([], upstream.update(packages: ['snap']).reject { |result| result.state == :ok })
        assert_equal 1, bucket.uploaded.size
      end

      it 'reports a failed upload' do
        bucket.failing = true
        results = upstream.update(packages: ['snap'])

        assert_equal [%i[updated], [:failed, 'upload failed: denied']], [results.first.to_h.values_at(:state), results.last.to_h.values_at(:state, :detail)]
      end
    end
  end

  it 'refuses to run offline' do
    offline = load_config(path: config.files.last, overrides: { offline: true }, env: { 'PACKMAN_NOVA_WORKDIR' => nil })

    assert_raises(::PackmanNova::UpstreamError) { ::PackmanNova::Upstream.new(config: offline, logger: null_logger, packages_dir:).check }
  end
end
