# frozen_string_literal: true

module PackmanNova
  module State
    module Schemas
      VERSION = 1

      ALL = {
        sync_state: { file: 'state/sync.json', required: %w[schema packages] },
        build_record: { file: 'state/builds/<run>.json', required: %w[schema run release started_at packages] },
        repo_state: { file: '<repository.path>/state.json', required: %w[schema generated_at run release files packages] }
      }.freeze

      module_function

      def validate!(name, hash)
        schema = ALL.fetch(name) { raise ::ArgumentError, "unknown schema #{name.inspect}" }
        raise ::PackmanNova::Error, "#{schema.fetch(:file)}: expected a JSON object" unless hash.is_a?(::Hash)

        missing = schema.fetch(:required) - hash.keys.map(&:to_s)
        raise ::PackmanNova::Error, "#{schema.fetch(:file)}: missing key(s) #{missing.join(', ')}" unless missing.empty?

        hash
      end
    end
  end
end
