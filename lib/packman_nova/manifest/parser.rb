# frozen_string_literal: true

module PackmanNova
  class Manifest
    class Parser
      OBS_LINK = ::PackmanNova::Manifest::OBS_LINK
      NATIVE = ::PackmanNova::Manifest::NATIVE
      KINDS = [OBS_LINK, NATIVE].freeze
      COMMON_KEYS = %i[name kind enabled tier tags notes spec].freeze
      KIND_KEYS = { OBS_LINK => %i[origin link], NATIVE => %i[sources watch] }.freeze
      ORIGIN_KEYS = %i[project package pin].freeze
      LINK_KEYS = %i[delete patches].freeze
      SOURCE_KEYS = %i[file urls sha256 size path generated].freeze
      DEFAULT_ORIGIN_PROJECT = 'openSUSE:Factory'

      def initialize(data, label:, require_checksums: true)
        @data = data
        @label = label
        @require_checksums = require_checksums
      end

      def call
        fail!('manifest', "expected a mapping, got #{data.class}") unless data.is_a?(::Hash)

        kind = parse_kind
        reject_unknown(data, COMMON_KEYS + KIND_KEYS.fetch(kind), 'manifest')
        name = parse_name
        metadata(name, kind).merge(kind == OBS_LINK ? obs_link_parts(name) : native_parts)
      end

      private

      attr_reader :data, :label, :require_checksums

      def parse_kind
        kind = data[:kind]
        fail!('kind', "must be one of #{KINDS.join(', ')}, got #{kind.inspect}") unless KINDS.include?(kind)

        kind
      end

      def parse_name
        name = string(data, :name, 'name', required: true)
        fail!('name', "#{name.inspect} does not match directory #{label.inspect}") unless name == label

        name
      end

      def metadata(name, kind)
        {
          name:,
          kind:,
          enabled: boolean(data, :enabled, 'enabled', default: true),
          tier: typed(data, :tier, 'tier', ::Integer),
          tags: string_list(data, :tags, 'tags'),
          notes: string(data, :notes, 'notes'),
          spec_name: string(data, :spec, 'spec') || "#{name}.spec"
        }
      end

      def obs_link_parts(name)
        link = mapping(data, :link, 'link')
        reject_unknown(link, LINK_KEYS, 'link')
        {
          origin: parse_origin(name),
          link_delete: string_list(link, :delete, 'link.delete'),
          link_patches: string_list(link, :patches, 'link.patches'),
          sources: [],
          watch: nil
        }
      end

      def parse_origin(name)
        origin = mapping(data, :origin, 'origin')
        reject_unknown(origin, ORIGIN_KEYS, 'origin')
        ::PackmanNova::Manifest::Origin.new(
          project: string(origin, :project, 'origin.project') || DEFAULT_ORIGIN_PROJECT,
          package: string(origin, :package, 'origin.package') || name,
          pin: string(origin, :pin, 'origin.pin')
        )
      end

      def native_parts
        { origin: nil, link_delete: [], link_patches: [], sources: parse_sources, watch: ::PackmanNova::Manifest::WatchParser.new(data[:watch], label:).call }
      end

      def parse_sources
        entries = typed(data, :sources, 'sources', ::Array) || []
        sources = entries.each_with_index.map { |entry, index| parse_source(entry, "sources[#{index}]") }
        reject_duplicate_files(sources)
        sources
      end

      def reject_duplicate_files(sources)
        duplicates = sources.map(&:file).tally.select { |_file, count| count > 1 }.keys
        fail!('sources', "duplicate file(s) #{duplicates.join(', ')}") unless duplicates.empty?
      end

      def parse_source(entry, field)
        fail!(field, 'expected a mapping') unless entry.is_a?(::Hash)
        reject_unknown(entry, SOURCE_KEYS, field)
        urls, path, generated = parse_source_origin(entry, field)

        ::PackmanNova::Manifest::Source.new(
          file: parse_file(entry, field), urls:, path:, generated:,
          sha256: parse_sha256(entry, field, remote: path.nil? && generated.nil?, archive_only: urls.empty?), size: parse_size(entry, field)
        )
      end

      def parse_file(entry, field)
        file = string(entry, :file, "#{field}.file", required: true)
        fail!("#{field}.file", "must be a plain file name, got #{file.inspect}") if file.include?('/') || file.start_with?('.')
        fail!("#{field}.file", "#{file} is reserved") if file == ::PackmanNova::Manifest::FILE_NAME

        file
      end

      def parse_source_origin(entry, field)
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

      def reject_unknown(hash, allowed, field)
        unknown = hash.keys - allowed
        fail!(field, "unknown key(s) #{unknown.join(', ')}") unless unknown.empty?
      end

      def mapping(hash, key, field)
        typed(hash, key, field, ::Hash) || {}
      end

      def string(hash, key, field, required: false)
        value = typed(hash, key, field, ::String)
        fail!(field, 'missing') if required && (value.nil? || value.empty?)

        value
      end

      def string_list(hash, key, field)
        list = typed(hash, key, field, ::Array) || []
        fail!(field, 'must be a list of strings') unless list.all?(::String)

        list
      end

      def boolean(hash, key, field, default:)
        return default unless hash.key?(key)

        value = hash[key]
        fail!(field, "must be true or false, got #{value.inspect}") unless [true, false].include?(value)

        value
      end

      def typed(hash, key, field, type)
        value = hash[key]
        fail!(field, "must be #{type}, got #{value.class}") unless value.nil? || value.is_a?(type)

        value
      end

      def fail!(field, message)
        raise ::PackmanNova::ManifestError, "package #{label}: #{field}: #{message}"
      end
    end
  end
end
