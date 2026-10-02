# frozen_string_literal: true

module PackmanNova
  module Sources
    class Reachability
      TIMEOUT_SEC = 20

      def initialize(config:, logger:, http: nil)
        @config = config
        @http = http || ::PackmanNova::Utils::Http.new(logger: logger, timeout_sec: TIMEOUT_SEC, retries: 0)
      end

      def probes
        [
          ['obs api', "#{config.sources.obs_api.chomp('/')}/source/openSUSE:Factory/_config", :fail],
          ['tw repo', config.distro.snapshot_url, :fail],
          ['pmbs', config.sources.pmbs_api, :warn]
        ]
      end

      def call
        probes.map { |name, url, severity| probe(name, url, severity) }
      end

      private

      attr_reader :config, :http

      def probe(name, url, severity)
        [:ok, name, "#{url} HTTP #{http.head(url).code}"]
      rescue ::PackmanNova::DownloadError => e
        [severity, name, e.message]
      end
    end
  end
end
