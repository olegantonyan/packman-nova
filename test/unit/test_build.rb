# frozen_string_literal: true

require 'test_helper'
require 'support/build_fakes'

describe ::PackmanNova::Build do
  let(:root) { ::Dir.mktmpdir('packman-nova-build-test-') }
  let(:config) { load_config(env: { 'PACKMAN_NOVA_WORKDIR' => root, 'PACKMAN_NOVA_REPO_PATH' => nil }) }
  let(:project) { ::File.join(root, 'project') }
  let(:results) { ::File.join(project, '_build.tumbleweed.x86_64') }
  let(:out) { ::StringIO.new }
  let(:started) { ::Time.at(::Time.now.to_i - 60).utc }
  let(:sync_calls) { [] }
  let(:sync) { -> { (sync_calls << :sync) && ::PackmanNova::Sync::Report.new } }

  after { ::FileUtils.rm_rf(root) }

  def materialize(*packages)
    ::FileUtils.mkdir_p(::File.join(project, '_configs'))
    ::File.write(::File.join(project, '_config'), "Macros:\n:Macros\n")
    ::File.write(::File.join(project, '_configs', 'tumbleweed.conf'), "Preinstall: rpm\n")
    packages.each { |name| ::FileUtils.mkdir_p(::File.join(project, name)) }
  end

  def write_result(name, release:, success: true, dir: ::File.join(results, name), rpms: nil)
    ::FileUtils.mkdir_p(dir)
    ::File.write(::File.join(dir, '_meta'), "srcmd5  #{name}\n")
    ::FileUtils.cp(::File.join(dir, '_meta'), ::File.join(dir, success ? '_meta.success' : '_meta.fail'))
    ::File.write(::File.join(dir, '_log'), 'log')
    return unless success

    (rpms || %W[lib#{name}2-1.0-#{release}.x86_64.rpm #{name}-1.0-#{release}.src.rpm lib#{name}2-debuginfo-1.0-#{release}.x86_64.rpm]).each do |file|
      ::File.write(::File.join(dir, file), '')
    end
  end

  def write_baselibs(name, release:, success: true)
    rpms = %W[lib#{name}2-1.0-#{release}.i586.rpm lib#{name}2-32bit-1.0-#{release}.x86_64.rpm #{name}-1.0-#{release}.src.rpm]
    write_result(name, release:, success:, dir: ::File.join(project, '_build.tumbleweed.i586', name), rpms:)
  end

  def arch_of(argv)
    argv[argv.index('--arch') + 1]
  end

  def subprocess(status: 0, result_text: "succeeded: 1\n    fdk-aac\n", &)
    ::BuildFakes::Subprocess.new(status:, result_text:, &)
  end

  def build(subprocess, at: started, logger: null_logger)
    environment = ::PackmanNova::Pbuild::Environment.new(
      config:, logger: null_logger, subprocess:, runtime: ::PackmanNova::Container::Runtime.new(executable: 'podman'),
      image: ::BuildFakes::Image.new(config.container.image)
    )
    ::PackmanNova::Build.new(config:, logger:, out:, environment:, sync:, clock: -> { at })
  end

  def pbuild_argv(subprocess)
    argv = subprocess.executed.first
    argv[argv.index('pbuild')..]
  end

  def state(name)
    ::JSON.parse(::File.read(::File.join(root, 'state', name)))
  end

  it 'refuses to build without the pbuild config files' do
    error = assert_raises(::PackmanNova::BuildError) { build(subprocess).call(sync: false) }

    assert_match(/run sync first/, error.message)
  end

  it 'runs pbuild in the container and records the result' do
    materialize('fdk-aac')
    fake = subprocess { write_result('fdk-aac', release: '1699.1.nova.1') }

    assert_equal 0, build(fake).call

    assert_equal [:sync], sync_calls
    assert_equal %w[podman run --rm --privileged --name], fake.executed.first.first(5)
    assert_includes fake.executed.first.join(' '), "source=#{root}/build-root,target=/build-root -e LANG=C.UTF-8 -e HOME=/root localhost/packman-nova-builder:latest pbuild"
    assert_equal %w[--release 1699.1.nova.1 /project], pbuild_argv(fake).last(3)
    assert_equal %w[pbuild --reponame tumbleweed --arch x86_64 --result-code all /project], fake.captured.first.last(8)

    record = state('last-build.json')

    assert_equal record, state('builds/1.json')
    assert_equal [1, '1699.1.nova.1', 'sha256:feed', { 'succeeded' => 1 }], record.values_at('run', 'release', 'image_id', 'codes')
    assert_equal started.iso8601, record['started_at']
    entry = record.dig('packages', 'fdk-aac')

    assert_equal ['libfdk-aac2-1.0-1699.1.nova.1.x86_64.rpm'], entry['rpms']
    assert_equal 'fdk-aac-1.0-1699.1.nova.1.src.rpm', entry['srpm']
    assert_equal ['libfdk-aac2-debuginfo-1.0-1699.1.nova.1.x86_64.rpm'], entry['debuginfo_rpms']
    assert_equal 'project/_build.tumbleweed.x86_64/fdk-aac/_log', entry['log']
    assert_equal 1, state('run-counter.json')['run']
    assert_equal ['fdk-aac'], record['built']
    assert_match(/^fdk-aac +succeeded +1/, out.string)
  end

  it 'runs an i586 baselibs pass and records its -32bit rpms' do
    materialize('fdk-aac')
    fake = subprocess do |argv|
      argv.include?('--baselibs') ? write_baselibs('fdk-aac', release: '1699.1.nova.1') : write_result('fdk-aac', release: '1699.1.nova.1')
    end

    assert_equal 0, build(fake).call(sync: false)

    main, baselibs = fake.executed.map { |argv| argv[argv.index('pbuild')..] }

    assert_equal %w[x86_64 i586], [arch_of(main), arch_of(baselibs)]
    assert_includes baselibs.each_cons(2).to_a, ['--repo', 'https://download.opensuse.org/ports/i586/tumbleweed/repo/oss/']
    refute_includes baselibs.each_cons(2).to_a, ['--repo', 'https://download.opensuse.org/tumbleweed/repo/oss/']
    assert_includes baselibs, '--baselibs'
    refute_includes main, '--baselibs'
    assert_equal(%w[x86_64 i586 x86_64 i586], fake.captured.map { |argv| arch_of(argv) })
    record = state('last-build.json')
    expected = { 'arch' => 'i586', 'code' => 'succeeded', 'rpms' => ['libfdk-aac2-32bit-1.0-1699.1.nova.1.x86_64.rpm'], 'details' => nil }

    assert_equal expected, record.dig('packages', 'fdk-aac', 'baselibs')
    assert_equal 'x86_64', record['arch']
    assert_match(/^fdk-aac +succeeded +2/, out.string)
  end

  it 'drops binaries that keep their own package unresolvable and retries the pass once' do
    materialize('ffmpeg-8', 'vlc')
    write_result('ffmpeg-8', release: '1699.0.nova.1', rpms: %w[libavcodec62-8.1-1699.0.nova.1.x86_64.rpm libavcodec62-32bit-8.1-1699.0.nova.1.x86_64.rpm])
    write_result('vlc', release: '1699.0.nova.1', rpms: %w[vlc-3.0-1699.0.nova.1.x86_64.rpm])
    blocked = "unresolvable: 2\n    ffmpeg-8 (nothing provides libavcodec.so.62(LIBAVCODEC_62) needed by pipewire-spa-plugins-0_2)\n    " \
              "vlc (nothing provides libavcodec.so.62(LIBAVCODEC_62) needed by pipewire-spa-plugins-0_2)\n"
    runs = []
    fake = subprocess(result_text: ->(argv) { arch_of(argv) == 'x86_64' && runs.count('x86_64') < 2 ? blocked : "succeeded: 2\n    ffmpeg-8\n    vlc\n" }) do |argv|
      runs << arch_of(argv[argv.index('pbuild')..])
      write_result('ffmpeg-8', release: '1699.1.nova.1') if runs.count('x86_64') == 2 && runs.last == 'x86_64'
    end
    build(fake).call(sync: false)

    assert_equal %w[x86_64 x86_64 i586], runs
    refute_path_exists ::File.join(results, 'ffmpeg-8', 'libavcodec62-8.1-1699.0.nova.1.x86_64.rpm')
    assert_path_exists ::File.join(results, 'ffmpeg-8', 'libffmpeg-82-1.0-1699.1.nova.1.x86_64.rpm')
    assert_path_exists ::File.join(results, 'vlc', 'vlc-3.0-1699.0.nova.1.x86_64.rpm')
  end

  it 'fails a package whose baselibs build failed and skips excluded ones' do
    materialize('fdk-aac', 'vlc')
    codes = ->(argv) { arch_of(argv) == 'i586' ? "failed: 1\n    fdk-aac\nexcluded: 1\n    vlc\n" : "succeeded: 2\n    fdk-aac\n    vlc\n" }
    fake = subprocess(status: 1, result_text: codes) do |argv|
      next write_baselibs('fdk-aac', release: '1699.1.nova.1', success: false) if argv.include?('--baselibs')

      write_result('fdk-aac', release: '1699.1.nova.1')
      write_result('vlc', release: '1699.1.nova.1')
    end

    logger, io = string_logger

    assert_equal 1, build(fake, logger:).call(sync: false)

    record = state('last-build.json')

    assert_equal ['failed', 'i586: failed'], record.dig('packages', 'fdk-aac').values_at('code', 'details')
    assert_match(%r{\[E\] fdk-aac: failed: i586: failed\n.*\[E\] fdk-aac: last 1 lines of .*/_build\.tumbleweed\.i586/fdk-aac/_log\nlog}, io.string)
    assert_equal({ 'failed' => 1, 'succeeded' => 1 }, record['codes'])
    refute record.dig('packages', 'vlc').key?('baselibs')
  end

  describe 'without baselibs' do
    let(:config) { load_config(env: { 'PACKMAN_NOVA_WORKDIR' => root, 'PACKMAN_NOVA_REPO_PATH' => nil }, overrides: { distro: { baselibs: { arch: '' } } }) }

    it 'runs a single pbuild pass' do
      materialize('fdk-aac')
      fake = subprocess { write_result('fdk-aac', release: '1699.1.nova.1') }

      assert_equal 0, build(fake).call(sync: false)
      assert_equal 1, fake.executed.size
      refute state('last-build.json').dig('packages', 'fdk-aac').key?('baselibs')
    end
  end

  it 'returns 1 when a package failed and logs why with the tail of its build log' do
    materialize('fdk-aac', 'vlc', 'x264')
    main_codes = "succeeded: 1\n    fdk-aac\nfailed: 1\n    vlc\nunresolvable: 1\n    x264 (nothing provides nasm)\n"
    result_text = ->(argv) { arch_of(argv) == 'x86_64' ? main_codes : '' }
    fake = subprocess(status: 1, result_text:) do
      write_result('fdk-aac', release: '1699.1.nova.1')
      write_result('vlc', release: '1699.1.nova.1', success: false)
      ::File.write(::File.join(results, 'vlc', '_log'), (1..150).map { |n| "line #{n}\n" }.join)
    end
    logger, io = string_logger

    assert_equal 1, build(fake, logger:).call(sync: false)
    assert_equal({ 'failed' => 1, 'succeeded' => 1, 'unresolvable' => 1 }, state('last-build.json')['codes'])
    assert_empty sync_calls
    assert_match(%r{\[E\] vlc: failed\n.*\[E\] vlc: last 100 lines of .*/vlc/_log\nline 51\n(line \d+\n){98}line 150\n}, io.string)
    assert_match(/\[E\] x264: unresolvable: nothing provides nasm\n.*\[E\] x264: no build log\n/, io.string)
  end

  it 'raises when pbuild fails without a failed package' do
    materialize('fdk-aac')

    assert_raises(::PackmanNova::BuildError) { build(subprocess(status: 2, result_text: '')).call(sync: false) }
    assert_path_exists ::File.join(root, 'state', 'last-build.json')
  end

  it 'falls back to the result files when the result query fails' do
    materialize('fdk-aac')
    fake = subprocess(result_text: nil) { write_result('fdk-aac', release: '1699.1.nova.1') }

    assert_equal 0, build(fake).call(sync: false)
    assert_equal 'succeeded', state('last-build.json').dig('packages', 'fdk-aac', 'code')
  end

  it 'bumps the run above published and built releases' do
    materialize('fdk-aac')
    write_result('fdk-aac', release: '1699.4.nova.1')
    repo_state = ::File.join(root, 'repo', 'opensuse_tumbleweed', 'essentials', 'state.json')
    ::FileUtils.mkdir_p(::File.dirname(repo_state))
    ::File.write(repo_state, '{"run": 6}')
    first = subprocess { write_result('fdk-aac', release: '1699.7.nova.1') }
    second = subprocess { write_result('fdk-aac', release: '1699.8.nova.1') }

    build(first).call(sync: false)
    ::File.write(repo_state, '{"run": 2}')
    build(second).call(sync: false)

    assert_equal %w[--release 1699.7.nova.1], pbuild_argv(first)[-3, 2]
    assert_equal %w[--release 1699.8.nova.1], pbuild_argv(second)[-3, 2]
    assert_equal({ 'run' => 8, 'updated_at' => started.iso8601, 'last_release' => '1699.8.nova.1' }, state('run-counter.json'))
  end

  it 'gives the run back when nothing was built' do
    materialize('fdk-aac')
    fake = subprocess { write_result('fdk-aac', release: '1699.1.nova.1') }
    build(fake).call(sync: false)
    noop = subprocess

    assert_equal 0, build(noop, at: started + 120).call(sync: false)
    assert_equal %w[--release 1699.2.nova.1], pbuild_argv(noop)[-3, 2]
    assert_equal 1, state('run-counter.json')['run']
    assert_equal 2, state('last-build.json')['run']
    assert_empty state('last-build.json')['built']
    assert_includes out.string, 'built 0 of 1'
  end

  it 'uses an explicit release without bumping the counter' do
    materialize('fdk-aac')
    fake = subprocess

    build(fake).call(sync: false, release: '1699.42.nova.3', packages: ['fdk-aac'])

    assert_equal %w[--release 1699.42.nova.3 --rebuild-pkg fdk-aac /project], pbuild_argv(fake).last(5)
    assert_equal 42, state('last-build.json')['run']
    refute_path_exists ::File.join(root, 'state', 'run-counter.json')
  end

  it 'rebuilds everything when sync asks for it and clears the flag afterwards' do
    materialize('fdk-aac')
    ::FileUtils.mkdir_p(::File.join(root, 'state'))
    ::File.write(::File.join(root, 'state', 'sync.json'), '{"schema":1,"packages":{},"rebuild_all_required":true,"distro_snapshot":"20260924"}')
    fake = subprocess

    build(fake).call(sync: false)

    assert_equal %w[--rebuild all /project], pbuild_argv(fake).last(3)
    assert_equal({ 'schema' => 1, 'packages' => {}, 'rebuild_all_required' => false, 'distro_snapshot' => '20260924' }, state('sync.json'))
    assert_equal '20260924', state('last-build.json')['distro_snapshot']
  end

  it 'keeps the rebuild flag for an explicit single build' do
    materialize('fdk-aac')
    ::FileUtils.mkdir_p(::File.join(root, 'state'))
    ::File.write(::File.join(root, 'state', 'sync.json'), '{"schema":1,"packages":{},"rebuild_all_required":true}')
    fake = subprocess

    build(fake).call(sync: false, single: 'fdk-aac')

    assert_equal %w[--single fdk-aac /project], pbuild_argv(fake).last(3)
    assert state('sync.json')['rebuild_all_required']
  end

  it 'rejects unknown packages before running anything' do
    materialize('fdk-aac')
    fake = subprocess

    error = assert_raises(::PackmanNova::BuildError) { build(fake).call(sync: false, packages: %w[fdk-aac nope]) }

    assert_match(/unknown package\(s\) in .*: nope\z/, error.message)
    assert_empty fake.executed
  end

  it 'prints the container command on a dry run' do
    fake = subprocess

    assert_equal 0, build(fake).call(dry_run: true, jobs: 3, checks: false, repo_refresh: false)

    assert_empty fake.executed
    assert_empty sync_calls
    first, second = out.string.lines

    assert_match(%r{pbuild --dist /project/_configs/tumbleweed.conf .* --arch x86_64 .* --jobs 3 --release 1699.1.nova.1 --no-checks --no-repo-refresh /project$}, first)
    assert_match(/--arch i586 .* --release 1699.1.nova.1 --no-checks --baselibs --no-repo-refresh /, second)
    refute_path_exists ::File.join(root, 'state', 'run-counter.json')
  end
end
