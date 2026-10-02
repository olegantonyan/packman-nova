# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Sync::PackageDir do
  let(:dir) { ::Dir.mktmpdir('packman-nova-pkgdir-') }
  let(:package_dir) { ::PackmanNova::Sync::PackageDir.new(path: ::File.join(dir, 'project', 'demo')) }
  let(:blob) { ::File.join(dir, 'blob').tap { |path| ::File.write(path, 'tarball') } }
  let(:spec) { ::File.join(dir, 'demo.spec').tap { |path| ::File.write(path, 'spec') } }
  let(:files) do
    [
      ::PackmanNova::Sync::ExpectedFile.new(name: 'demo.tar.gz', source: blob, sha256: ::PackmanNova::Utils::Digest.sha256_string('tarball'), blob: true),
      ::PackmanNova::Sync::ExpectedFile.new(name: 'demo.spec', source: spec, md5: ::PackmanNova::Utils::Digest.md5_string('spec'))
    ]
  end

  after { ::FileUtils.rm_rf(dir) }

  it 'materializes files atomically and matches them afterwards' do
    package_dir.materialize(files)

    assert_predicate package_dir, :exist?
    assert package_dir.matches?(files)
    assert_equal ['demo'], ::Dir.children(::File.join(dir, 'project'))
  end

  it 'hardlinks blobs and copies plain files' do
    package_dir.materialize(files)

    assert ::File.identical?(blob, ::File.join(package_dir.path, 'demo.tar.gz'))
    refute ::File.identical?(spec, ::File.join(package_dir.path, 'demo.spec'))
  end

  it 'detects extra, missing and modified files' do
    package_dir.materialize(files)
    ::File.write(::File.join(package_dir.path, 'demo.spec'), 'edited')

    refute package_dir.matches?(files)
    refute package_dir.matches?(files.take(1))
  end

  it 'replaces the previous contents' do
    package_dir.materialize(files)
    package_dir.materialize(files.take(1))

    assert_equal ['demo.tar.gz'], ::Dir.children(package_dir.path)
  end

  it 'raises SyncError and leaves no temp dir when a source is missing' do
    missing = ::PackmanNova::Sync::ExpectedFile.new(name: 'x', source: ::File.join(dir, 'nope'), blob: true)

    assert_raises(::PackmanNova::SyncError) { package_dir.materialize([missing]) }
    assert_empty ::Dir.children(::File.join(dir, 'project'))
  end
end
