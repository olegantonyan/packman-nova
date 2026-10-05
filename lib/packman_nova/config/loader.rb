# frozen_string_literal: true

require 'dotenv'

module PackmanNova
  class Config
    class Loader
      USER_FILE_NAME = 'packman-nova.yml'
      DOTENV_FILE_NAME = '.env'
      ENV_PATTERN = /\$\{([A-Za-z_][A-Za-z0-9_]*)\}/
      ENV_OVERRIDES = {
        'PACKMAN_NOVA_WORKDIR' => %i[workdir],
        'PACKMAN_NOVA_CONTAINER_RUNTIME' => %i[container runtime],
        'PACKMAN_NOVA_PUBLIC_URL' => %i[repository public_url],
        'PACKMAN_NOVA_REPO_PATH' => %i[repository localfs path]
      }.freeze

      def initialize(path:, overrides:, cwd:, env: ::ENV)
        @path = path
        @overrides = overrides
        @cwd = cwd
        @env = env
        @used = []
      end

      def call
        load_dotenv
        merged = [*files.map { |file| expand(read_file(file)) }, env_overrides, overrides.compact].reduce { |acc, layer| merge(acc, layer) }
        ::PackmanNova::Config.new(merged, files:, env_vars_used: used.uniq.sort, env_vars_missing: missing_names)
      end

      def files
        [::PackmanNova::Config::DEFAULT_PATH, user_file].compact
      end

      private

      attr_reader :path, :overrides, :cwd, :env, :used

      def missing_names
        used.uniq.sort.select { |name| env.fetch(name, '').empty? }
      end

      def expand(value)
        case value
        when ::Hash then value.transform_values { |nested| expand(nested) }
        when ::Array then value.map { |nested| expand(nested) }
        when ::String then value.gsub(ENV_PATTERN) { env.fetch(used.push(::Regexp.last_match(1)).last, '') }
        else value
        end
      end

      def load_dotenv
        dotenv_path = ::File.join(cwd, DOTENV_FILE_NAME)
        ::Dotenv.load(dotenv_path) if ::File.file?(dotenv_path)
      end

      def user_file
        return ::File.expand_path(path) if path && ::File.file?(path)
        raise ::PackmanNova::ConfigError, "config file not found: #{path}" if path

        candidate = ::File.join(cwd, USER_FILE_NAME)
        ::File.file?(candidate) ? candidate : nil
      end

      def read_file(file)
        data = ::PackmanNova::Utils::Yaml.load_file(file, symbolize_names: true) || {}
        raise ::PackmanNova::ConfigError, "#{file}: expected a mapping at the top level" unless data.is_a?(::Hash)

        data
      rescue ::Psych::Exception => e
        raise ::PackmanNova::ConfigError, "#{file}: #{e.message}"
      end

      def env_overrides
        ENV_OVERRIDES.reduce({}) do |acc, (name, key_path)|
          value = env.fetch(name, '')
          value.empty? ? acc : merge(acc, key_path.reverse.reduce(value) { |nested, key| { key => nested } })
        end
      end

      def merge(base, override)
        base.merge(override) do |_key, old, new|
          old.is_a?(::Hash) && new.is_a?(::Hash) ? merge(old, new) : new
        end
      end
    end
  end
end
