# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class SyncRunner
      class << self
        def available?
          ::PackmanNova.const_defined?(:Sync, false) && ::PackmanNova::Sync.is_a?(::Class) && ::PackmanNova::Sync.method_defined?(:call)
        end
      end

      def initialize(config:, logger:, sync: nil)
        @config = config
        @logger = logger
        @sync = sync
      end

      def call
        return sync.call if sync
        return logger.warn('sync not available, building the project dir as it is') unless self.class.available?

        report(::PackmanNova::Sync.new(config: config, logger: logger).call(packages: nil, check_only: false, update_checksums: false))
      end

      private

      attr_reader :config, :logger, :sync

      def report(result)
        result.lines.each { |line| logger.info(line) } if result.respond_to?(:lines)
        logger.warn('sync failed for some packages, building their previous sources') if result.respond_to?(:failed?) && result.failed?
        result
      end
    end
  end
end
