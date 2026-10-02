# frozen_string_literal: true

require 'test_helper'
require_relative '../publish/fakes'

describe ::PackmanNova::Repo::Diff do
  let(:tmp) { ::Dir.mktmpdir('packman-nova-diff-') }
  let(:results_dir) { ::File.join(tmp, 'results') }
  let(:repo_dir) { ::File.join(tmp, 'repo') }
  let(:enabled) { %w[fdk-aac ffmpeg-8 libx264] }
  let(:fdk) { ['libfdk-aac2-2.0.3-1.x86_64.rpm', 'fdk-aac-debuginfo-2.0.3-1.x86_64.rpm', 'fdk-aac-2.0.3-1.src.rpm'] }
  let(:ffmpeg) { ['libavcodec62-8.1.2-1.x86_64.rpm', 'ffmpeg-8-lang-8.1.2-1.noarch.rpm', 'ffmpeg-8-8.1.2-1.src.rpm'] }

  after { ::FileUtils.rm_rf(tmp) }

  def diff(record, state: ::PackmanNova::Repo::State.empty, **options)
    ::PackmanNova::Repo::Diff.new(build_record: record, results_dir: results_dir, state: state, enabled: enabled, arch: 'x86_64', repo_dir: repo_dir, **options).call
  end

  def publish(result, key_id: nil)
    files = result.desired.to_h do |relative, entry|
      path = ::File.join(repo_dir, relative)
      ::FileUtils.mkdir_p(::File.dirname(path))
      ::FileUtils.cp(entry.source, path) unless entry.retained?
      [relative, { 'sha256' => 'published', 'size' => 1, 'package' => entry.package, 'source_sha256' => entry.source_sha256, 'key_id' => key_id }]
    end
    ::PackmanNova::Repo::State.new(::PackmanNova::Repo::State.empty.to_h.merge('files' => files))
  end

  before do
    PublishFakes.results(results_dir, 'fdk-aac' => fdk, 'ffmpeg-8' => ffmpeg, 'libx264:x264' => ['x264-1-1.x86_64.rpm', 'libx264-x264-1-1.src.rpm'])
  end

  it 'adds binary, noarch and source rpms of succeeded packages and skips debuginfo' do
    result = diff(PublishFakes.record('fdk-aac' => ['succeeded', fdk], 'ffmpeg-8' => ['succeeded', ffmpeg]))

    assert_equal %w[
      src/fdk-aac-2.0.3-1.src.rpm src/ffmpeg-8-8.1.2-1.src.rpm x86_64/ffmpeg-8-lang-8.1.2-1.noarch.rpm
      x86_64/libavcodec62-8.1.2-1.x86_64.rpm x86_64/libfdk-aac2-2.0.3-1.x86_64.rpm
    ], result.to_add
    assert_empty result.to_remove
    assert_equal ::File.join(results_dir, 'fdk-aac', 'libfdk-aac2-2.0.3-1.x86_64.rpm'), result.desired.fetch('x86_64/libfdk-aac2-2.0.3-1.x86_64.rpm').source
    assert_equal %w[fdk-aac ffmpeg-8], result.succeeded_packages
  end

  it 'honours publish_srpms and publish_debuginfo' do
    record = PublishFakes.record('fdk-aac' => ['succeeded', fdk])
    record['packages']['fdk-aac']['debuginfo_rpms'] = ['fdk-aac-debuginfo-2.0.3-1.x86_64.rpm']

    assert_equal ['x86_64/libfdk-aac2-2.0.3-1.x86_64.rpm'], diff(record, publish_srpms: false).to_add
    assert_includes diff(record, publish_debuginfo: true).to_add, 'x86_64/fdk-aac-debuginfo-2.0.3-1.x86_64.rpm'
  end

  it 'resolves multibuild flavors and absolute paths' do
    record = PublishFakes.record('libx264:x264' => ['succeeded', ['x264-1-1.x86_64.rpm', 'libx264-x264-1-1.src.rpm']])
    record['packages']['libx264:x264']['rpms'] = [::File.join(results_dir, 'libx264:x264', 'x264-1-1.x86_64.rpm')]
    result = diff(record)

    assert_equal ['src/libx264-x264-1-1.src.rpm', 'x86_64/x264-1-1.x86_64.rpm'], result.to_add
    assert_equal 'libx264:x264', result.desired.fetch('x86_64/x264-1-1.x86_64.rpm').package
  end

  it 'is empty on a second run and detects changed and removed files' do
    record = PublishFakes.record('fdk-aac' => ['succeeded', fdk], 'ffmpeg-8' => ['succeeded', ffmpeg])
    state = publish(diff(record))

    assert_predicate diff(record, state: state), :empty?

    ::File.write(::File.join(results_dir, 'fdk-aac', 'libfdk-aac2-2.0.3-1.x86_64.rpm'), 'rebuilt')
    record['packages']['ffmpeg-8']['rpms'] = ['libavcodec62-8.1.2-1.x86_64.rpm']
    result = diff(record, state: state)

    assert_equal ['x86_64/libfdk-aac2-2.0.3-1.x86_64.rpm'], result.to_replace
    assert_equal ['x86_64/ffmpeg-8-lang-8.1.2-1.noarch.rpm'], result.to_remove
    assert_empty result.to_add
  end

  it 're-adds files missing on disk and removes untracked rpms' do
    record = PublishFakes.record('fdk-aac' => ['succeeded', fdk])
    state = publish(diff(record))
    ::File.delete(::File.join(repo_dir, 'src', 'fdk-aac-2.0.3-1.src.rpm'))
    ::File.write(::File.join(repo_dir, 'x86_64', 'stray-1-1.x86_64.rpm'), 'x')
    result = diff(record, state: state)

    assert_equal ['src/fdk-aac-2.0.3-1.src.rpm'], result.to_add
    assert_equal ['x86_64/stray-1-1.x86_64.rpm'], result.to_remove
  end

  it 'retains the published files of enabled packages that did not succeed' do
    state = publish(diff(PublishFakes.record('fdk-aac' => ['succeeded', fdk], 'ffmpeg-8' => ['succeeded', ffmpeg])))
    result = diff(PublishFakes.record('fdk-aac' => ['succeeded', fdk], 'ffmpeg-8' => ['failed', []]), state: state)

    assert_predicate result, :empty?
    assert_equal ['ffmpeg-8'], result.retained_packages
    assert_predicate result.desired.fetch('x86_64/libavcodec62-8.1.2-1.x86_64.rpm'), :retained?
  end

  it 'retains enabled packages missing from the build record but drops disabled ones' do
    state = publish(diff(PublishFakes.record('fdk-aac' => ['succeeded', fdk], 'ffmpeg-8' => ['succeeded', ffmpeg])))
    enabled.delete('fdk-aac')
    result = diff(PublishFakes.record({}), state: state)

    assert_equal ['ffmpeg-8'], result.retained_packages
    assert_equal ['src/fdk-aac-2.0.3-1.src.rpm', 'x86_64/libfdk-aac2-2.0.3-1.x86_64.rpm'], result.to_remove
  end

  it 'ignores succeeded packages that are not enabled' do
    enabled.delete('fdk-aac')
    result = diff(PublishFakes.record('fdk-aac' => ['succeeded', fdk]))

    assert_empty result.to_add
    assert_equal ['fdk-aac: succeeded but not enabled'], result.ignored
  end

  it 're-signs files published without the current key' do
    record = PublishFakes.record('fdk-aac' => ['succeeded', fdk], 'ffmpeg-8' => ['succeeded', ffmpeg])
    state = publish(diff(record))
    failed = PublishFakes.record('fdk-aac' => ['succeeded', fdk], 'ffmpeg-8' => ['failed', []])
    result = diff(failed, state: state, key_id: 'NEWKEY')

    assert_equal state.files.keys.sort, result.to_resign
    assert_predicate diff(failed, state: publish(diff(record), key_id: 'NEWKEY'), key_id: 'NEWKEY'), :empty?
  end

  it 'trusts the state when files are not checked' do
    record = PublishFakes.record('fdk-aac' => ['succeeded', fdk])
    state = publish(diff(record))
    ::FileUtils.rm_rf(repo_dir)

    assert_predicate diff(record, state: state, check_files: false), :empty?
  end

  it 'fails on missing build outputs and on files claimed by two packages' do
    record = PublishFakes.record('fdk-aac' => ['succeeded', fdk])
    record['packages']['fdk-aac']['rpms'] << 'gone-1-1.x86_64.rpm'

    assert_raises(::PackmanNova::PublishError) { diff(record) }

    PublishFakes.results(results_dir, 'libx264' => ['libfdk-aac2-2.0.3-1.x86_64.rpm'])
    enabled << 'libx264'
    clash = PublishFakes.record('fdk-aac' => ['succeeded', fdk], 'libx264' => ['succeeded', ['libfdk-aac2-2.0.3-1.x86_64.rpm']])

    assert_raises(::PackmanNova::PublishError) { diff(clash) }
  end

  it 'leaves files of other arches alone' do
    PublishFakes.results(results_dir, 'fdk-aac' => ['libfdk-aac2-2.0.3-1.i586.rpm'])
    record = PublishFakes.record('fdk-aac' => ['succeeded', [*fdk, 'libfdk-aac2-2.0.3-1.i586.rpm']])
    state = ::PackmanNova::Repo::State.new(::PackmanNova::Repo::State.empty.to_h.merge('files' => { 'aarch64/a-1-1.aarch64.rpm' => { 'package' => 'fdk-aac' } }))
    result = diff(record, state: state)

    assert_empty result.to_remove
    assert_includes result.ignored, 'libfdk-aac2-2.0.3-1.i586.rpm: arch i586 is not published into x86_64/'
  end
end
