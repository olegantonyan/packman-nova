# frozen_string_literal: true

module PackmanNova
  class Cli
    class Command
      class << self
        def summary
          ''
        end

        def usage
          '[options]'
        end

        def options(_parser, _options); end

        def log_file?
          true
        end

        def tolerates_config_error?
          false
        end
      end

      def initialize(config:, logger:, options: {}, args: [], out: $stdout, config_error: nil)
        @config = config
        @logger = logger
        @options = options
        @args = args
        @out = out
        @config_error = config_error
      end

      private

      attr_reader :config, :logger, :options, :args, :out, :config_error
    end
  end
end
