# frozen_string_literal: true

module PackmanNova
  class Cli
    class Publish < ::PackmanNova::Cli::Command
      class << self
        def summary
          'sign rpms, update repodata and upload the repository'
        end

        def options(parser, options)
          parser.on('--provider NAME', %w[localfs s3], 'localfs or s3 (default: repository.provider)') { |value| options[:provider] = value }
          parser.on('--unsigned', 'skip signing (refused for s3 when signing.require_signature)') { options[:unsigned] = true }
          parser.on('--dry-run', 'print add/remove/sign lists only') { options[:dry_run] = true }
          parser.on('--[no-]site', 'regenerate the static site (default: yes)') { |value| options[:site] = value }
          parser.on('--arch ARCH', 'publish only this arch') { |value| options[:arch] = value }
        end
      end

      def call
        diff = publisher.call(provider: options[:provider], arch: options[:arch], **flags)
        logger.info(summary_line(diff)) unless flags[:dry_run]
        publisher.uninstallable.empty? ? 0 : 1
      end

      private

      def flags
        { unsigned: options.fetch(:unsigned, false), dry_run: options.fetch(:dry_run, false), site: options.fetch(:site, true) }
      end

      def publisher
        @publisher ||= ::PackmanNova::Publish.new(config:, logger:, out:)
      end

      def summary_line(diff)
        format('published: %<add>d added, %<replace>d replaced, %<remove>d removed, %<resign>d re-signed, %<retain>d package(s) retained',
               add: diff.to_add.size, replace: diff.to_replace.size, remove: diff.to_remove.size, resign: diff.to_resign.size, retain: diff.retained_packages.size)
      end
    end
  end
end
