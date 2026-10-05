# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class Executor
      ENV = { 'LANG' => 'C.UTF-8', 'HOME' => '/root' }.freeze
      NAME_PREFIX = 'packman-nova-build'

      def initialize(config:, runner:, project_dir:, image:)
        @config = config
        @runner = runner
        @project_dir = project_dir
        @image = image
      end

      def run(argv, timeout_sec: ::PackmanNova::Utils::Subprocess::DEFAULT_TIMEOUT_SEC, &)
        runner.run(**options(argv), name: "#{NAME_PREFIX}-#{::Process.pid}", timeout_sec:, &)
      end

      def capture(argv)
        runner.capture(**options(argv))
      end

      def command(argv)
        runner.command(**options(argv), name: "#{NAME_PREFIX}-#{::Process.pid}")
      end

      private

      attr_reader :config, :runner, :project_dir, :image

      def options(argv)
        {
          image:, args: argv, mounts: project_dir.mounts, env: ENV,
          privileged: config.container.privileged?, extra_args: config.container.extra_args
        }
      end
    end
  end
end
