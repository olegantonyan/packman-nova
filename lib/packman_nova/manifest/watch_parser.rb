# frozen_string_literal: true

module PackmanNova
  class Manifest
    class WatchParser
      STRING_KEYS = %i[url pattern git branch tags format file commit].freeze
      KEYS = [*STRING_KEYS, :exclude, :sover].freeze
      GIT_ONLY = %i[branch tags format file exclude sover commit].freeze
      SOVER_KEYS = %i[path pattern].freeze
      COMMIT_PATTERN = /\A\h{40}\z/

      def initialize(data, label:)
        @data = data
        @label = label
      end

      def call
        return nil if data.nil?

        reject_invalid_shape
        watch = ::PackmanNova::Manifest::Watch.new(**strings, exclude: exclude_list, sover: parse_sover)
        validate(watch)
        watch
      end

      private

      attr_reader :data, :label

      def reject_invalid_shape
        fail!('watch', "expected a mapping, got #{data.class}") unless data.is_a?(::Hash)
        unknown = data.keys - KEYS
        fail!('watch', "unknown key(s) #{unknown.join(', ')}") unless unknown.empty?
      end

      def strings
        STRING_KEYS.to_h { |key| [key, string(data, key, "watch.#{key}")] }
      end

      def exclude_list
        list = data.fetch(:exclude, [])
        fail!('watch.exclude', 'must be a list of strings') unless list.is_a?(::Array) && list.all?(::String)

        list
      end

      def parse_sover
        sover = data[:sover]
        return nil if sover.nil?

        fail!('watch.sover', 'expected a mapping with path and pattern') unless sover.is_a?(::Hash) && sover.keys.sort == SOVER_KEYS
        path, pattern = SOVER_KEYS.map { |key| string(sover, key, "watch.sover.#{key}") }
        regexp!(pattern, 'watch.sover.pattern')
        ::PackmanNova::Manifest::Watch::Sover.new(path:, pattern:)
      end

      def validate(watch)
        fail!('watch', 'needs exactly one of url or git') unless [watch.url, watch.git].compact.size == 1
        watch.http? ? validate_http(watch) : validate_git(watch)
      end

      def validate_http(watch)
        present = GIT_ONLY.select { |key| data.key?(key) }
        fail!('watch', "#{present.join(', ')} need git") unless present.empty?
        fail!('watch.pattern', 'missing') unless watch.pattern

        regexp!(watch.pattern, 'watch.pattern')
      end

      def validate_git(watch)
        fail!('watch.pattern', 'only for url watches (git uses tags)') if watch.pattern
        validate_ref(watch)
        validate_snapshot(watch)
        fail!('watch.commit', 'must be a 40 hex character sha') if watch.commit && !COMMIT_PATTERN.match?(watch.commit)
      end

      def validate_ref(watch)
        fail!('watch', 'needs exactly one of branch or tags') unless [watch.branch, watch.tags].compact.size == 1
        fail!('watch', 'branch needs format and file') if watch.branch? && !(watch.format && watch.file)
        regexp!(watch.tags, 'watch.tags') if watch.tags
      end

      def validate_snapshot(watch)
        return validate_file(watch.file) if watch.snapshot?

        fail!('watch', 'exclude, sover and commit need file') if data.key?(:exclude) || watch.sover || watch.commit
      end

      def validate_file(file)
        fail!('watch.file', "must contain #{::PackmanNova::Manifest::Watch::VERSION_PLACEHOLDER}") unless file.include?(::PackmanNova::Manifest::Watch::VERSION_PLACEHOLDER)
        fail!('watch.file', 'must end in .tar or .tar.xz') unless ::PackmanNova::Manifest::Watch::ARCHIVE_EXTENSION.match?(file)
        fail!('watch.file', "must be a plain file name, got #{file.inspect}") if file.include?('/')
      end

      def regexp!(pattern, field)
        ::Regexp.new(pattern)
      rescue ::RegexpError => e
        fail!(field, "invalid regexp: #{e.message}")
      end

      def string(hash, key, field)
        value = hash[key]
        fail!(field, "must be String, got #{value.class}") unless value.nil? || value.is_a?(::String)
        fail!(field, 'must not be empty') if value == ''

        value
      end

      def fail!(field, message)
        raise ::PackmanNova::ManifestError, "package #{label}: #{field}: #{message}"
      end
    end
  end
end
