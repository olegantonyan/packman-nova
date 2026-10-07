# frozen_string_literal: true

require 'time'

module PackmanNova
  class Sync
    class ObsLinkMaterializer
      def initialize(manifest:, services:, workdir:, logger:)
        @manifest = manifest
        @services = services
        @workdir = workdir
        @logger = logger
      end

      def call(previous:, check_only: false)
        listing = fetch_listing
        files = expected_files(listing)
        detail = change_detail(previous, listing, files)
        return outcome(:unchanged, listing, files, previous:) unless detail
        return outcome(:changed, listing, files, detail:) if check_only

        files.select(&:blob).each { |file| ensure_blob(file, listing) }
        package_dir.materialize(files)
        outcome(:changed, listing, files, detail:)
      end

      private

      attr_reader :manifest, :services, :workdir, :logger

      def origin
        manifest.origin
      end

      def fetch_listing
        services.obs.directory(project: origin.project, package: origin.package, rev: origin.pin)
      end

      def package_dir
        @package_dir ||= ::PackmanNova::Sync::PackageDir.new(path: workdir.package_dir(manifest.name))
      end

      def expected_files(listing)
        files = listing.entries.reject { |entry| manifest.link_delete.include?(entry.name) }.map { |entry| listed_file(entry) }
        files = patched_spec(files, listing) if link_files.patches?
        files + link_files.files
      end

      def listed_file(entry)
        ::PackmanNova::Sync::ExpectedFile.new(name: entry.name, source: services.cache.md5_path(entry.md5), md5: entry.md5, blob: true)
      end

      def patched_spec(files, listing)
        spec = spec_file(files)
        ensure_blob(spec, listing)
        patched = link_files.spec(spec)
        files.map { |file| file.equal?(spec) ? patched : file }
      end

      def spec_file(files)
        files.find { |file| file.name == manifest.spec_name } || raise(::PackmanNova::SyncError, "#{manifest.name}: #{manifest.spec_name} not in #{origin}")
      end

      def link_files
        @link_files ||= ::PackmanNova::Sync::LinkFiles.new(manifest:, cache: services.cache)
      end

      def change_detail(previous, listing, files)
        return 'new' unless previous
        return "srcmd5 #{previous['srcmd5']} -> #{listing.srcmd5}" unless previous['srcmd5'] == listing.srcmd5
        return 'file list changed' unless previous.fetch('files', {}).keys.sort == files.map(&:name).sort
        return 'project dir differs' unless package_dir.matches?(files)

        nil
      end

      def ensure_blob(file, listing)
        entry = listing.entry(file.name)
        url = file_url(entry, listing)
        services.cache.store_md5(md5: entry.md5, size: entry.size) { |tmp| services.downloader.download(url, tmp) }
      end

      def file_url(entry, listing)
        services.obs.file_url(project: origin.project, package: origin.package, name: entry.name, rev: listing.srcmd5)
      end

      def outcome(status, listing, files, detail: nil, previous: nil)
        record = {
          'kind' => manifest.kind, 'origin' => origin.to_s, 'srcmd5' => listing.srcmd5,
          'files' => files.to_h { |file| [file.name, file.md5] },
          'synced_at' => previous&.fetch('synced_at', nil) || ::Time.now.utc.iso8601
        }
        ::PackmanNova::Sync::Outcome.new(name: manifest.name, status:, record:, detail:)
      end
    end
  end
end
