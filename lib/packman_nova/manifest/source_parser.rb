# frozen_string_literal: true

module PackmanNova
  class Manifest
    class SourceParser
      include ::PackmanNova::Manifest::Fields

      KEYS = %i[file urls sha256 size path generated].freeze

      def initialize(label:, require_checksums:)
        @label = label
        @require_checksums = require_checksums
      end

      def call(entry, field)
        fail!(field, 'expected a mapping') unless entry.is_a?(::Hash)
        reject_unknown(entry, KEYS, field)
        urls, path, generated = parse_origin(entry, field)

        ::PackmanNova::Manifest::Source.new(
          file: parse_file(entry, field), urls: urls, path: path, generated: generated,
          sha256: parse_sha256(entry, field, remote: path.nil? && generated.nil?, archive_only: urls.empty?), size: parse_size(entry, field)
        )
      end

      private

      attr_reader :label, :require_checksums

      def parse_file(entry, field)
        file = string(entry, :file, "#{field}.file", required: true)
        fail!("#{field}.file", "must be a plain file name, got #{file.inspect}") if file.include?('/') || file.start_with?('.')
        fail!("#{field}.file", "#{file} is reserved") if file == ::PackmanNova::Manifest::FILE_NAME

        file
      end

      def parse_origin(entry, field)
        origin = [parse_urls(entry, field), string(entry, :path, "#{field}.path"), parse_generated(entry, field)]
        fail!(field, 'urls, path and generated are mutually exclusive') if [!origin[0].empty?, origin[1], origin[2]].count(&:itself) > 1

        origin
      end

      def parse_urls(entry, field)
        string_list(entry, :urls, "#{field}.urls").each do |url|
          fail!("#{field}.urls", "unsupported url #{url.inspect} (use http(s)://)") unless ::PackmanNova::Manifest::Source::HTTP_PATTERN.match?(url)
        end
      end

      def parse_generated(entry, field)
        generated = string(entry, :generated, "#{field}.generated")
        allowed = ::PackmanNova::Manifest::Source::GENERATED
        fail!("#{field}.generated", "must be one of #{allowed.join(', ')}, got #{generated.inspect}") if generated && !allowed.include?(generated)

        generated
      end

      def parse_sha256(entry, field, remote:, archive_only:)
        sha256 = string(entry, :sha256, "#{field}.sha256")
        require_sha256!(field, archive_only) if sha256.nil? && remote
        fail!("#{field}.sha256", 'must be 64 hex characters') if sha256 && !::PackmanNova::Manifest::Source::SHA256_PATTERN.match?(sha256)

        sha256&.downcase
      end

      def require_sha256!(field, archive_only)
        fail!("#{field}.sha256", 'required for a source without urls (it is fetched from the source archive)') if archive_only
        fail!("#{field}.sha256", 'missing (run sync --update-checksums)') if require_checksums
      end

      def parse_size(entry, field)
        size = typed(entry, :size, "#{field}.size", ::Integer)
        fail!("#{field}.size", 'must not be negative') if size&.negative?

        size
      end
    end
  end
end
