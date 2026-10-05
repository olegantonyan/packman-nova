# frozen_string_literal: true

module PackmanNova
  class Config
    class Section
      BOOLEAN = :boolean

      def initialize(hash, attributes:, path: [])
        raise ::PackmanNova::ConfigError, "#{label(path)}: expected a mapping, got #{hash.class}" unless hash.is_a?(::Hash)

        reject_unknown_keys(hash, attributes, path)
        @values = attributes.to_h { |name, type| [name, cast(hash, name, type, path + [name])] }.freeze
        attributes.each { |name, type| define_reader(name, type) }
        freeze
      end

      private

      attr_reader :values

      def reject_unknown_keys(hash, attributes, path)
        unknown = hash.keys.map(&:to_sym) - attributes.keys
        return if unknown.empty?

        raise ::PackmanNova::ConfigError, "#{label(path)}: unknown key(s) #{unknown.map { |key| label(path + [key]) }.join(', ')}"
      end

      def cast(hash, name, type, key_path)
        raise ::PackmanNova::ConfigError, "#{label(key_path)}: missing" unless hash.key?(name)

        value = hash.fetch(name)
        return self.class.new(value, attributes: type, path: key_path) if type.is_a?(::Hash)
        return value if matches?(value, type)

        raise ::PackmanNova::ConfigError, "#{label(key_path)}: expected #{describe(type)}, got #{value.class}"
      end

      def matches?(value, type)
        case type
        when BOOLEAN then [true, false].include?(value)
        when ::Array then value.is_a?(::Array) && value.all?(type.first)
        else value.is_a?(type)
        end
      end

      def describe(type)
        case type
        when BOOLEAN then 'true or false'
        when ::Array then "a list of #{type.first}"
        else type.to_s
        end
      end

      def define_reader(name, type)
        define_singleton_method(name) { values.fetch(name) }
        define_singleton_method(:"#{name}?") { values.fetch(name) } if type == BOOLEAN
      end

      def label(path)
        path.empty? ? 'config' : path.join('.')
      end
    end
  end
end
