# frozen_string_literal: true

require 'time'

module PackmanNova
  class Sync
    class NativeMaterializer
      def initialize(manifest:, services:, workdir:, config:, logger:)
        @manifest = manifest
        @services = services
        @workdir = workdir
        @config = config
        @logger = logger
      end

      def call(previous:, check_only: false)
        files = plain_files + remote_files
        detail = change_detail(previous, files)
        return unchanged(previous) unless detail
        return changed(files.to_h { |file| [file.name, file.md5] }, detail) if check_only

        materialize(detail)
      end

      private

      attr_reader :manifest, :services, :workdir, :config, :logger

      def materialize(detail)
        blobs = fetch_remote
        package_dir.materialize(plain_files + blobs.map(&:first))
        changed(package_dir.md5s, detail, checksums(blobs))
      end

      def plain_files
        vendored_files + local_files + generated_files
      end

      def package_dir
        @package_dir ||= ::PackmanNova::Sync::PackageDir.new(path: workdir.package_dir(manifest.name))
      end

      def vendored_files
        @vendored_files ||= manifest.vendored_files.map { |path| plain_file(::File.basename(path), path) }
      end

      def local_files
        @local_files ||= manifest.sources.select(&:local?).map do |source|
          path = config.resolve(source.path)
          raise ::PackmanNova::SyncError, "local source #{source.file} not found at #{path}" unless ::File.file?(path)

          plain_file(source.file, path)
        end
      end

      def generated_files
        @generated_files ||= manifest.sources.select(&:generated?).map { |source| plain_file(source.file, services.public_key.path) }
      end

      def remote_sources
        manifest.sources.select(&:remote?)
      end

      def remote_files
        remote_sources.map do |source|
          blob = source.sha256 && services.cache.sha256_path(source.sha256)
          ::PackmanNova::Sync::ExpectedFile.new(name: source.file, source: blob, sha256: source.sha256, blob: true)
        end
      end

      def plain_file(name, path)
        ::PackmanNova::Sync::ExpectedFile.new(name: name, source: path, md5: ::PackmanNova::Utils::Digest.md5_file(path))
      end

      def change_detail(previous, files)
        return 'new' unless previous
        return 'file list changed' unless previous.fetch('files', {}).keys.sort == files.map(&:name).sort
        return 'project dir differs' unless package_dir.matches?(files)

        nil
      end

      def fetch_remote
        remote_sources.map do |source|
          blob = services.fetcher.fetch(source, package: manifest.name)
          [::PackmanNova::Sync::ExpectedFile.new(name: source.file, source: blob.path, sha256: blob.sha256, blob: true), source, blob]
        end
      end

      def checksums(blobs)
        blobs.each_with_object({}) do |(_file, source, blob), acc|
          acc[source.file] = { sha256: blob.sha256, size: blob.size } if source.sha256.nil? || source.size.nil?
        end
      end

      def unchanged(previous)
        ::PackmanNova::Sync::Outcome.new(name: manifest.name, status: :unchanged, record: previous)
      end

      def changed(files, detail, checksums = {})
        record = {
          'kind' => manifest.kind, 'origin' => nil, 'srcmd5' => srcmd5(files), 'files' => files, 'synced_at' => ::Time.now.utc.iso8601
        }
        ::PackmanNova::Sync::Outcome.new(name: manifest.name, status: :changed, record: record, detail: detail, checksums: checksums)
      end

      def srcmd5(files)
        ::PackmanNova::Utils::Digest.md5_string(files.sort.map { |name, md5| "#{md5}  #{name}\n" }.join)
      end
    end
  end
end
