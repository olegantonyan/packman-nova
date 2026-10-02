# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Pbuild::RunFloor do
  def touch(path, content = '')
    ::FileUtils.mkdir_p(::File.dirname(path))
    ::File.write(path, content)
  end

  it 'takes the maximum of published state and built rpm releases' do
    with_tmpdir do |dir|
      results = ::File.join(dir, 'results')
      touch(::File.join(results, 'fdk-aac', 'libfdk-aac2-2.0.3-1699.3.nova.1.x86_64.rpm'))
      touch(::File.join(results, 'vlc', 'vlc-3.0-1699.5.nova.1.x86_64.rpm'))
      touch(::File.join(results, 'x265', 'x265-4.1-1.2.x86_64.rpm'))
      touch(::File.join(dir, 'a', 'state.json'), '{"run": 4}')
      touch(::File.join(dir, 'b', 'state.json'), '{"run": ')
      floor = ::PackmanNova::Pbuild::RunFloor.new(repo_state_files: [::File.join(dir, 'a', 'state.json'), ::File.join(dir, 'b', 'state.json')], results_dir: results)

      assert_equal 4, floor.published_run
      assert_equal 5, floor.built_run
      assert_equal 5, floor.call
    end
  end

  it 'is zero when nothing exists' do
    with_tmpdir do |dir|
      assert_equal 0, ::PackmanNova::Pbuild::RunFloor.new(repo_state_files: [::File.join(dir, 'state.json')], results_dir: ::File.join(dir, 'r')).call
    end
  end
end
