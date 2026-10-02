# frozen_string_literal: true

require 'test_helper'
require_relative 'sync_fixture'

describe ::PackmanNova::Sync do
  include ::SyncFixture

  let(:server) { ::HttpStubServer.new }
  let(:dir) { ::Dir.mktmpdir('packman-nova-sync-') }
  let(:config) { sync_config(dir, server) }
  let(:packages_dir) { ::File.join(dir, 'packages') }
  let(:workdir) { config.workdir }
  let(:link_files) { { 'demo.spec' => "Name: demo\n", '_multibuild' => "<multibuild/>\n", 'demo-1.0.tar.gz' => tarball } }
  let(:sync) { ::PackmanNova::Sync.new(config: config, logger: null_logger, packages_dir: packages_dir) }

  before do
    stub_common(server)
    stub_obs_package(server, project: 'openSUSE:Factory', package: 'demo', srcmd5: 'a' * 32, files: link_files)
    server.on('/upstream/hello-1.0.tar.gz', status: 404)
    server.on('/pmbs/hello?expand=1', body: obs_listing('b' * 32, 'hello-1.0.tar.gz' => tarball))
    server.on("/pmbs/hello/hello-1.0.tar.gz?rev=#{'b' * 32}", body: tarball)
    write_package(packages_dir, { 'name' => 'demo', 'kind' => 'obs-link', 'link' => { 'delete' => ['_multibuild', 'missing.changes'] } })
    write_package(packages_dir, hello_manifest, 'hello.spec' => "Name: hello\n", 'hello.changes' => "- init\n")
    write_package(packages_dir, { 'name' => 'old', 'kind' => 'native', 'enabled' => false }, 'old.spec' => "Name: old\n")
    %w[old ghost _configs .old.tmp].each { |name| ::FileUtils.mkdir_p(::File.join(workdir.project_dir, name)) }
  end

  after do
    server.stop
    ::FileUtils.rm_rf(dir)
  end

  def hello_manifest(sha256: sha256_of(tarball))
    source = { 'file' => 'hello-1.0.tar.gz', 'urls' => [server.url('/upstream/hello-1.0.tar.gz'), 'pmbs:hello'], 'sha256' => sha256, 'size' => tarball.bytesize }
    { 'name' => 'hello', 'kind' => 'native', 'sources' => [source.compact] }
  end

  def children(name)
    ::Dir.children(::File.join(workdir.project_dir, name)).sort
  end

  it 'materializes obs-link packages without the deleted files' do
    report = sync.call

    assert_equal %w[demo-1.0.tar.gz demo.spec], children('demo')
    assert_equal tarball, ::File.binread(::File.join(workdir.package_dir('demo'), 'demo-1.0.tar.gz'))
    assert_equal %w[demo hello], report.changed.map(&:name).sort
  end

  it 'materializes native packages from vendored files and the first working url' do
    sync.call

    assert_equal %w[hello-1.0.tar.gz hello.changes hello.spec], children('hello')
    assert ::File.identical?(::File.join(workdir.package_dir('hello'), 'hello-1.0.tar.gz'), workdir.cache_blob(sha256: sha256_of(tarball)))
  end

  it 'removes disabled and unknown package dirs but keeps _ and . entries' do
    report = sync.call

    assert_equal %w[.old.tmp _config _configs demo hello], ::Dir.children(workdir.project_dir).sort
    assert_equal %w[ghost old], report.removed.sort
  end

  it 'writes the project config files and the sync state' do
    sync.call
    state = ::PackmanNova::Sync::State.new(workdir: workdir).load

    assert_equal "Prefer: foo\n", ::File.read(workdir.config_file)
    assert_equal ::SyncFixture::FACTORY_PRJCONF, ::File.read(::File.join(workdir.configs_dir, 'tumbleweed.conf'))
    assert_equal ['20260924', 'a' * 32, %w[demo hello]], [state['tumbleweed_snapshot'], state.dig('packages', 'demo', 'srcmd5'), state['packages'].keys]
  end

  it 'reports no drift when nothing changed' do
    sync.call
    report = sync.call(check_only: true)

    refute_predicate report, :drift?
    assert_equal %w[demo hello], report.unchanged.map(&:name)
  end

  it 'reports drift in check mode without touching the project dir' do
    sync.call
    ::File.write(::File.join(packages_dir, 'hello', 'hello.changes'), "- changed\n")
    report = sync.call(check_only: true)

    assert_predicate report, :drift?
    assert_equal ['hello'], report.changed.map(&:name)
    assert_equal "- init\n", ::File.read(::File.join(workdir.package_dir('hello'), 'hello.changes'))
  end

  it 'keeps going when a package fails' do
    write_package(packages_dir, { 'name' => 'keyring', 'kind' => 'native', 'sources' => [{ 'file' => 'k.key', 'path' => ::File.join(dir, 'nope.key') }] },
                  'keyring.spec' => "Name: keyring\n")
    report = sync.call

    assert_equal ['keyring'], report.failed.keys
    assert_match(/k\.key not found/, report.failed.fetch('keyring'))
    assert_equal %w[demo hello], report.changed.map(&:name).sort
  end

  it 'flags rebuild_all_required when the local config changes' do
    sync.call
    ::File.write(config.prjconf.local, "Prefer: bar\n")
    report = sync.call

    assert report.rebuild_all_required
    assert ::PackmanNova::Sync::State.new(workdir: workdir).load['rebuild_all_required']
  end

  it 'limits the run to the named packages' do
    report = sync.call(packages: ['hello'])

    assert_equal ['hello'], report.outcomes.map(&:name)
    assert_empty report.removed
  end

  it 'fills missing checksums with --update-checksums' do
    write_package(packages_dir, hello_manifest(sha256: nil))
    sync.call(update_checksums: true, packages: ['hello'])
    manifest = ::PackmanNova::Manifest.load_file(::File.join(packages_dir, 'hello', 'package.yml'))

    assert_equal sha256_of(tarball), manifest.sources.first.sha256
    assert_equal tarball.bytesize, manifest.sources.first.size
  end

  it 'refuses to run while another process holds the lock' do
    workdir.with_lock do
      assert_raises(::PackmanNova::LockError) { sync.call }
    end
  end
end
