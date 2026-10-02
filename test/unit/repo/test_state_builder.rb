# frozen_string_literal: true

require 'test_helper'
require_relative '../publish/fakes'

describe ::PackmanNova::Repo::StateBuilder do
  let(:tmp) { ::Dir.mktmpdir('packman-nova-state-') }
  let(:layout) { ::PackmanNova::Repo::Layout.new(root: tmp, path: 'p') }
  let(:manifests) { [PublishFakes.manifest('ffmpeg-8', kind: 'obs-link'), PublishFakes.manifest('libx264'), PublishFakes.manifest('vlc')] }
  let(:entry) { ::PackmanNova::Repo::BuildOutputs::Entry }
  let(:now) { ::Time.utc(2026, 9, 29, 12) }

  after { ::FileUtils.rm_rf(tmp) }

  def publish_file(relative, content = relative)
    path = layout.file(relative)
    ::FileUtils.mkdir_p(::File.dirname(path))
    ::File.write(path, content)
  end

  def diff(desired, stage:, succeeded:, retained: [])
    ::PackmanNova::Repo::Diff::Result.new(
      desired: desired, to_add: stage, to_replace: [], to_remove: [], to_resign: [], retained_packages: retained, succeeded_packages: succeeded, ignored: []
    )
  end

  it 'records files, package versions, origins and the signing key' do
    %w[x86_64/x264-1-2.x86_64.rpm src/libx264-x264-1-2.src.rpm].each { |relative| publish_file(relative) }
    desired = {
      'x86_64/x264-1-2.x86_64.rpm' => entry.new(relative: 'x86_64/x264-1-2.x86_64.rpm', package: 'libx264:x264', source: '/r/x264', source_sha256: 'src1'),
      'src/libx264-x264-1-2.src.rpm' => entry.new(relative: 'src/libx264-x264-1-2.src.rpm', package: 'libx264:x264', source: '/r/src', source_sha256: 'src2')
    }
    info = ::PackmanNova::Repo::RpmQuery::Info.new(name: 'libx264-x264', evr: '1-2', arch: 'x86_64', sourcerpm: '(none)', pgpsig: '(none)', summary: 's')
    record = PublishFakes.record({ 'libx264:x264' => ['succeeded', []], 'vlc' => ['unresolvable', []] }, 5)
    state = ::PackmanNova::Repo::StateBuilder.new(
      previous: ::PackmanNova::Repo::State.empty, build_record: record, diff: diff(desired, stage: desired.keys, succeeded: ['libx264:x264']),
      layout: layout, manifests: manifests, sync_state: { 'packages' => { 'libx264' => { 'srcmd5' => 'abc' } } },
      versions: { 'libx264:x264' => info }, key: PublishFakes.key, now: now
    ).call

    assert_equal [5, '1699.5.nova.1', '2026-09-29T12:00:00Z'], [state.run, state.release, state.to_h['generated_at']]
    assert_equal({ 'id' => PublishFakes::KEY_ID, 'fingerprint' => PublishFakes::FINGERPRINT }, state.to_h['key'])
    file = state.files.fetch('x86_64/x264-1-2.x86_64.rpm')

    assert_equal [::Digest::SHA256.hexdigest('x86_64/x264-1-2.x86_64.rpm'), 26, 'libx264:x264', 'src1', PublishFakes::KEY_ID],
                 file.values_at('sha256', 'size', 'package', 'source_sha256', 'key_id')
    package = state.packages.fetch('libx264:x264')

    assert_equal ['native', nil, 'abc', '1', '2', 'succeeded', 5], package.values_at('kind', 'origin', 'srcmd5', 'version', 'release', 'status', 'last_run')
    assert_equal [['x86_64/x264-1-2.x86_64.rpm'], 'src/libx264-x264-1-2.src.rpm'], package.values_at('rpms', 'srpm')
    assert_equal %w[unresolvable vlc], [state.packages.fetch('vlc')['status'], state.packages.keys.last]
  end

  it 'keeps retained packages with their previous metadata and the new status' do
    publish_file('x86_64/libavcodec62-8-1.x86_64.rpm')
    previous = ::PackmanNova::Repo::State.new(
      ::PackmanNova::Repo::State.empty.to_h.merge(
        'run' => 7,
        'files' => { 'x86_64/libavcodec62-8-1.x86_64.rpm' => { 'sha256' => 'x', 'size' => 1, 'package' => 'ffmpeg-8', 'source_sha256' => 'y', 'key_id' => 'K' } },
        'packages' => { 'ffmpeg-8' => { 'kind' => 'obs-link', 'version' => '8', 'release' => '1', 'status' => 'succeeded', 'last_run' => 6, 'rpms' => [], 'srpm' => nil } }
      )
    )
    desired = { 'x86_64/libavcodec62-8-1.x86_64.rpm' => entry.new(relative: 'x86_64/libavcodec62-8-1.x86_64.rpm', package: 'ffmpeg-8', source: nil, source_sha256: 'y') }
    state = ::PackmanNova::Repo::StateBuilder.new(
      previous: previous, build_record: PublishFakes.record({ 'ffmpeg-8' => ['failed', []] }, 3), diff: diff(desired, stage: [], succeeded: [], retained: ['ffmpeg-8']),
      layout: layout, manifests: manifests, now: now
    ).call
    package = state.packages.fetch('ffmpeg-8')

    assert_equal 7, state.run
    assert_equal previous.files, state.files
    assert_equal ['failed', 'failed reason', '8', 6, ['x86_64/libavcodec62-8-1.x86_64.rpm']], package.values_at('status', 'reason', 'version', 'last_run', 'rpms')
    assert_nil state.to_h['key']
  end
end
