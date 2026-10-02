# frozen_string_literal: true

require 'time'

module PackmanNova
  class Sync
    class NextState
      def initialize(previous:, report:, enabled_names:, filtered:)
        @previous = previous
        @report = report
        @enabled_names = enabled_names
        @filtered = filtered
      end

      def rebuild_all_required?(local_md5)
        before = previous['local_config_md5']
        (!before.nil? && before != local_md5) || previous.fetch('rebuild_all_required', false)
      end

      def call(prjconf:, snapshot:)
        {
          'schema' => ::PackmanNova::State::Schemas::VERSION, 'synced_at' => ::Time.now.utc.iso8601,
          'tumbleweed_snapshot' => snapshot, 'factory_prjconf_md5' => prjconf.factory_md5, 'local_config_md5' => prjconf.local_md5,
          'rebuild_all_required' => rebuild_all_required?(prjconf.local_md5), 'packages' => packages
        }
      end

      private

      attr_reader :previous, :report, :enabled_names, :filtered

      def packages
        kept = previous.fetch('packages').except(*report.removed)
        kept = kept.slice(*enabled_names) unless filtered
        report.outcomes.each { |outcome| kept[outcome.name] = outcome.record }
        kept.sort.to_h
      end
    end
  end
end
