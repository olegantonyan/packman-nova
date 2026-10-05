# frozen_string_literal: true

module PackmanNova
  module Repo
    class Toolbox
      SHELL = '/bin/bash'
      SCRIPT_NAME = 'packman-nova'

      class << self
        def build(config:, logger:, subprocess:)
          runner = ::PackmanNova::Container::Runner.from_config(config:, logger:, subprocess:)
          new(runner:, image: config.container.image, extra_args: config.container.extra_args)
        end
      end

      def initialize(runner:, image:, extra_args: [])
        @runner = runner
        @image = image
        @extra_args = extra_args
      end

      def capture(script, mounts:, args: [], env: {})
        runner.capture(**command(script, mounts:, args:, env:))
      end

      def run(script, mounts:, args: [], env: {})
        options = command(script, mounts:, args:, env:)
        lines = []
        status = runner.run(**options) { |line| lines << line }
        raise ::PackmanNova::SubprocessError.new(cli: runner.command(**options), status:, output: lines.join) unless status.success?

        lines
      end

      def command(script, mounts:, args:, env:)
        {
          image:, mounts:, env:,
          args: ['-euo', 'pipefail', '-c', script, SCRIPT_NAME, *args],
          extra_args: ['--entrypoint', SHELL, *extra_args]
        }
      end

      private

      attr_reader :runner, :image, :extra_args
    end
  end
end
