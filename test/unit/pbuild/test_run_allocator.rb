# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Pbuild::RunAllocator do
  def touch(path, content = '')
    ::FileUtils.mkdir_p(::File.dirname(path))
    ::File.write(path, content)
  end

  def allocator(dir)
    config = load_config(env: { 'PACKMAN_NOVA_WORKDIR' => dir, 'PACKMAN_NOVA_REPO_PATH' => nil })
    ::PackmanNova::Pbuild::RunAllocator.new(config:, environment: ::PackmanNova::Pbuild::Environment.new(config:, logger: null_logger))
  end

  it 'floors the run at the maximum of published state and built rpm releases' do
    with_tmpdir do |dir|
      results = ::File.join(dir, 'project', '_build.tumbleweed.x86_64')
      touch(::File.join(results, 'fdk-aac', 'libfdk-aac2-2.0.3-1699.3.nova.1.x86_64.rpm'))
      touch(::File.join(results, 'vlc', 'vlc-3.0-1699.5.nova.1.x86_64.rpm'))
      touch(::File.join(results, 'x265', 'x265-4.1-1.2.x86_64.rpm'))
      touch(::File.join(dir, 'repo', 'opensuse_tumbleweed', 'essentials', 'state.json'), '{"run": 7}')
      touch(::File.join(dir, 'repo-mirror', 'opensuse_tumbleweed', 'essentials', 'state.json'), '{"run": ')

      assert_equal 7, allocator(dir).floor
      ::FileUtils.rm_rf(::File.join(dir, 'repo'))

      assert_equal 5, allocator(dir).floor
    end
  end

  it 'is zero when nothing exists' do
    with_tmpdir { |dir| assert_equal 0, allocator(dir).floor }
  end
end
