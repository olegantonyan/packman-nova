# frozen_string_literal: true

module PackmanNova
  class Sync
    class Snapshot
      DATE = /\b(\d{8})\b/

      def initialize(url:, downloader:, logger:)
        @url = url
        @downloader = downloader
        @logger = logger
      end

      def call(previous: nil)
        return previous if downloader.offline?

        self.class.parse(downloader.get(url)) || previous
      rescue ::PackmanNova::DownloadError => e
        logger.warn("Tumbleweed snapshot: #{e.message}")
        previous
      end

      class << self
        def parse(body)
          body[DATE, 1] || body.lines.first&.strip
        end
      end

      private

      attr_reader :url, :downloader, :logger
    end
  end
end
