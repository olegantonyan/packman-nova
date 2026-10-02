# frozen_string_literal: true

module PackmanNova
  module Sources
    class Downloader
      class << self
        def from_config(config:, logger:)
          http = ::PackmanNova::Utils::Http.new(
            logger: logger, timeout_sec: config.sources.http.timeout_sec, retries: config.sources.http.retries, offline: config.offline?
          )
          new(http: http, logger: logger, offline: config.offline?)
        end
      end

      def initialize(http:, logger:, offline: false)
        @http = http
        @logger = logger
        @offline = offline
      end

      def offline?
        offline
      end

      def get(url)
        logger.debug("GET #{url}")
        http.get(url)
      end

      def head(url)
        http.head(url)
      end

      def download(url, path)
        logger.info("download #{url}")
        http.get_to_file(url, path)
      end

      private

      attr_reader :http, :logger, :offline
    end
  end
end
