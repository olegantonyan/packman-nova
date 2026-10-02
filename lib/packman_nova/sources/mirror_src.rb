# frozen_string_literal: true

module PackmanNova
  module Sources
    class MirrorSrc
      CACHE_SUBDIR = 'mirror-src'

      def initialize(urls:, downloader:, workdir:, extractor:, logger:)
        @urls = urls
        @downloader = downloader
        @workdir = workdir
        @extractor = extractor
        @logger = logger
        @indexes = {}
      end

      def fetch(package:, file:, target:)
        extractor.extract(srpm: local_srpm(package), member: file, target: target)
      end

      def newest(package)
        raise ::PackmanNova::SyncError, "mirror-src:#{package}: offline" if downloader.offline?

        candidates = urls.flat_map { |url| index(url).candidates(package) }
        ::PackmanNova::Sources::MirrorIndex.newest(candidates) ||
          raise(::PackmanNova::SyncError, "mirror-src:#{package}: no #{package}-<version>-<release>.src.rpm in #{urls.join(', ')}")
      end

      private

      attr_reader :urls, :downloader, :workdir, :extractor, :logger, :indexes

      def local_srpm(package)
        candidate = newest(package)
        path = ::File.join(workdir.cache_dir, CACHE_SUBDIR, candidate.file_name)
        logger.info("mirror-src:#{package}: #{candidate.file_name}")
        downloader.download(candidate.url, path) unless ::File.file?(path)
        path
      end

      def index(url)
        indexes[url] ||= ::PackmanNova::Sources::MirrorIndex.parse(downloader.get(url), base_url: url)
      end
    end
  end
end
