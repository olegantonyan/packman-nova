# frozen_string_literal: true

module PackmanNova
  module Repo
    class SourceArchive
      CONTENT_TYPE = 'application/octet-stream'

      def initialize(manifests:, workdir:, logger:)
        @manifests = manifests
        @workdir = workdir
        @logger = logger
      end

      def call(bucket)
        present = bucket.list(::PackmanNova::Sources::Archive::PREFIX)
        missing = blobs.reject { |sha256, _path| present.key?(::PackmanNova::Sources::Archive.key(sha256)) }
        logger.info("source archive: #{blobs.size} source(s), uploading #{missing.size}")
        missing.each { |sha256, path| bucket.upload(path, ::PackmanNova::Sources::Archive.key(sha256), content_type: CONTENT_TYPE) }
        missing.keys
      end

      private

      attr_reader :manifests, :workdir, :logger

      def blobs
        @blobs ||= remote_sources.each_with_object({}) do |source, acc|
          path = workdir.cache_blob(sha256: source.sha256)
          next acc[source.sha256] = path if ::File.file?(path)

          logger.warn("source archive: #{source.file} (#{source.sha256}) is not in the cache, run sync first")
        end
      end

      def remote_sources
        manifests.select(&:enabled?).flat_map(&:sources).select { |source| source.remote? && source.sha256 }
      end
    end
  end
end
