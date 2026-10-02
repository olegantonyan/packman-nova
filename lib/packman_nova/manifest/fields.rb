# frozen_string_literal: true

module PackmanNova
  class Manifest
    module Fields
      private

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
