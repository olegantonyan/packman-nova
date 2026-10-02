# frozen_string_literal: true

require 'yaml'

module PackmanNova
  class Sync
    class ChecksumUpdater
      def initialize(manifest_path:)
        @manifest_path = manifest_path
      end

      def call(checksums)
        return false if checksums.empty?

        data = ::PackmanNova::Utils::Yaml.load_file(manifest_path)
        return false unless fill(data.fetch('sources', []), checksums)

        ::PackmanNova::Utils::Path.atomic_write(manifest_path, ::YAML.dump(data).delete_prefix("---\n"))
        true
      end

      private

      attr_reader :manifest_path

      def fill(sources, checksums)
        sources.select { |source| checksums.key?(source['file']) }.map do |source|
          values = checksums.fetch(source['file'])
          before = source.slice('sha256', 'size')
          source['sha256'] ||= values.fetch(:sha256)
          source['size'] ||= values.fetch(:size)
          before != source.slice('sha256', 'size')
        end.any?
      end
    end
  end
end
