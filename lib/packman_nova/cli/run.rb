# frozen_string_literal: true

module PackmanNova
  class Cli
    class Run < ::PackmanNova::Cli::Command
      PUBLISH_FAILED_EXIT_CODE = 2

      class << self
        def summary
          'sync, build and publish (CI entry point)'
        end

        def options(parser, options)
          parser.on('--[no-]publish', 'publish after the build (default: yes)') { |value| options[:publish] = value }
          parser.on('--[no-]fail-on-failed-packages', 'exit 1 when any package failed to sync or build (default: yes)') { |value| options[:fail_on_failed_packages] = value }
          parser.on('--provider NAME', %w[localfs s3], 'localfs or s3 (default: repository.provider)') { |value| options[:provider] = value }
        end
      end

      def call
        result = pipeline.call(publish: options.fetch(:publish, true), provider: options[:provider])
        logger.info("run summary: #{result.summary}")
        exit_code(result)
      end

      private

      def pipeline
        ::PackmanNova::Pipeline.new(config: config, logger: logger, out: out)
      end

      def exit_code(result)
        return PUBLISH_FAILED_EXIT_CODE if result.publish_failed?
        return 1 if result.packages_failed? && options.fetch(:fail_on_failed_packages, true)

        0
      end
    end
  end
end
