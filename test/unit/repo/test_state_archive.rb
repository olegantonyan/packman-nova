# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Repo::StateArchive do
  let(:store) { {} }
  let(:provider) do
    objects = store
    ::Object.new.tap do |fake|
      fake.define_singleton_method(:upload) { |path, key, content_type:| objects[key] = [::File.binread(path), content_type] }
      fake.define_singleton_method(:download) { |key, path| ::File.binwrite(path, objects.fetch(key).first) && path }
      fake.define_singleton_method(:exist?) { |key| objects.key?(key) }
    end
  end

  def archive(dir, subprocess: ::PackmanNova::Utils::Subprocess.new(logger: null_logger))
    config = load_config(env: { 'PACKMAN_NOVA_WORKDIR' => dir })
    ::PackmanNova::Repo::StateArchive.new(config: config, workdir: config.workdir, provider: provider, subprocess: subprocess, logger: null_logger)
  end

  it 'archives the results dir with the pbuild cache and state, then restores them' do
    with_tmpdir do |dir|
      base = ::File.join(dir, 'project', '_build.tumbleweed.x86_64', '.pbuild', '_base', 'repo1')
      ::FileUtils.mkdir_p(base)
      ::File.write(::File.join(base, 'a.rpm'), 'cached')
      ::FileUtils.mkdir_p(::File.join(dir, 'state'))
      ::File.write(::File.join(dir, 'state', 'last-build.json'), '{}')

      assert_equal ['project/_build.tumbleweed.x86_64', 'state'], archive(dir).push
      assert_equal 'application/zstd', store.fetch('_state/state.tar.zst').last

      ::FileUtils.rm_rf(::File.join(dir, 'project'))
      ::FileUtils.rm_rf(::File.join(dir, 'state'))
      archive(dir).pull

      assert_equal 'cached', ::File.read(::File.join(base, 'a.rpm'))
      assert_equal '{}', ::File.read(::File.join(dir, 'state', 'last-build.json'))
    end
  end

  it 'runs tar with zstd against the workdir' do
    with_tmpdir do |dir|
      ::FileUtils.mkdir_p(::File.join(dir, 'state'))
      argvs = []
      subprocess = ::Object.new
      subprocess.define_singleton_method(:execute) do |argv|
        argvs << argv
        ::File.write(argv[3], 'archive') if argv[2] == '-cf'
        ::Data.define(:ok) { def success? = ok }.new(ok: true)
      end
      archive(dir, subprocess: subprocess).push

      assert_equal ['tar', '--zstd', '-cf'], argvs.first.first(3)
      assert_equal ['-C', dir, 'state'], argvs.first.last(3)
    end
  end

  it 'refuses empty pushes and missing archives' do
    with_tmpdir do |dir|
      assert_raises(::PackmanNova::PublishError) { archive(dir).push }
      assert_raises(::PackmanNova::PublishError) { archive(dir).pull }
    end
  end

  it 'tolerates a missing archive on request' do
    with_tmpdir do |dir|
      assert_nil archive(dir).pull(allow_missing: true)
    end
  end
end
