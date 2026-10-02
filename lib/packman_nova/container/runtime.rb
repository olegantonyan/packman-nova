# frozen_string_literal: true

module PackmanNova
  module Container
    class Runtime
      EXECUTABLES = %w[podman docker].freeze
      ENV_KEY = 'PACKMAN_NOVA_CONTAINER_RUNTIME'
      AUTO = 'auto'
      DEFAULT_PROBE = ->(executable) { system(executable, '--version', out: ::File::NULL, err: ::File::NULL) }

      class << self
        def detect(config:, env: ::ENV, probe: DEFAULT_PROBE)
          explicit = [env.fetch(ENV_KEY, ''), config.container.runtime].find { |value| !value.empty? && value != AUTO }
          return new(executable: explicit) if explicit

          found = EXECUTABLES.find { |executable| probe.call(executable) }
          raise ::PackmanNova::ConfigError, "no container runtime found: install #{EXECUTABLES.join(' or ')}" unless found

          new(executable: found)
        end
      end

      attr_reader :executable

      def initialize(executable:)
        @executable = executable
        freeze
      end

      def name
        ::File.basename(executable)
      end

      def podman?
        name == 'podman'
      end

      def docker?
        name == 'docker'
      end

      def unshare(argv)
        raise ::PackmanNova::Error, "#{name} has no user namespace helper; use remove_tree_argv" unless podman?

        [executable, 'unshare', *argv]
      end

      def remove_tree_argv(path, image:)
        return unshare(['rm', '-rf', path]) if podman?

        [executable, 'run', '--rm', '-v', "#{::File.dirname(path)}:/x", image, 'rm', '-rf', "/x/#{::File.basename(path)}"]
      end
    end
  end
end
