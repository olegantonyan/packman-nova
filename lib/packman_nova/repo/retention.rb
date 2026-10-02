# frozen_string_literal: true

module PackmanNova
  module Repo
    class Retention
      SUCCEEDED = 'succeeded'

      def initialize(state:, build_record:, enabled:)
        @state = state
        @build_packages = build_record.fetch('packages', {})
        @enabled = enabled
      end

      def packages
        state.package_names.select { |name| enabled?(name) && !succeeded?(name) }
      end

      def files
        retained = packages
        state.files.select { |_relative, entry| retained.include?(entry['package']) }
      end

      def code(name)
        build_packages.dig(name, 'code')
      end

      private

      attr_reader :state, :build_packages, :enabled

      def enabled?(name)
        enabled.include?(name.split(':', 2).first)
      end

      def succeeded?(name)
        code(name) == SUCCEEDED
      end
    end
  end
end
