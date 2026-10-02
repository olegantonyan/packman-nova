# frozen_string_literal: true

module PackmanNova
  module Sources
    class ObsClient
      CACHE_EXTENSION = '.xml'

      def initialize(api:, downloader:, workdir:)
        @api = api.chomp('/')
        @downloader = downloader
        @workdir = workdir
      end

      def directory(project:, package:, expand: true, rev: nil)
        label = "#{project}/#{package}"
        cached = cached_listing(project, package, rev, label) if expand && (rev || downloader.offline?)
        return cached if cached
        raise ::PackmanNova::SyncError, "#{label}: offline and no cached OBS listing" if downloader.offline?

        xml = downloader.get(directory_url(project: project, package: package, expand: expand, rev: rev))
        listing = ::PackmanNova::Sources::Listing.parse(xml, label: label)
        store(project, package, xml, [listing.srcmd5, rev]) if expand
        listing
      end

      def directory_url(project:, package:, expand: true, rev: nil)
        "#{package_url(project, package)}#{::PackmanNova::Sources::UrlSegment.query([(%w[expand 1] if expand), (['rev', rev] if rev)])}"
      end

      def file_url(project:, package:, name:, rev:)
        "#{package_url(project, package)}/#{escape(name)}#{::PackmanNova::Sources::UrlSegment.query([['rev', rev]])}"
      end

      def prjconf(project:)
        downloader.get("#{api}/source/#{escape(project)}/_config")
      end

      private

      attr_reader :api, :downloader, :workdir

      def package_url(project, package)
        "#{api}/source/#{escape(project)}/#{escape(package)}"
      end

      def escape(segment)
        ::PackmanNova::Sources::UrlSegment.escape(segment)
      end

      def cached_listing(project, package, rev, label)
        path = rev ? cache_path(project, package, rev) : newest_cached(project, package)
        return nil unless path && ::File.file?(path)

        ::PackmanNova::Sources::Listing.parse(::File.read(path), label: label)
      end

      def newest_cached(project, package)
        ::Dir.glob(::File.join(workdir.obs_cache_dir(project: project, package: package), "*#{CACHE_EXTENSION}")).max_by { |path| ::File.mtime(path) }
      end

      def store(project, package, xml, keys)
        keys.compact.uniq.each { |key| ::PackmanNova::Utils::Path.atomic_write(cache_path(project, package, key), xml) }
      end

      def cache_path(project, package, key)
        ::File.join(workdir.obs_cache_dir(project: project, package: package), "#{key}#{CACHE_EXTENSION}")
      end
    end
  end
end
