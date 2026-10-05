# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Workdir do
  let(:workdir) { ::PackmanNova::Workdir.new(root: '/w') }

  it 'builds project paths' do
    assert_equal '/w/project/_configs/tumbleweed.conf', workdir.dist_config_file('tumbleweed')
    assert_equal '/w/project/_config', workdir.config_file
    assert_equal '/w/project/_build.tumbleweed.x86_64', workdir.results_dir(reponame: 'tumbleweed', arch: 'x86_64')
  end

  it 'builds cache paths' do
    assert_equal '/w/cache/blobs/sha256/abc', workdir.cache_blob(sha256: 'abc')
    assert_equal '/w/cache/blobs/md5/def', workdir.cache_blob(md5: 'def')
    assert_equal '/w/cache/obs/openSUSE:Factory/vlc', workdir.obs_cache_dir(project: 'openSUSE:Factory', package: 'vlc')
  end

  it 'requires exactly one digest for cache blobs' do
    assert_raises(::ArgumentError) { workdir.cache_blob }
    assert_raises(::ArgumentError) { workdir.cache_blob(sha256: 'a', md5: 'b') }
  end

  it 'builds state paths' do
    assert_equal '/w/state/sync.json', workdir.state_file('sync.json')
    assert_equal '/w/state/builds/7.json', workdir.build_record_file(7)
    assert_equal '/w/state/last-build.json', workdir.last_build_file
  end

  it 'builds timestamped log file names' do
    assert_equal '/w/logs/20260929-081500-build.log', workdir.log_file('build', now: ::Time.new(2026, 9, 29, 8, 15, 0))
  end

  it 'creates the top-level directories on prepare!' do
    with_tmpdir do |dir|
      prepared = ::PackmanNova::Workdir.new(root: ::File.join(dir, 'wd')).prepare!

      assert_predicate prepared, :exist?
      assert ::File.directory?(prepared.build_root)
      assert ::File.directory?(prepared.tmp_dir)
    end
  end

  it 'yields a private temporary directory under tmp/ and removes it afterwards' do
    with_tmpdir do |dir|
      path = ::PackmanNova::Workdir.new(root: dir).mktmpdir('gpg-') do |tmp|
        assert tmp.start_with?(::File.join(dir, 'tmp', 'gpg-'))
        assert_equal 0o700, ::File.stat(tmp).mode & 0o777
        tmp
      end

      refute_path_exists path
    end
  end

  it 'runs the block under the lock' do
    with_tmpdir do |dir|
      assert_equal(:done, ::PackmanNova::Workdir.new(root: dir).with_lock { :done })
    end
  end

  it 'raises LockError when another handle holds the lock' do
    with_tmpdir do |dir|
      locked = ::PackmanNova::Workdir.new(root: dir)
      ::File.open(locked.lock_file, ::File::RDWR | ::File::CREAT) do |other|
        other.flock(::File::LOCK_EX)

        assert_raises(::PackmanNova::LockError) { locked.with_lock { flunk 'must not run' } }
      end
    end
  end

  it 'reports free bytes for a directory that does not exist yet' do
    with_tmpdir do |dir|
      assert_operator ::PackmanNova::Workdir.new(root: ::File.join(dir, 'missing', 'deeper')).free_bytes, :>, 0
    end
  end
end
