# frozen_string_literal: true

module PackmanNova
  module Container
    class Runner
      DEFAULT_TIMEOUT_SEC = 43_200
      CAPTURE_TIMEOUT_SEC = 600

      def initialize(runtime:, logger:, subprocess:)
        @runtime = runtime
        @logger = logger
        @subprocess = subprocess
      end

      def run(timeout_sec: DEFAULT_TIMEOUT_SEC, **, &line_block)
        subprocess.execute(command(**), timeout_sec: timeout_sec, &line_block)
      end

      def capture(timeout_sec: CAPTURE_TIMEOUT_SEC, **)
        subprocess.capture(command(**), timeout_sec: timeout_sec)
      end

      def command(image:, args:, mounts: [], env: {}, privileged: false, name: nil, workdir: nil, extra_args: [])
        [
          runtime.executable, 'run', '--rm', *flag_args(privileged: privileged, name: name, workdir: workdir),
          *mounts.flat_map(&:to_args), *env.flat_map { |key, value| ['-e', "#{key}=#{value}"] },
          *extra_args, image, *args
        ].map(&:to_s)
      end

      private

      attr_reader :runtime, :logger, :subprocess

      def flag_args(privileged:, name:, workdir:)
        [*(privileged ? ['--privileged'] : []), *(name ? ['--name', name] : []), *(workdir ? ['-w', workdir] : [])]
      end
    end
  end
end
