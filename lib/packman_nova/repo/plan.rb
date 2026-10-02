# frozen_string_literal: true

module PackmanNova
  module Repo
    class Plan
      def initialize(diff:, build_record:, key: nil)
        @diff = diff
        @build_record = build_record
        @key = key
      end

      def lines
        [*file_lines, *sign_lines, *retain_lines, *diff.ignored.map { |reason| "ignore   #{reason}" }]
      end

      private

      attr_reader :diff, :build_record, :key

      def file_lines
        { 'add' => diff.to_add, 'replace' => diff.to_replace, 'remove' => diff.to_remove, 'resign' => diff.to_resign }.flat_map do |action, files|
          files.map { |relative| "#{action.ljust(8)} #{relative}" }
        end
      end

      def sign_lines
        key && !diff.to_stage.empty? ? ["sign     #{diff.to_stage.size} file(s) with key #{key.key_id}"] : []
      end

      def retain_lines
        diff.retained_packages.map { |name| "retain   #{name} (#{build_record.dig('packages', name, 'code') || 'not built'})" }
      end
    end
  end
end
