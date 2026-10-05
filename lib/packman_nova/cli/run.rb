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

      def initialize(sync: nil, build: nil, publisher: nil, **)
        super(**)
        @sync = sync
        @build = build
        @publisher = publisher
      end

      def call
        sync_failed = sync.call.log(logger).failed.keys
        build.call(sync: false)
        record = ::PackmanNova::State::BuildRecord.new(workdir: config.workdir).last || {}
        publish_error, publish_part = publish
        log_summary(record, sync_failed, publish_part)
        exit_code(publish_error, [*sync_failed, *::PackmanNova::State::BuildRecord.failed_packages(record)])
      end

      private

      def sync
        @sync ||= ::PackmanNova::Sync.new(config:, logger:)
      end

      def build
        @build ||= ::PackmanNova::Build.new(config:, logger:, out:)
      end

      def publisher
        @publisher ||= ::PackmanNova::Publish.new(config:, logger:, out:)
      end

      def publish
        return [nil, 'publish skipped'] unless options.fetch(:publish, true)

        [nil, published_part(publisher.call(provider: options[:provider]))]
      rescue ::StandardError => e
        logger.error("publish failed: #{e.class}: #{e.message}")
        [e, "publish failed: #{e.message}"]
      end

      def published_part(diff)
        format('published %<add>d added, %<replace>d replaced, %<remove>d removed', add: diff.to_add.size, replace: diff.to_replace.size, remove: diff.to_remove.size)
      end

      def log_summary(record, sync_failed, publish_part)
        logger.info("run summary: #{[build_part(record), sync_part(sync_failed), publish_part].compact.join('; ')}")
      end

      def build_part(record)
        failed = ::PackmanNova::State::BuildRecord.failed_packages(record)
        failed_text = failed.empty? ? '0 failed' : "#{failed.size} failed (#{failed.join(', ')})"
        "run #{record['run'] || '-'}, release #{record['release'] || '-'}: built #{record.fetch('built', []).size} of #{record.fetch('packages', {}).size}, #{failed_text}"
      end

      def sync_part(sync_failed)
        "sync failed: #{sync_failed.join(', ')}" unless sync_failed.empty?
      end

      def exit_code(publish_error, failed)
        return PUBLISH_FAILED_EXIT_CODE if publish_error
        return 1 if failed.any? && options.fetch(:fail_on_failed_packages, true)

        0
      end
    end
  end
end
