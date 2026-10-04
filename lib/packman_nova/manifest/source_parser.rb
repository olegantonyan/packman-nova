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
        urls = parse_urls(entry, field)
        path = string(entry, :path, "#{field}.path")
        generated = parse_generated(entry, field)
        fail!(field, 'needs exactly one of urls, path or generated') unless [!urls.empty?, path, generated].one?

        ::PackmanNova::Manifest::Source.new(
          file: parse_file(entry, field), urls: urls, path: path, generated: generated, sha256: parse_sha256(entry, field, urls), size: parse_size(entry, field)
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

      def parse_urls(entry, field)
        string_list(entry, :urls, "#{field}.urls").each do |url|
          next if ::PackmanNova::Manifest::Source.scheme_of(url)

          fail!("#{field}.urls", "unsupported url #{url.inspect} (use http(s)://, pmbs:<package>[/<file>] or mirror-src:<package>)")
        end
      end

      def parse_generated(entry, field)
        generated = string(entry, :generated, "#{field}.generated")
        allowed = ::PackmanNova::Manifest::Source::GENERATED
        fail!("#{field}.generated", "must be one of #{allowed.join(', ')}, got #{generated.inspect}") if generated && !allowed.include?(generated)

        generated
      end

      def parse_sha256(entry, field, urls)
        sha256 = string(entry, :sha256, "#{field}.sha256")
        fail!("#{field}.sha256", 'missing (run sync --update-checksums)') if sha256.nil? && !urls.empty? && require_checksums
        fail!("#{field}.sha256", 'must be 64 hex characters') if sha256 && !::PackmanNova::Manifest::Source::SHA256_PATTERN.match?(sha256)

        sha256&.downcase
      end

      def parse_size(entry, field)
        size = typed(entry, :size, "#{field}.size", ::Integer)
        fail!("#{field}.size", 'must not be negative') if size&.negative?

        size
      end
    end
  end
end
