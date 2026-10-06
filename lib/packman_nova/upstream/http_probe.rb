# frozen_string_literal: true

module PackmanNova
  class Upstream
    class HttpProbe
      def initialize(downloader:)
        @downloader = downloader
      end

      def call(watch, version: nil)
        return ::PackmanNova::Upstream::Probe.new(version:, commit: nil, ref: nil) if version

        versions = downloader.get(watch.url).scan(watch.version_regexp).map { |match| Array(match).first }.uniq
        raise ::PackmanNova::UpstreamError, "#{watch.url}: nothing matches #{watch.pattern}" if versions.empty?

        ::PackmanNova::Upstream::Probe.new(version: ::PackmanNova::Upstream::VersionCompare.max(versions), commit: nil, ref: nil)
      end

      private

      attr_reader :downloader
    end
  end
end
