# frozen_string_literal: true

module PackmanNova
  module Container
    class Runner
      class << self
        def from_config(config:, logger:, subprocess:)
          new(runtime: ::PackmanNova::Container::Runtime.detect(config:), logger:, subprocess:)
        end
      end

      def initialize(runtime:, logger:, subprocess:)
        @runtime = runtime
        @logger = logger
        @subprocess = subprocess
      end

      def run(timeout_sec: ::PackmanNova::Utils::Subprocess::DEFAULT_TIMEOUT_SEC, **, &line_block)
        subprocess.execute(command(**), timeout_sec:, &line_block)
      end

      def capture(timeout_sec: ::PackmanNova::Utils::Subprocess::CAPTURE_TIMEOUT_SEC, **)
        subprocess.capture(command(**), timeout_sec:)
      end

      def command(image:, args:, mounts: [], env: {}, privileged: false, name: nil, extra_args: [])
        [
          runtime.executable, 'run', '--rm', *flag_args(privileged:, name:),
          *mounts.flat_map(&:to_args), *env.flat_map { |key, value| ['-e', "#{key}=#{value}"] },
          *extra_args, image, *args
        ].map(&:to_s)
      end

      private

      attr_reader :runtime, :logger, :subprocess

      def flag_args(privileged:, name:)
        [*(privileged ? ['--privileged'] : []), *(name ? ['--name', name] : [])]
      end
    end
  end
end
