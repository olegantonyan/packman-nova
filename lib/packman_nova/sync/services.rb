# frozen_string_literal: true

module PackmanNova
  class Sync
    class Services
      class << self
        def from_config(config:, logger:, workdir:, downloader: nil, extractor: nil)
          downloader ||= ::PackmanNova::Sources::Downloader.from_config(config: config, logger: logger)
          extractor ||= ::PackmanNova::Sources::SrpmExtractor.new(config: config, logger: logger, workdir: workdir)
          new(config: config, logger: logger, workdir: workdir, downloader: downloader, extractor: extractor)
        end
      end

      attr_reader :downloader, :cache, :obs, :pmbs, :mirror, :fetcher

      def initialize(config:, logger:, workdir:, downloader:, extractor:)
        sources = config.sources
        @downloader = downloader
        @cache = ::PackmanNova::Sources::DownloadCache.new(workdir: workdir)
        @obs = ::PackmanNova::Sources::ObsClient.new(api: sources.obs_api, downloader: downloader, workdir: workdir)
        @pmbs = ::PackmanNova::Sources::PmbsClient.new(api: sources.pmbs_api, downloader: downloader)
        @mirror = ::PackmanNova::Sources::MirrorSrc.new(
          urls: sources.mirror_src_urls, downloader: downloader, workdir: workdir, extractor: extractor, logger: logger
        )
        @fetcher = ::PackmanNova::Sync::SourceFetcher.new(cache: cache, downloader: downloader, pmbs: pmbs, mirror: mirror, logger: logger)
      end
    end
  end
end
