# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Sync, :sync do
  let(:server) { ::HttpStubServer.new }
  let(:dir) { ::Dir.mktmpdir('packman-nova-sync-') }
  let(:config) { sync_config(dir, server) }
  let(:packages_dir) { ::File.join(dir, 'packages') }
  let(:workdir) { config.workdir }
  let(:link_files) { { 'demo.spec' => "Name: demo\n", '_multibuild' => "<multibuild/>\n", 'demo-1.0.tar.gz' => tarball } }
  let(:sync) { ::PackmanNova::Sync.new(config:, logger: null_logger, packages_dir:) }

  before do
    stub_common(server)
    stub_obs_package(server, project: 'openSUSE:Factory', package: 'demo', srcmd5: 'a' * 32, files: link_files)
    server.on('/upstream/hello-1.0.tar.gz', status: 404)
    server.on("/pub/_sources/sha256/#{sha256_of(tarball)}", body: tarball)
    write_package(packages_dir, { 'name' => 'demo', 'kind' => 'obs-link', 'link' => { 'delete' => ['_multibuild', 'missing.changes'] } })
    write_package(packages_dir, hello_manifest, 'hello.spec' => "Name: hello\n", 'hello.changes' => "- init\n")
    write_package(packages_dir, { 'name' => 'old', 'kind' => 'native', 'enabled' => false }, 'old.spec' => "Name: old\n")
    %w[old ghost _configs .old.tmp].each { |name| ::FileUtils.mkdir_p(::File.join(workdir.project_dir, name)) }
  end

  after do
    server.stop
    ::FileUtils.rm_rf(dir)
  end

  def hello_manifest(sha256: sha256_of(tarball), url: server.url('/upstream/hello-1.0.tar.gz'))
    source = { 'file' => 'hello-1.0.tar.gz', 'urls' => [url], 'sha256' => sha256, 'size' => tarball.bytesize }
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

  describe 'link patches' do
    let(:spec) { "Name: demo\nSource0: demo-1.0.tar.gz\nPatch1: a.patch\nPatch7: b.patch\n\n%prep\n%autosetup -p1\n%if 0\nPatch9: mini.patch\n%endif\n" }
    let(:link_files) { { 'demo.spec' => spec, 'demo-1.0.tar.gz' => tarball } }

    def write_demo(patches, files = { 'fix.patch' => "--- a/x\n", 'more.patch' => "--- a/y\n" })
      write_package(packages_dir, { 'name' => 'demo', 'kind' => 'obs-link', 'link' => { 'patches' => patches } }, files)
    end

    it 'adds the patch files and declares them before %prep, numbered after the last patch' do
      write_demo(%w[fix.patch more.patch])
      sync.call
      patched = ::File.read(::File.join(workdir.package_dir('demo'), 'demo.spec'))

      assert_equal %w[demo-1.0.tar.gz demo.spec fix.patch more.patch], children('demo')
      assert_includes patched, "Patch7: b.patch\nPatch10:        fix.patch\nPatch11:        more.patch\n\n%prep\n"
      assert_equal "--- a/x\n", ::File.read(::File.join(workdir.package_dir('demo'), 'fix.patch'))
    end

    it 'resyncs when a patch changes and is a no-op otherwise' do
      write_demo(%w[fix.patch])
      sync.call

      assert_empty sync.call.changed
      ::File.write(::File.join(packages_dir, 'demo', 'fix.patch'), "--- a/z\n")

      assert_equal ['demo'], sync.call.changed.map(&:name)
      assert_equal "--- a/z\n", ::File.read(::File.join(workdir.package_dir('demo'), 'fix.patch'))
    end

    describe 'without %autosetup' do
      let(:spec) { "Name: demo\nSource0: demo-1.0.tar.gz\n%prep\n%setup\n" }

      it 'fails the package' do
        write_demo(%w[fix.patch])

        assert_match(/demo: link.patches: demo.spec does not apply patches/, sync.call.failed.fetch('demo'))
      end
    end

    it 'rejects a patch missing from the package dir' do
      write_demo(%w[gone.patch], {})

      assert_raises(::PackmanNova::ManifestError) { sync.call }
    end
  end

  it 'materializes native packages from vendored files, falling back to the source archive' do
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
    state = ::PackmanNova::Sync::State.new(workdir:).load

    assert_equal "Prefer: foo\n", ::File.read(workdir.config_file)
    assert_equal ::SyncSpec::FACTORY_PRJCONF, ::File.read(workdir.dist_config_file('tumbleweed'))
    assert_equal ['20260924', 'a' * 32, %w[demo hello]], [state['distro_snapshot'], state.dig('packages', 'demo', 'srcmd5'), state['packages'].keys]
  end

  it 'keeps the previous snapshot when the snapshot URL fails' do
    sync.call
    server.on('/media', status: 404)
    sync.call

    assert_equal '20260924', ::PackmanNova::Sync::State.new(workdir:).snapshot
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

  def sync_keyring(private_key)
    gpg = ::Object.new
    gpg.define_singleton_method(:public_key_from_private) { |encoded| "public of #{encoded}\n" }
    keyed = with_env('GPG_PRIVATE_KEY_BASE64' => private_key) { sync_config(dir, server) }
    services = ::PackmanNova::Sync::Services.from_config(config: keyed, logger: null_logger, workdir: keyed.workdir, gpg:)
    write_package(packages_dir, { 'name' => 'keyring', 'kind' => 'native', 'sources' => [{ 'file' => 'k.key', 'generated' => 'public-key' }] },
                  'keyring.spec' => "Name: keyring\n")
    ::PackmanNova::Sync.new(config: keyed, logger: null_logger, packages_dir:, services:).call(packages: ['keyring'])
  end

  it 'derives generated public key sources from the private key' do
    sync_keyring('cHJpdmF0ZQ==')

    assert_equal "public of cHJpdmF0ZQ==\n", ::File.read(::File.join(workdir.package_dir('keyring'), 'k.key'))
  end

  it 'fails a generated public key source without a private key' do
    assert_match(/GPG_PRIVATE_KEY_BASE64 is empty/, sync_keyring(nil).failed.fetch('keyring'))
  end

  it 'flags rebuild_all_required when the local config changes' do
    sync.call
    ::File.write(config.prjconf.local, "Prefer: bar\n")
    report = sync.call

    assert report.rebuild_all_required
    assert ::PackmanNova::Sync::State.new(workdir:).load['rebuild_all_required']
  end

  it 'limits the run to the named packages' do
    report = sync.call(packages: ['hello'])

    assert_equal ['hello'], report.outcomes.map(&:name)
    assert_empty report.removed
  end

  it 'fills missing checksums with --update-checksums' do
    server.on('/new/hello-1.0.tar.gz', body: tarball)
    write_package(packages_dir, hello_manifest(sha256: nil, url: server.url('/new/hello-1.0.tar.gz')))
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
