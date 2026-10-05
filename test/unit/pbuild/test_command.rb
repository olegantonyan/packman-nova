# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Pbuild::Command do
  let(:defaults) do
    {
      reponame: 'tumbleweed', arch: 'x86_64', repos: ['https://download.opensuse.org/tumbleweed/repo/oss/'],
      buildjobs: 2, jobs: 8, release: '1699.4.nova.1'
    }
  end
  let(:prefix) do
    %w[
      pbuild --dist /project/_configs/tumbleweed.conf --reponame tumbleweed --arch x86_64
      --repo https://download.opensuse.org/tumbleweed/repo/oss/ --root /build-root --buildjobs 2 --jobs 8 --release 1699.4.nova.1
    ]
  end

  def command(**overrides)
    ::PackmanNova::Pbuild::Command.new(**defaults, **overrides)
  end

  it 'builds the default argv' do
    assert_equal [*prefix, '/project'], command.argv
  end

  it 'adds --rebuild-pkg per package' do
    assert_equal [*prefix, '--rebuild-pkg', 'fdk-aac', '--rebuild-pkg', 'x265', '/project'], command(rebuild_packages: %w[fdk-aac x265]).argv
  end

  it 'adds --rebuild all' do
    assert_equal [*prefix, '--rebuild', 'all', '/project'], command(rebuild: true).argv
    assert_predicate command(rebuild: true), :rebuild?
  end

  it 'adds --single' do
    assert_equal [*prefix, '--single', 'fdk-aac', '/project'], command(single: 'fdk-aac').argv
  end

  it 'adds flags and extra args in a fixed order' do
    argv = command(checks: false, debuginfo: true, baselibs: true, repo_refresh: false, rebuild_packages: ['vlc'], extra_args: %w[--debugflags expansion]).argv

    assert_equal [*prefix, '--no-checks', '--debuginfo', '--baselibs', '--no-repo-refresh', '--rebuild-pkg', 'vlc', '--debugflags', 'expansion', '/project'], argv
  end

  it 'passes every distro repo in order' do
    argv = command(repos: %w[https://a/ https://b/]).argv

    assert_equal %w[--repo https://a/ --repo https://b/], argv[7, 4]
  end

  it 'rejects conflicting selections' do
    assert_raises(::PackmanNova::Error) { command(rebuild: true, single: 'x') }
    assert_raises(::PackmanNova::Error) { command(rebuild_packages: ['a'], single: 'x') }
  end

  it 'builds the result query argv' do
    assert_equal %w[pbuild --reponame tumbleweed --arch x86_64 --result-code all /project], command.result_argv
  end
end
