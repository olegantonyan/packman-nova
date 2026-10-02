# frozen_string_literal: true

module PackmanNova
  class Config
    class EnvExpander
      PATTERN = /\$\{([A-Za-z_][A-Za-z0-9_]*)\}/

      def initialize(env: ::ENV)
        @env = env
        @used = []
      end

      def expand(value)
        case value
        when ::Hash then value.transform_values { |nested| expand(nested) }
        when ::Array then value.map { |nested| expand(nested) }
        when ::String then expand_string(value)
        else value
        end
      end

      def used_names
        used.uniq.sort
      end

      def missing_names
        used_names.select { |name| env.fetch(name, '').empty? }
      end

      private

      attr_reader :env, :used

      def expand_string(string)
        string.gsub(PATTERN) do
          name = ::Regexp.last_match(1)
          used << name
          env.fetch(name, '')
        end
      end
    end
  end
end
