# frozen_string_literal: true

module PackmanNova
  class Sync
    class Services
      class << self
        def from_config(config:, logger:, workdir:, downloader: nil, gpg: nil)
          downloader ||= ::PackmanNova::Sources::Downloader.from_config(config:, logger:)
          new(config:, logger:, workdir:, downloader:, gpg:)
        end
      end

      attr_reader :downloader, :cache, :obs, :fetcher, :public_key, :snapshot

      def initialize(config:, logger:, workdir:, downloader:, gpg: nil)
        @downloader = downloader
        @cache = ::PackmanNova::Sources::DownloadCache.new(workdir:)
        @obs = ::PackmanNova::Sources::ObsClient.new(api: config.sources.obs_api, downloader:, workdir:)
        archive = ::PackmanNova::Sources::Archive.from_config(config)
        @fetcher = ::PackmanNova::Sync::SourceFetcher.new(cache:, downloader:, archive:, logger:)
        @public_key = ::PackmanNova::Sync::PublicKey.new(config:, logger:, workdir:, gpg:)
        @snapshot = snapshot_revisions(config.distro.source_snapshot, logger, workdir)
      end

      private

      def snapshot_revisions(source_snapshot, logger, workdir)
        return if source_snapshot.repo.empty?

        subprocess = ::PackmanNova::Utils::Subprocess.new(logger:)
        ::PackmanNova::Sources::SnapshotRevisions.new(repo: source_snapshot.repo, project: source_snapshot.project, downloader:, subprocess:, workdir:)
      end
    end
  end
end
