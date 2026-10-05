# frozen_string_literal: true

module PackmanNova
  module Container
    class Runtime
      EXECUTABLES = %w[podman docker].freeze
      AUTO = 'auto'
      DEFAULT_PROBE = ->(executable) { system(executable, '--version', out: ::File::NULL, err: ::File::NULL) }

      class << self
        def detect(config:, probe: DEFAULT_PROBE)
          explicit = config.container.runtime
          return new(executable: explicit) unless explicit.empty? || explicit == AUTO

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

      def remove_tree_argv(path, image:)
        return [executable, 'unshare', 'rm', '-rf', path] if podman?

        [executable, 'run', '--rm', '-v', "#{::File.dirname(path)}:/x", image, 'rm', '-rf', "/x/#{::File.basename(path)}"]
      end
    end
  end
end
