# frozen_string_literal: true

module PackmanNova
  module Sources
    class PmbsClient
      def initialize(api:, downloader:)
        @api = api.chomp('/')
        @downloader = downloader
        @listings = {}
      end

      def directory(package:)
        listings[package] ||= ::PackmanNova::Sources::Listing.parse(
          downloader.get("#{package_url(package)}?expand=1"), label: "PMBS #{package}"
        )
      end

      def file_url(package:, file:, rev: nil)
        query = rev ? ::PackmanNova::Sources::UrlSegment.query([['rev', rev]]) : '?expand=1'
        "#{package_url(package)}/#{::PackmanNova::Sources::UrlSegment.escape(file)}#{query}"
      end

      def resolve(package:, file:)
        listing = directory(package: package)
        entry = listing.entry(file)
        raise ::PackmanNova::SyncError, "PMBS #{package} has no file #{file}" unless entry

        [file_url(package: package, file: file, rev: listing.srcmd5), entry]
      end

      private

      attr_reader :api, :downloader, :listings

      def package_url(package)
        "#{api}/#{::PackmanNova::Sources::UrlSegment.escape(package)}"
      end
    end
  end
end
