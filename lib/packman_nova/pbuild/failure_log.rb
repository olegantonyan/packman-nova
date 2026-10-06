# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class FailureLog
      def initialize(config:)
        @config = config
      end

      def path(key, entry)
        baselibs = entry['baselibs']
        return ::File.join(config.results_dir(baselibs['arch']), key, '_log') if baselibs && ::PackmanNova::Pbuild::ResultParser::FAILURE_CODES.include?(baselibs['code'])

        entry['log'] && ::File.join(config.workdir.root, entry['log'])
      end

      private

      attr_reader :config
    end
  end
end
