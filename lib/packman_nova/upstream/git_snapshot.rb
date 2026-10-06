# frozen_string_literal: true

require 'fileutils'

module PackmanNova
  class Upstream
    class GitSnapshot
      ENV = ::PackmanNova::Upstream::GitProbe::ENV
      DATE_FORMAT = '--date=format:%Y%m%d'
      XZ = '.xz'

      def initialize(workdir:, cache:, subprocess:, logger:)
        @workdir = workdir
        @cache = cache
        @subprocess = subprocess
        @logger = logger
      end

      def call(name:, watch:, probe:)
        repo = fetch(name, watch, probe)
        commit = git(repo, 'rev-parse', '--verify', "#{probe.commit || probe.ref}^{commit}").strip
        version = probe.version || git(repo, 'log', '-1', DATE_FORMAT, "--format=#{watch.format}", commit).strip
        file = watch.file_for(version)
        ::PackmanNova::Upstream::Snapshot.new(
          version:, commit:, file:, blob: archive(repo, watch, commit, version), sover: sover(repo, watch.sover, commit)
        )
      end

      private

      attr_reader :workdir, :cache, :subprocess, :logger

      def fetch(name, watch, probe)
        repo = workdir.git_repo_dir(name)
        init(repo) unless ::File.directory?(repo)
        ref = watch.branch? ? "refs/heads/#{watch.branch}" : "refs/tags/#{probe.ref}"
        logger.info("#{name}: fetch #{watch.git} #{ref}")
        git(repo, 'fetch', '--quiet', '--no-tags', watch.git, "+#{ref}:#{ref}")
        repo
      end

      def init(repo)
        ::PackmanNova::Utils::Path.mkpath(::File.dirname(repo))
        subprocess.capture(['git', 'init', '--quiet', '--bare', repo], env: ENV)
      end

      def archive(repo, watch, commit, version)
        file = watch.file_for(version)
        workdir.mktmpdir('snapshot-') do |dir|
          tar = ::File.join(dir, file.delete_suffix(XZ))
          git(repo, 'archive', '--format=tar', "--prefix=#{watch.archive_dir(version)}/", '-o', tar, commit, '--', '.', *excludes(watch.exclude))
          path = compress(tar, file)
          cache.fetch(sha256: nil, size: nil) { |tmp| ::FileUtils.mv(path, tmp) }
        end
      end

      def compress(tar, file)
        return tar unless file.end_with?(XZ)

        subprocess.capture(['xz', '-9', '-T1', tar])
        "#{tar}#{XZ}"
      end

      def excludes(patterns)
        patterns.flat_map { |pattern| [":(exclude,glob)**/#{pattern}", ":(exclude,glob)**/#{pattern}/**"] }
      end

      def sover(repo, sover, commit)
        return nil unless sover

        content = git(repo, 'show', "#{commit}:#{sover.path}")
        ::Regexp.new(sover.pattern).match(content)&.[](1) || raise(::PackmanNova::UpstreamError, "#{sover.path}: nothing matches #{sover.pattern}")
      end

      def git(repo, *args)
        subprocess.capture(['git', "--git-dir=#{repo}", *args], env: ENV)
      end
    end
  end
end
