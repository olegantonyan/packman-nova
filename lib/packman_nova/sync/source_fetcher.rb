# frozen_string_literal: true

module PackmanNova
  class Sync
    class SourceFetcher
      FETCH_ERRORS = [::PackmanNova::Error, ::SystemCallError].freeze

      def initialize(cache:, downloader:, archive:, logger:)
        @cache = cache
        @downloader = downloader
        @archive = archive
        @logger = logger
      end

      def fetch(source, package:)
        cached(source) || fetch_from_urls(source, package)
      end

      private

      attr_reader :cache, :downloader, :archive, :logger

      def cached(source)
        source.sha256 && cache.cached(sha256: source.sha256, size: source.size)
      end

      def fetch_from_urls(source, package)
        errors = []
        candidate_urls(source).each do |url|
          return cache.fetch(sha256: source.sha256, size: source.size) { |tmp| downloader.download(url, tmp) }
        rescue *FETCH_ERRORS => e
          errors << note_failure(package, source, url, e)
        end
        raise ::PackmanNova::SyncError, "#{source.file}: no url worked (#{errors.join('; ')})"
      end

      def candidate_urls(source)
        urls = [*source.urls, archive.url(source.sha256)].compact
        raise ::PackmanNova::SyncError, "#{source.file}: no urls and no source archive (repository.public_url)" if urls.empty?

        urls
      end

      def note_failure(package, source, url, error)
        message = "#{url}: #{error.message.lines.first.to_s.strip}"
        logger.warn("#{package}: #{source.file}: #{message}")
        message
      end
    end
  end
end
