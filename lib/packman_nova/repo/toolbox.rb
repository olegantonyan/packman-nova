# frozen_string_literal: true

module PackmanNova
  module Repo
    class Toolbox
      SHELL = '/bin/bash'
      SCRIPT_NAME = 'packman-nova'

      class << self
        def build(config:, logger:, subprocess:)
          runtime = ::PackmanNova::Container::Runtime.detect(config: config)
          runner = ::PackmanNova::Container::Runner.new(runtime: runtime, logger: logger, subprocess: subprocess)
          new(runner: runner, image: config.container.image, extra_args: config.container.extra_args)
        end
      end

      def initialize(runner:, image:, extra_args: [])
        @runner = runner
        @image = image
        @extra_args = extra_args
      end

      def capture(script, mounts:, args: [], env: {})
        runner.capture(**command(script, mounts: mounts, args: args, env: env))
      end

      def run(script, mounts:, args: [], env: {})
        options = command(script, mounts: mounts, args: args, env: env)
        lines = []
        status = runner.run(**options) { |line| lines << line }
        raise ::PackmanNova::SubprocessError.new(cli: runner.command(**options), status: status, output: lines.join) unless status.success?

        lines
      end

      def command(script, mounts:, args:, env:)
        {
          image: image, mounts: mounts, env: env,
          args: ['-euo', 'pipefail', '-c', script, SCRIPT_NAME, *args],
          extra_args: ['--entrypoint', SHELL, *extra_args]
        }
      end

      private

      attr_reader :runner, :image, :extra_args
    end
  end
end
