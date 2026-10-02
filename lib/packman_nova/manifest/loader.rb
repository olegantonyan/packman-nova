# frozen_string_literal: true

module PackmanNova
  class Manifest
    class Loader
      attr_reader :packages_dir

      def initialize(packages_dir:, require_checksums: true)
        @packages_dir = ::File.expand_path(packages_dir)
        @require_checksums = require_checksums
      end

      def all
        raise errors.first unless errors.empty?

        manifests
      end

      def enabled
        all.select(&:enabled?)
      end

      def find(name)
        all.find { |manifest| manifest.name == name } || raise(::PackmanNova::ManifestError, "unknown package: #{name}")
      end

      def skipped
        results.fetch(:skipped)
      end

      def errors
        results.fetch(:errors)
      end

      def manifests
        results.fetch(:manifests)
      end

      private

      attr_reader :require_checksums

      def results
        @results ||= package_dirs.each_with_object({ manifests: [], errors: [], skipped: [] }) do |dir, acc|
          load_dir(dir, acc)
        end.transform_values(&:freeze).freeze
      end

      def load_dir(dir, acc)
        path = ::File.join(dir, ::PackmanNova::Manifest::FILE_NAME)
        return acc[:skipped] << ::File.basename(dir) unless ::File.file?(path)

        acc[:manifests] << ::PackmanNova::Manifest.load_file(path, require_checksums: require_checksums)
      rescue ::PackmanNova::ManifestError => e
        acc[:errors] << e
      end

      def package_dirs
        raise ::PackmanNova::ManifestError, "packages directory not found: #{packages_dir}" unless ::File.directory?(packages_dir)

        ::Dir.children(packages_dir).sort
             .reject { |entry| entry.start_with?('.', '_') }
             .map { |entry| ::File.join(packages_dir, entry) }
             .select { |path| ::File.directory?(path) }
      end
    end
  end
end
