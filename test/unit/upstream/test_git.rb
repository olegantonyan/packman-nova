# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Upstream::GitProbe do
  let(:dir) { ::Dir.mktmpdir('packman-nova-git-') }
  let(:repo) { ::GitFixture.new(::File.join(dir, 'repo')) }
  let(:subprocess) { ::PackmanNova::Utils::Subprocess.new(logger: null_logger) }
  let(:workdir) { ::PackmanNova::Workdir.new(root: ::File.join(dir, 'wd')).prepare! }
  let(:snapshots) do
    ::PackmanNova::Upstream::GitSnapshot.new(workdir:, cache: ::PackmanNova::Sources::DownloadCache.new(workdir:), subprocess:, logger: null_logger)
  end

  after { ::FileUtils.rm_rf(dir) }

  def watch(**attributes)
    ::PackmanNova::Manifest::Watch.new(git: repo.url, **attributes)
  end

  def probe(watch, version: nil)
    ::PackmanNova::Upstream::GitProbe.new(subprocess:).call(watch, version:)
  end

  def entries(path)
    subprocess.capture(['tar', 'tf', path]).lines.map(&:strip).sort
  end

  describe 'tags' do
    let(:tags_watch) { watch(tags: '^v(\d+(?:\.\d+)+)$', file: 'snap-%{version}.tar', exclude: %w[.gitignore tests]) }

    before do
      repo.commit('lib.h' => "BUILD 1\n", '.gitignore' => "x\n", 'tests/a' => "a\n", 'sub/tests/b' => "b\n", 'sub/c' => "c\n")
      repo.tag('v1.9')
      repo.commit('lib.h' => "BUILD 2\n")
      repo.tag('v1.10')
      repo.tag('v2.0-rc1')
    end

    it 'finds the newest matching tag and its commit' do
      result = probe(tags_watch)

      assert_equal ['1.10', repo.head, 'v1.10'], [result.version, result.commit, result.ref]
    end

    it 'finds an explicit version and rejects an unknown one' do
      assert_equal 'v1.9', probe(tags_watch, version: '1.9').ref
      assert_raises(::PackmanNova::UpstreamError) { probe(tags_watch, version: '3.0') }
    end

    it 'archives the tag deterministically with excludes and reads sover' do
      sover = ::PackmanNova::Manifest::Watch::Sover.new(path: 'lib.h', pattern: 'BUILD (\d+)')
      sover_watch = watch(tags: tags_watch.tags, file: tags_watch.file, exclude: tags_watch.exclude, sover:)
      first = snapshots.call(name: 'snap', watch: sover_watch, probe: probe(sover_watch))
      second = snapshots.call(name: 'snap', watch: sover_watch, probe: probe(sover_watch))

      assert_equal ['1.10', 'snap-1.10.tar', '2', repo.head], [first.version, first.file, first.sover, first.commit]
      assert_equal first.blob.sha256, second.blob.sha256
      assert_equal %w[snap-1.10/ snap-1.10/lib.h snap-1.10/sub/ snap-1.10/sub/c], entries(first.blob.path)
    end
  end

  describe 'branch' do
    let(:branch_watch) { watch(branch: 'main', format: '1.0.%cd.%h', file: 'snap-%{version}.tar.xz') }

    it 'reports the head commit and versions it from the commit date' do
      repo.commit({ 'a' => "1\n" }, date: '2026-03-04T05:06:07Z')
      result = probe(branch_watch)
      snapshot = snapshots.call(name: 'snap', watch: branch_watch, probe: result)

      assert_equal [nil, repo.head, 'main'], [result.version, result.commit, result.ref]
      assert_match(/\A1\.0\.20260304\.\h{7,}\z/, snapshot.version)
      assert_includes entries(snapshot.blob.path), "snap-#{snapshot.version}/a"
    end

    it 'archives an explicit older commit of the branch' do
      old = repo.commit('a' => "1\n")
      repo.commit('a' => "2\n")
      snapshot = snapshots.call(name: 'snap', watch: branch_watch, probe: probe(branch_watch, version: old[0, 10]))

      assert_equal old, snapshot.commit
    end
  end
end
