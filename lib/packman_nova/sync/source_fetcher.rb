# frozen_string_literal: true

module PackmanNova
  class Sync
    class SourceFetcher
      FETCH_ERRORS = [::PackmanNova::Error, ::SystemCallError].freeze

      def initialize(cache:, downloader:, pmbs:, mirror:, logger:)
        @cache = cache
        @downloader = downloader
        @pmbs = pmbs
        @mirror = mirror
        @logger = logger
      end

      def fetch(source, package:)
        cached(source) || fetch_from_urls(source, package)
      end

      private

      attr_reader :cache, :downloader, :pmbs, :mirror, :logger

      def cached(source)
        source.sha256 && cache.cached(sha256: source.sha256, size: source.size)
      end

      def fetch_from_urls(source, package)
        errors = []
        source.urls.each do |url|
          return try_url(source, url)
        rescue *FETCH_ERRORS => e
          errors << note_failure(package, source, url, e)
        end
        raise ::PackmanNova::SyncError, "#{source.file}: no url worked (#{errors.join('; ')})"
      end

      def note_failure(package, source, url, error)
        message = "#{url}: #{error.message.lines.first.to_s.strip}"
        logger.warn("#{package}: #{source.file}: #{message}")
        message
      end

      def try_url(source, url)
        cache.fetch(sha256: source.sha256, size: source.size) { |tmp| download(source, url, tmp) }
      end

      def download(source, url, tmp)
        case source.scheme(url)
        when :http then downloader.download(url, tmp)
        when :pmbs then download_pmbs(source, url, tmp)
        when :mirror_src then mirror.fetch(package: source.mirror_package(url), file: source.file, target: tmp)
        end
      end

      def download_pmbs(source, url, tmp)
        file_url, = pmbs.resolve(package: source.pmbs_package(url), file: source.pmbs_file(url))
        downloader.download(file_url, tmp)
      end
    end
  end
end
