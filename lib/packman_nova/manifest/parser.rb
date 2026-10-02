# frozen_string_literal: true

module PackmanNova
  class Manifest
    class Parser
      include ::PackmanNova::Manifest::Fields

      OBS_LINK = ::PackmanNova::Manifest::OBS_LINK
      NATIVE = ::PackmanNova::Manifest::NATIVE
      KINDS = [OBS_LINK, NATIVE].freeze
      COMMON_KEYS = %i[name kind enabled tier tags notes spec].freeze
      KIND_KEYS = { OBS_LINK => %i[origin link], NATIVE => %i[sources] }.freeze
      ORIGIN_KEYS = %i[project package pin].freeze
      LINK_KEYS = %i[delete].freeze
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
          name: name,
          kind: kind,
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
          link_rules: ::PackmanNova::Manifest::LinkRules.new(delete: string_list(link, :delete, 'link.delete')),
          sources: []
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
        { origin: nil, link_rules: ::PackmanNova::Manifest::LinkRules.new(delete: []), sources: parse_sources }
      end

      def parse_sources
        source_parser = ::PackmanNova::Manifest::SourceParser.new(label: label, require_checksums: require_checksums)
        entries = typed(data, :sources, 'sources', ::Array) || []
        sources = entries.each_with_index.map { |entry, index| source_parser.call(entry, "sources[#{index}]") }
        reject_duplicate_files(sources)
        sources
      end

      def reject_duplicate_files(sources)
        duplicates = sources.map(&:file).tally.select { |_file, count| count > 1 }.keys
        fail!('sources', "duplicate file(s) #{duplicates.join(', ')}") unless duplicates.empty?
      end
    end
  end
end
