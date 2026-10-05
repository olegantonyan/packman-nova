# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Pbuild::ProjectDir do
  def project_dir(root)
    ::PackmanNova::Pbuild::ProjectDir.new(workdir: ::PackmanNova::Workdir.new(root:), reponame: 'tumbleweed', arch: 'x86_64')
  end

  it 'knows host and container paths' do
    dir = project_dir('/w')

    assert_equal '/w/project', dir.host_path
    assert_equal '/w/project/_build.tumbleweed.x86_64', dir.results_dir
    assert_equal [
      ['--mount', 'type=bind,source=/w/project,target=/project'], ['--mount', 'type=bind,source=/w/build-root,target=/build-root']
    ], dir.mounts.map(&:to_args)
  end

  it 'checks for both config files' do
    with_tmpdir do |root|
      dir = project_dir(root)
      ::FileUtils.mkdir_p(::File.join(root, 'project', '_configs'))
      ::File.write(::File.join(root, 'project', '_config'), '')

      refute_predicate dir, :configs_present?
      ::File.write(::File.join(root, 'project', '_configs', 'tumbleweed.conf'), '')

      assert_predicate dir, :configs_present?
    end
  end

  it 'lists package dirs, skipping dot and underscore entries' do
    with_tmpdir do |root|
      %w[fdk-aac vlc .fdk-aac.tmp _build.tumbleweed.x86_64 _configs .pbuild].each { |name| ::FileUtils.mkdir_p(::File.join(root, 'project', name)) }
      ::File.write(::File.join(root, 'project', 'README'), '')

      assert_equal %w[fdk-aac vlc], project_dir(root).package_names
    end
  end

  it 'returns no packages without a project dir' do
    with_tmpdir { |root| assert_empty project_dir(root).package_names }
  end
end
