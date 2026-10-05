# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class Baselibs
      SKIPPED_CODES = %w[excluded disabled].freeze

      attr_reader :results

      def initialize(results:, codes:, details:, arch:, export_arch:)
        @results = results
        @codes = codes
        @details = details
        @arch = arch
        @export_arch = export_arch
      end

      def entries
        (results.keys | codes.keys).sort.to_h { |key| [key, entry(key)] }.reject { |_key, entry| SKIPPED_CODES.include?(entry['code']) }
      end

      def built_since(time)
        results.select { |_key, result| result.built_since?(time) }.keys
      end

      private

      attr_reader :codes, :details, :arch, :export_arch

      def entry(key)
        result = results[key]
        { 'arch' => arch, 'code' => codes[key] || result&.status || 'unknown', 'rpms' => exported_rpms(result), 'details' => details[key] }
      end

      def exported_rpms(result)
        return [] unless result

        result.rpm_files.select { |file| file.end_with?(".#{export_arch}.rpm") }
      end
    end
  end
end
