# frozen_string_literal: true

module PackmanNova
  class Cli
    class State < ::PackmanNova::Cli::Command
      SUBCOMMANDS = %w[push pull].freeze

      class << self
        def summary
          'push or pull build state to/from the s3 provider'
        end

        def usage
          '<push|pull>'
        end

        def options(parser, options)
          parser.on('--allow-missing', 'pull: succeed with a warning when the bucket has no state yet') { options[:allow_missing] = true }
        end
      end

      def initialize(provider: nil, subprocess: nil, **)
        super(**)
        @provider = provider
        @subprocess = subprocess
      end

      def call
        subcommand = args.first
        raise ::OptionParser::InvalidArgument, "state: expected one of #{SUBCOMMANDS.join(', ')}" unless SUBCOMMANDS.include?(subcommand)

        workdir.with_lock { subcommand == 'pull' ? archive.pull(allow_missing: options.fetch(:allow_missing, false)) : archive.push }
        0
      end

      private

      def archive
        ::PackmanNova::Repo::StateArchive.new(config: config, workdir: workdir, provider: provider, subprocess: subprocess, logger: logger)
      end

      def workdir
        @workdir ||= config.workdir
      end

      def provider
        @provider ||= ::PackmanNova::Repo::Providers::S3.build(config: config, logger: logger)
      end

      def subprocess
        @subprocess ||= ::PackmanNova::Utils::Subprocess.new(logger: logger)
      end
    end
  end
end
