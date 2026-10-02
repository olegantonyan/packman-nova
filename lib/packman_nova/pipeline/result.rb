# frozen_string_literal: true

module PackmanNova
  class Pipeline
    class Result
      attr_reader :sync_failed, :record, :failed_packages, :diff, :publish_error

      def initialize(sync_failed:, record:, failed_packages:, published:, diff:, publish_error:)
        @sync_failed = sync_failed
        @record = record
        @failed_packages = failed_packages
        @published = published
        @diff = diff
        @publish_error = publish_error
        freeze
      end

      def packages_failed?
        !(sync_failed.empty? && failed_packages.empty?)
      end

      def publish_failed?
        !publish_error.nil?
      end

      def summary
        [build_part, sync_part, publish_part].compact.join('; ')
      end

      private

      def published?
        @published
      end

      def build_part
        packages = record.fetch('packages', {})
        failed = failed_packages.empty? ? '0 failed' : "#{failed_packages.size} failed (#{failed_packages.join(', ')})"
        "run #{record['run'] || '-'}, release #{record['release'] || '-'}: built #{record.fetch('built', []).size} of #{packages.size}, #{failed}"
      end

      def sync_part
        "sync failed: #{sync_failed.join(', ')}" unless sync_failed.empty?
      end

      def publish_part
        return 'publish skipped' unless published?
        return "publish failed: #{publish_error.message}" if publish_failed?

        format('published %<add>d added, %<replace>d replaced, %<remove>d removed', add: diff.to_add.size, replace: diff.to_replace.size, remove: diff.to_remove.size)
      end
    end
  end
end
