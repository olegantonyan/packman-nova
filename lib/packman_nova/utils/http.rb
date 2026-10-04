# frozen_string_literal: true

require 'fileutils'
require 'net/http'
require 'openssl'
require 'uri'

module PackmanNova
  module Utils
    class Http
      MAX_REDIRECTS = 10
      OPEN_TIMEOUT_SEC = 30
      BASE_DELAY_SEC = 1
      MAX_DELAY_SEC = 60
      REQUEST_CLASSES = { get: ::Net::HTTP::Get, head: ::Net::HTTP::Head }.freeze
      NETWORK_ERRORS = [
        ::Timeout::Error, ::IOError, ::EOFError, ::SocketError, ::OpenSSL::SSL::SSLError, ::Net::HTTPBadResponse,
        ::Errno::ECONNREFUSED, ::Errno::ECONNRESET, ::Errno::EHOSTUNREACH, ::Errno::ENETUNREACH, ::Errno::ETIMEDOUT, ::Errno::EPIPE
      ].freeze

      def initialize(logger:, timeout_sec: 600, retries: 5, offline: false, sleeper: ->(seconds) { sleep(seconds) })
        @logger = logger
        @timeout_sec = timeout_sec
        @retries = retries
        @offline = offline
        @sleeper = sleeper
      end

      def get(url)
        request(:get, url, &:read_body)
      end

      def head(url)
        request(:head, url) { |response| response }
      end

      def get_to_file(url, path)
        part = "#{path}.part"
        ::FileUtils.mkdir_p(::File.dirname(path))
        request(:get, url) do |response|
          ::File.open(part, 'wb') { |file| response.read_body { |chunk| file.write(chunk) } }
        end
        ::File.rename(part, path)
        path
      ensure
        ::FileUtils.rm_f(part)
      end

      private

      attr_reader :logger, :timeout_sec, :retries, :offline, :sleeper

      def request(method, url, &)
        raise ::PackmanNova::DownloadError.new("offline, not fetching #{url}", url: url, attempts: 0) if offline

        attempt = 0
        loop do
          attempt += 1
          outcome, value = perform_once(method, url, &)
          return value if outcome == :ok
          raise ::PackmanNova::DownloadError.new("#{url}: #{value}", url: url, attempts: attempt) if outcome == :fail || attempt > retries

          pause(attempt, url, value)
        end
      end

      def perform_once(method, url, &)
        follow(method, url, MAX_REDIRECTS, &)
      rescue *NETWORK_ERRORS => e
        [:retry, "#{e.class}: #{e.message}"]
      end

      def follow(method, url, redirects_left, &)
        outcome, value = fetch(method, parse_uri(url), &)
        return [outcome, value] unless outcome == :redirect
        return [:fail, "too many redirects (#{MAX_REDIRECTS})"] if redirects_left.zero?

        logger.debug("redirect #{url} -> #{value}")
        follow(method, value, redirects_left - 1, &)
      end

      def fetch(method, uri, &)
        result = nil
        ::Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: OPEN_TIMEOUT_SEC, read_timeout: timeout_sec) do |http|
          http.request(build_request(method, uri)) { |response| result = classify(response, uri, &) }
        end
        result
      end

      def classify(response, uri, &handler)
        case response
        when ::Net::HTTPSuccess then [:ok, handler.call(response)]
        when ::Net::HTTPRedirection then [:redirect, ::URI.join(uri.to_s, response['location'].to_s).to_s]
        when ::Net::HTTPServerError, ::Net::HTTPTooManyRequests then [:retry, "HTTP #{response.code}"]
        else [:fail, "HTTP #{response.code} #{response.message}".strip]
        end
      end

      def build_request(method, uri)
        request = REQUEST_CLASSES.fetch(method).new(uri)
        request['User-Agent'] = "packman-nova/#{::PackmanNova::VERSION}"
        request
      end

      def parse_uri(url)
        uri = ::URI.parse(url)
        return uri if uri.is_a?(::URI::HTTP) && uri.host

        raise ::PackmanNova::DownloadError.new("unsupported URL: #{url}", url: url, attempts: 0)
      rescue ::URI::InvalidURIError
        raise ::PackmanNova::DownloadError.new("invalid URL: #{url}", url: url, attempts: 0)
      end

      def pause(attempt, url, reason)
        delay = [BASE_DELAY_SEC * (2**(attempt - 1)), MAX_DELAY_SEC].min
        logger.warn("#{url}: #{reason}; retry #{attempt}/#{retries} in #{delay}s")
        sleeper.call(delay)
      end
    end
  end
end
