# frozen_string_literal: true

module PackmanNova
  class Sync
    class Report
      Change = ::Data.define(:label, :previous, :current) do
        def changed?
          previous != current
        end

        def to_s
          changed? ? "#{label}: #{previous || '(none)'} -> #{current}" : "#{label}: #{current} (unchanged)"
        end
      end

      attr_reader :outcomes, :removed, :failed, :changes
      attr_accessor :rebuild_all_required

      def initialize(check_only: false)
        @check_only = check_only
        @outcomes = []
        @removed = []
        @failed = {}
        @changes = []
        @rebuild_all_required = false
      end

      def check_only?
        @check_only
      end

      def add(outcome)
        outcomes << outcome
      end

      def fail(name, message)
        failed[name] = message
      end

      def remove(name)
        removed << name
      end

      def track(label, previous:, current:)
        changes << Change.new(label:, previous:, current:) unless current.nil?
      end

      def changed
        outcomes.select(&:changed?)
      end

      def unchanged
        outcomes.reject(&:changed?)
      end

      def drift?
        !changed.empty? || !removed.empty? || changes.any?(&:changed?)
      end

      def failed?
        !failed.empty?
      end

      def log(logger)
        lines.each { |line| logger.info(line) }
        logger.warn("sync failed for #{failed.keys.join(', ')}; building their previous sources") if failed?
        self
      end

      def lines
        [
          check_only? ? 'sync --check summary' : 'sync summary',
          *changed_lines, "unchanged (#{unchanged.size})",
          *(removed.empty? ? [] : ["removed (#{removed.size}): #{removed.join(', ')}"]),
          *failed_lines, *changes.map(&:to_s),
          *(rebuild_all_required ? ['rebuild_all_required: true'] : [])
        ]
      end

      private

      def changed_lines
        ["changed (#{changed.size})#{':' unless changed.empty?}", *changed.map { |outcome| "  #{outcome.name}: #{outcome.detail}" }]
      end

      def failed_lines
        return [] if failed.empty?

        ["failed (#{failed.size}):", *failed.map { |name, message| "  #{name}: #{message}" }]
      end
    end
  end
end
