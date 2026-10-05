# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::State::BuildRecord do
  def result(key, rpm_files:, status: 'succeeded', dir: '/w/project/_build.tumbleweed.x86_64')
    ::PackmanNova::Pbuild::PackageResult.new(
      key:, dir: ::File.join(dir, key), rpm_files:, status:, reason: 'new build',
      log: ::File.join(dir, key, '_log'), built_at: ::Time.utc(2026, 9, 29, 11, 0, 0), duration_sec: 42
    )
  end

  let(:workdir) { ::PackmanNova::Workdir.new(root: '/w') }
  let(:record) do
    ::PackmanNova::State::BuildRecord.new(workdir:).compose(
      results: {
        'libx264:x264' => result('libx264:x264', rpm_files: %w[x264-0.165-1699.2.nova.1.x86_64.rpm libx264-0.165-1699.2.nova.1.src.rpm]),
        'vlc' => result('vlc', rpm_files: [], status: 'failed')
      },
      codes: { 'libx264:x264' => 'succeeded', 'vlc' => 'failed', 'ffmpeg-6' => 'unresolvable' }, details: { 'ffmpeg-6' => 'nothing provides foo' },
      run: 2, release: '1699.2.nova.1', started_at: ::Time.utc(2026, 9, 29, 10, 0, 0), pbuild_argv: %w[pbuild /project]
    )
  end

  it 'composes a schema-valid record with merged codes' do
    assert_equal ::PackmanNova::State::Schemas.validate!(:build_record, record), record
    assert_equal({ 'failed' => 1, 'succeeded' => 1, 'unresolvable' => 1 }, record['codes'])
    assert_equal %w[ffmpeg-6 libx264:x264 vlc], record['packages'].keys
    assert_equal '2026-09-29T10:00:00Z', record['started_at']
  end

  it 'describes built packages' do
    assert_equal(
      {
        'code' => 'succeeded', 'flavor' => 'x264', 'reason' => 'new build', 'rpms' => ['x264-0.165-1699.2.nova.1.x86_64.rpm'],
        'debuginfo_rpms' => [], 'srpm' => 'libx264-0.165-1699.2.nova.1.src.rpm', 'log' => 'project/_build.tumbleweed.x86_64/libx264:x264/_log',
        'built_at' => '2026-09-29T11:00:00Z', 'duration_sec' => 42, 'details' => nil
      },
      record.dig('packages', 'libx264:x264')
    )
  end

  it 'keeps packages known only from pbuild codes' do
    assert_equal({ 'code' => 'unresolvable', 'rpms' => [], 'srpm' => nil, 'details' => 'nothing provides foo' },
                 record.dig('packages', 'ffmpeg-6').slice('code', 'rpms', 'srpm', 'details'))
  end

  it 'writes the run file and last-build.json' do
    with_tmpdir do |dir|
      store = ::PackmanNova::State::BuildRecord.new(workdir: ::PackmanNova::Workdir.new(root: dir))
      path = store.write(record)

      assert_equal ::File.join(dir, 'state', 'builds', '2.json'), path
      assert_equal ::JSON.parse(::File.read(path)), store.last
      assert_equal record, ::JSON.parse(::JSON.generate(store.last))
    end
  end

  it 'refuses records without required keys' do
    with_tmpdir do |dir|
      assert_raises(::PackmanNova::Error) { ::PackmanNova::State::BuildRecord.new(workdir: ::PackmanNova::Workdir.new(root: dir)).write({ 'run' => 1 }) }
    end
  end
end
