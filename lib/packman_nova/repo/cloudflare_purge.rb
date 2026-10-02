# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module PackmanNova
  module Repo
    class CloudflarePurge
      API = 'https://api.cloudflare.com/client/v4'
      TIMEOUT_SEC = 60

      def initialize(zone_id:, api_token:, logger:, api: API)
        @zone_id = zone_id
        @api_token = api_token
        @logger = logger
        @api = api
      end

      def call(prefix)
        response = post(::URI.parse("#{api}/zones/#{zone_id}/purge_cache"), { prefixes: [prefix] })
        ok = success?(response)
        ok ? logger.info("cloudflare: purged cache for #{prefix}") : logger.warn("cloudflare: cache purge for #{prefix} failed: HTTP #{response.code}")
        ok
      rescue ::StandardError => e
        logger.warn("cloudflare: cache purge for #{prefix} failed: #{e.class}: #{e.message}")
        false
      end

      private

      attr_reader :zone_id, :api_token, :logger, :api

      def post(uri, payload)
        request = ::Net::HTTP::Post.new(uri)
        request['Authorization'] = "Bearer #{api_token}"
        request['Content-Type'] = 'application/json'
        request.body = ::JSON.generate(payload)
        ::Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: TIMEOUT_SEC, read_timeout: TIMEOUT_SEC) { |http| http.request(request) }
      end

      def success?(response)
        response.is_a?(::Net::HTTPSuccess) && ::JSON.parse(response.body.to_s).fetch('success', false) == true
      rescue ::JSON::ParserError
        false
      end
    end
  end
end
