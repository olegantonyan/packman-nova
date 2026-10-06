# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class FailureLog
      FAILED = 'failed'

      def initialize(config:)
        @config = config
      end

      def path(key, entry)
        return unless entry['code'] == FAILED

        baselibs = entry['baselibs']
        return ::File.join(config.results_dir(baselibs['arch']), key, '_log') if baselibs && baselibs['code'] == FAILED

        entry['log'] && ::File.join(config.workdir.root, entry['log'])
      end

      private

      attr_reader :config
    end
  end
end
